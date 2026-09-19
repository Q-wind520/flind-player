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
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:flind_player/core/models/playback_state.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/services/playback_controller.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/services/cover_service.dart';

/// Warms the cover cache whenever tracks enter the playback queue.
///
/// This is the "fetch on enqueue" trigger: it subscribes to the controller's
/// state, and for every queued track that lacks a usable local cover it calls
/// [CoverService.ensureCover] and patches the live queue with the result so the
/// player, mini bar and library rows all light up.
///
/// A short bounded concurrency window keeps a large queue from firing hundreds
/// of downloads at once, and a per-URI retry window means a failed resolution
/// is not retried on every position tick.
class CoverPrefetchCoordinator {
  /// Creates a coordinator. Call [start] to subscribe.
  CoverPrefetchCoordinator({
    required CoverService service,
    required PlaybackController controller,
  }) : _service = service, // ignore: prefer_initializing_formals
       _controller = controller; // ignore: prefer_initializing_formals

  /// Maximum number of cover downloads in flight at once.
  static const int maxConcurrent = 4;

  /// How long a failed resolution is suppressed before it may be retried.
  static const Duration retryAfter = Duration(minutes: 10);

  final CoverService _service;
  final PlaybackController _controller;

  final Set<String> _inFlight = <String>{};
  final Map<String, DateTime> _lastAttempt = <String, DateTime>{};

  StreamSubscription<PlaybackState>? _subscription;
  bool _disposed = false;

  /// Subscribes to playback state and warms the queue already loaded. Idempotent.
  void start() {
    if (_disposed || _subscription != null) return;
    _subscription = _controller.state.listen(_onState);
    _onState(_controller.currentState);
  }

  /// Cancels the subscription; further state changes are ignored.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _subscription?.cancel();
    _subscription = null;
    _inFlight.clear();
  }

  void _onState(PlaybackState state) {
    if (_disposed) return;
    final now = DateTime.now();

    // Bound the retry map so a long session cannot grow it without limit.
    if (_lastAttempt.length > 256) {
      _lastAttempt.removeWhere((_, at) => now.difference(at) >= retryAfter);
    }

    for (final track in _controller.queue.tracks) {
      if (_inFlight.length >= maxConcurrent) return;
      if (_inFlight.contains(track.uri)) continue;

      // Cheap guards first: this list is scanned on every state tick (~5 Hz),
      // so the filesystem stat in `_hasUsableCover` must not run for tracks
      // that cannot carry a remote cover. Only Bilibili tracks can today.
      final hasRemoteUrl =
          track.coverUrl != null && track.coverUrl!.isNotEmpty;
      if (!hasRemoteUrl && track.sourceTrackId is! BiliTrackId) continue;

      final last = _lastAttempt[track.uri];
      if (last != null && now.difference(last) < retryAfter) continue;
      if (_hasUsableCover(track)) continue;

      _lastAttempt[track.uri] = now;
      _inFlight.add(track.uri);
      unawaited(_resolve(track));
    }
  }

  Future<void> _resolve(Track track) async {
    try {
      final path = await _service.ensureCover(track);
      if (path != null && !_disposed) {
        await _controller.updateTrackCover(
          track.uri,
          coverPath: path,
          coverUrl: track.coverUrl,
        );
      }
    } catch (error) {
      debugPrint('CoverPrefetchCoordinator: ${track.uri}: $error');
    } finally {
      _inFlight.remove(track.uri);
    }
  }

  static bool _hasUsableCover(Track track) {
    final path = track.coverPath;
    return path != null && path.isNotEmpty && File(path).existsSync();
  }
}
