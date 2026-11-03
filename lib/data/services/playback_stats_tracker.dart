// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:flind_player/core/models/playback_session.dart';
import 'package:flind_player/core/models/playback_state.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/repositories/playback_stats_repository.dart';
import 'package:flind_player/core/services/playback_controller.dart';

/// Turns the player's state stream into [PlaybackSession]s.
///
/// Rules:
/// * A session starts on the first tick where a track is actually playing.
/// * Listened time is wall-clock time between playing ticks, capped at
///   [tickCap] so a suspended app or a long event-loop gap cannot inflate it.
/// * Pausing does not end the session; switching tracks, completing a track,
///   stopping, or disposing does.
/// * Sessions below [PlaybackSession.minimumRecordedListen] are dropped;
///   sessions of 30s or more (or completed tracks) count as one play.
class PlaybackStatsTracker {
  PlaybackStatsTracker({
    required PlaybackController playback,
    required PlaybackStatsRepository repository,
    Duration tickCap = const Duration(seconds: 2),
    DateTime Function() clock = DateTime.now,
  }) : _playback = playback, // ignore: prefer_initializing_formals
       _repository = repository, // ignore: prefer_initializing_formals
       _tickCap = tickCap, // ignore: prefer_initializing_formals
       _clock = clock; // ignore: prefer_initializing_formals

  final PlaybackController _playback;
  final PlaybackStatsRepository _repository;
  final Duration _tickCap;
  final DateTime Function() _clock;

  StreamSubscription<PlaybackState>? _subscription;
  bool _started = false;
  bool _disposed = false;

  String? _trackUri;
  DateTime? _startedAt;
  DateTime? _lastPlayingAt;
  int _listenedMs = 0;
  int _maxPositionMs = 0;
  Duration? _duration;
  bool _completed = false;

  /// Starts observing; idempotent.
  void start() {
    if (_disposed || _started) return;
    _started = true;
    _subscription = _playback.state.listen(
      _onState,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint(
          'PlaybackStatsTracker: state stream error: $error\n$stackTrace',
        );
      },
    );
  }

  /// Flushes the current session and stops observing.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _started = false;
    await _subscription?.cancel();
    _subscription = null;
    await _flush();
  }

  void _onState(PlaybackState state) {
    if (_disposed) return;

    final track = state.currentTrack;
    if (track == null) {
      _flush();
      return;
    }

    if (_trackUri != track.uri) {
      _flush();
      _begin(track);
    }

    if (state.duration != null) _duration = state.duration;
    if (state.position.inMilliseconds > _maxPositionMs) {
      _maxPositionMs = state.position.inMilliseconds;
    }

    final playing = state.isPlaying && !state.isBuffering;
    if (playing) {
      final now = _clock();
      _startedAt ??= now;
      final last = _lastPlayingAt;
      if (last != null) {
        final delta = now.difference(last);
        if (delta > Duration.zero) {
          _listenedMs += delta > _tickCap
              ? _tickCap.inMilliseconds
              : delta.inMilliseconds;
        }
      }
      _lastPlayingAt = now;
    } else {
      _lastPlayingAt = null;
    }

    if (state.isCompleted) {
      _completed = true;
      _flush();
    }
  }

  void _begin(Track track) {
    _trackUri = track.uri;
    _startedAt = null;
    _lastPlayingAt = null;
    _listenedMs = 0;
    _maxPositionMs = 0;
    _duration = track.duration;
    _completed = false;
  }

  Future<void> _flush() async {
    final uri = _trackUri;
    final startedAt = _startedAt;
    final listened = Duration(milliseconds: _listenedMs);
    final completed = _completed;
    final position = Duration(milliseconds: _maxPositionMs);
    final duration = _duration;

    _trackUri = null;
    _startedAt = null;
    _lastPlayingAt = null;
    _listenedMs = 0;
    _maxPositionMs = 0;
    _duration = null;
    _completed = false;

    if (uri == null || startedAt == null) return;

    final session = PlaybackSession(
      trackUri: uri,
      startedAt: startedAt,
      endedAt: _clock(),
      listened: listened,
      completed: completed,
      position: position,
      duration: duration,
    );
    if (!session.isRecordable) return;

    try {
      await _repository.record(session);
    } catch (error, stackTrace) {
      debugPrint('PlaybackStatsTracker: record failed: $error\n$stackTrace');
    }
  }
}
