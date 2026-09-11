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

import 'package:flind_player/core/models/playback_queue.dart';
import 'package:flind_player/core/models/playback_state.dart';
import 'package:flind_player/core/models/repeat_mode.dart';
import 'package:flind_player/core/repositories/playback_snapshot_repository.dart';
import 'package:flind_player/core/services/playback_controller.dart';

/// Glues a [PlaybackController] to a [PlaybackSnapshotRepository].
///
/// Persistence rules:
/// * Immediate write on any structural change: current track, queue
///   length/order, play/pause, repeat/shuffle.
/// * Explicit seeks are detected as a large position discontinuity and written
///   immediately.
/// * Position-only ticks are throttled to at most one write per [throttle] (the
///   controller emits ~5 Hz; SQLite should not see every one).
/// * An **empty queue clears the snapshot** — the user emptied it, so there is
///   nothing to restore. This is intentional, not a skipped write.
/// * Every write is fire-and-forget: a failing repository logs via
///   [debugPrint] and must never break playback.
class PlaybackPersistenceService {
  PlaybackPersistenceService({
    required PlaybackController playback,
    required PlaybackSnapshotRepository repository,
    Duration throttle = const Duration(seconds: 5),
    DateTime Function() clock = DateTime.now,
  }) : _playback = playback, // ignore: prefer_initializing_formals
       _repository = repository, // ignore: prefer_initializing_formals
       _positionThrottle = throttle, // ignore: prefer_initializing_formals
       _clock = clock; // ignore: prefer_initializing_formals

  /// A position jump larger than this (against the expected tick) is treated
  /// as an explicit seek and persisted immediately.
  static const Duration _seekThreshold = Duration(seconds: 2);

  final PlaybackController _playback;
  final PlaybackSnapshotRepository _repository;
  final Duration _positionThrottle;
  final DateTime Function() _clock;

  StreamSubscription<PlaybackState>? _subscription;

  PlaybackQueue? _lastQueue;
  bool? _lastPlaying;
  RepeatMode? _lastRepeat;
  bool? _lastShuffle;
  Duration? _lastPosition;
  DateTime? _lastStateAt;
  DateTime? _lastPositionWrite;

  bool _started = false;
  bool _restoring = false;
  bool _disposed = false;
  bool _hasSnapshot = false;

  /// Loads any stored snapshot and restores the queue, position, repeat and
  /// shuffle into the controller.
  ///
  /// Playback is left paused: the engine interface offers no load-without-play,
  /// so the queue is loaded and then immediately paused. Never throws — a
  /// corrupt snapshot or a failing repository is logged and ignored so startup
  /// can continue.
  Future<void> restore() async {
    if (_disposed) return;

    PlaybackSnapshot? snapshot;
    try {
      snapshot = await _repository.load();
    } catch (error, stackTrace) {
      debugPrint(
        'PlaybackPersistenceService: snapshot load failed: $error\n'
        '$stackTrace',
      );
      return;
    }
    if (snapshot == null || snapshot.queue.isEmpty) return;

    _restoring = true;
    try {
      final queue = snapshot.queue;
      // Load without producing sound: a restored session must come up paused.
      await _playback.playQueue(
        queue,
        index: queue.currentIndex,
        autoPlay: false,
      );
      await _playback.setRepeatMode(snapshot.repeatMode);
      await _playback.setShuffle(snapshot.shuffleEnabled);
      await _playback.seek(snapshot.position);
      _hasSnapshot = true;
    } catch (error, stackTrace) {
      debugPrint(
        'PlaybackPersistenceService: restore failed: $error\n$stackTrace',
      );
    } finally {
      _restoring = false;
    }
  }

  /// Starts observing the controller and persisting changes.
  ///
  /// Idempotent; calling it twice keeps a single subscription.
  void start() {
    if (_disposed || _started) return;
    _started = true;
    _captureBaseline(_playback.currentState, _playback.queue, _clock());
    _subscription = _playback.state.listen(
      _onState,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint(
          'PlaybackPersistenceService: state stream error: $error\n'
          '$stackTrace',
        );
      },
    );
  }

  /// Stops observing; no further writes are scheduled.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _started = false;
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }

  void _onState(PlaybackState state) {
    if (_disposed || _restoring) return;

    final queue = _playback.queue;
    final now = _clock();

    // Empty queue: clear the snapshot. The user emptied the queue, so the
    // stored session must not be resurrected on the next launch.
    if (queue.isEmpty) {
      if (_hasSnapshot) {
        _hasSnapshot = false;
        _clearSnapshot();
      }
      _captureBaseline(state, queue, now);
      return;
    }

    final queueChanged =
        _lastQueue == null ||
        !listEquals(_lastQueue!.tracks, queue.tracks) ||
        _lastQueue!.currentIndex != queue.currentIndex ||
        !listEquals(_lastQueue!.originalOrder, queue.originalOrder);

    if (queueChanged ||
        _lastPlaying != state.isPlaying ||
        _lastRepeat != state.repeatMode ||
        _lastShuffle != state.shuffleEnabled) {
      _persist(state, queue, now);
      return;
    }

    if (_lastPosition == state.position) return;

    // Position-only change: persist immediately for a seek, otherwise at most
    // once per throttle window.
    final elapsed = _lastPositionWrite == null
        ? null
        : now.difference(_lastPositionWrite!);
    if (_isSeek(state, now) ||
        elapsed == null ||
        elapsed >= _positionThrottle) {
      _persist(state, queue, now);
      return;
    }

    // Throttled: remember the position so later ticks are compared correctly,
    // but do not write.
    _lastPosition = state.position;
    _lastStateAt = now;
  }

  /// True when [state]'s position cannot be explained by normal ticking, i.e.
  /// the user seeked.
  bool _isSeek(PlaybackState state, DateTime now) {
    final lastPosition = _lastPosition;
    final lastStateAt = _lastStateAt;
    if (lastPosition == null || lastStateAt == null) return true;

    final elapsed = now.difference(lastStateAt);
    final expected = state.isPlaying ? lastPosition + elapsed : lastPosition;
    return (state.position - expected).abs() > _seekThreshold;
  }

  void _persist(PlaybackState state, PlaybackQueue queue, DateTime now) {
    _hasSnapshot = true;
    _lastPositionWrite = now;
    _captureBaseline(state, queue, now);

    final snapshot = PlaybackSnapshot(
      queue: queue,
      position: state.position,
      repeatMode: state.repeatMode,
      shuffleEnabled: state.shuffleEnabled,
    );
    unawaited(
      _repository.save(snapshot).catchError((Object error) {
        debugPrint('PlaybackPersistenceService: snapshot save failed: $error');
      }),
    );
  }

  void _clearSnapshot() {
    unawaited(
      _repository.clear().catchError((Object error) {
        debugPrint('PlaybackPersistenceService: snapshot clear failed: $error');
      }),
    );
  }

  void _captureBaseline(
    PlaybackState state,
    PlaybackQueue queue,
    DateTime now,
  ) {
    _lastQueue = queue;
    _lastPlaying = state.isPlaying;
    _lastRepeat = state.repeatMode;
    _lastShuffle = state.shuffleEnabled;
    _lastPosition = state.position;
    _lastStateAt = now;
  }
}
