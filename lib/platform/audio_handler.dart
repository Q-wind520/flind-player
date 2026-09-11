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

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';

import 'package:flind_player/core/models/playback_queue.dart';
import 'package:flind_player/core/models/playback_state.dart' as domain;
import 'package:flind_player/core/models/repeat_mode.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/services/playback_controller.dart';

/// Adapts a [PlaybackController] to `audio_service`.
///
/// Publishes the controller's state to the platform (Android media
/// notification / lock screen, Linux MPRIS, ...) and forwards transport
/// commands from the platform back into the controller.
class FlindAudioHandler extends BaseAudioHandler {
  /// Maximum number of queue entries published to the platform.
  ///
  /// Android marshals the queue over a Binder transaction whose buffer is
  /// shared and comparatively small (~1 MiB). Publishing an unbounded queue of
  /// large media items can overflow it and kill the process with
  /// `TransactionTooLargeException`, so only the first window is sent. The
  /// controller still owns and plays the full queue.
  static const int maxQueueWindow = 250;

  final PlaybackController _playback;
  StreamSubscription<domain.PlaybackState>? _subscription;

  bool _disposed = false;
  String? _lastMediaItemId;
  PlaybackQueue? _lastQueue;

  FlindAudioHandler({required this._playback}) {
    _subscription = _playback.state.listen(_onState, onError: _onError);
    // The controller's stream is a broadcast stream and may have emitted
    // before this handler attached; seed from its latest snapshot so the
    // platform reflects playback that started earlier.
    _onState(_playback.currentState);
  }

  @override
  Future<void> play() => _guard('play', _playback.play);

  @override
  Future<void> pause() => _guard('pause', _playback.pause);

  @override
  Future<void> seek(Duration position) =>
      _guard('seek', () => _playback.seek(position));

  @override
  Future<void> skipToNext() => _guard('skipToNext', _playback.next);

  @override
  Future<void> skipToPrevious() => _guard('skipToPrevious', _playback.previous);

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) => _guard(
    'setRepeatMode',
    () => _playback.setRepeatMode(_toRepeatMode(repeatMode)),
  );

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) => _guard(
    'setShuffleMode',
    () => _playback.setShuffle(shuffleMode != AudioServiceShuffleMode.none),
  );

  @override
  Future<void> stop() async {
    // The domain controller has no `stop`; pausing is the closest analogue.
    await _guard('stop', _playback.pause);
    await _cancelSubscription();
    if (_disposed) {
      return;
    }
    _publish(
      'idle state',
      () => playbackState.add(
        playbackState.value.copyWith(
          processingState: AudioProcessingState.idle,
          playing: false,
        ),
      ),
    );
  }

  /// Cancels the state subscription and closes the published streams.
  ///
  /// The [PlaybackController] is owned by its provider and is not disposed
  /// here.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _cancelSubscription();
    await playbackState.close();
    await mediaItem.close();
    await queue.close();
  }

  Future<void> _cancelSubscription() async {
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }

  void _onState(domain.PlaybackState state) {
    if (_disposed) {
      return;
    }
    _publish(
      'playback state',
      () => playbackState.add(_toPlaybackState(state)),
    );
    _publish('media item', () => _publishMediaItem(state));
    _publish('queue', _publishQueue);
  }

  void _publishMediaItem(domain.PlaybackState state) {
    final track = state.currentTrack;
    if (track == null) {
      if (_lastMediaItemId != null) {
        _lastMediaItemId = null;
        mediaItem.add(null);
      }
      return;
    }
    // Position ticks re-emit the same track; only publish when it changes.
    if (track.uri == _lastMediaItemId) {
      return;
    }
    _lastMediaItemId = track.uri;
    mediaItem.add(_toMediaItem(track));
  }

  void _publishQueue() {
    final next = _playback.queue;
    if (identical(next, _lastQueue) || next == _lastQueue) {
      return;
    }
    _lastQueue = next;
    final tracks = next.tracks.length > maxQueueWindow
        ? next.tracks.take(maxQueueWindow)
        : next.tracks;
    queue.add([for (final track in tracks) _toMediaItem(track)]);
  }

  PlaybackState _toPlaybackState(domain.PlaybackState state) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        state.isPlaying ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: _toProcessingState(state),
      playing: state.isPlaying,
      updatePosition: state.position,
      repeatMode: _toAudioServiceRepeatMode(state.repeatMode),
      shuffleMode: _toAudioServiceShuffleMode(state.shuffleEnabled),
    );
  }

  MediaItem _toMediaItem(Track track) {
    return MediaItem(
      id: track.uri,
      title: track.title,
      artist: track.artist,
      album: track.album,
      duration: track.duration,
      extras: <String, dynamic>{'source': track.source},
    );
  }

  AudioProcessingState _toProcessingState(domain.PlaybackState state) {
    if (state.isBuffering) {
      return AudioProcessingState.buffering;
    }
    if (state.isCompleted) {
      return AudioProcessingState.completed;
    }
    return AudioProcessingState.ready;
  }

  AudioServiceRepeatMode _toAudioServiceRepeatMode(RepeatMode mode) {
    switch (mode) {
      case RepeatMode.off:
        return AudioServiceRepeatMode.none;
      case RepeatMode.all:
        return AudioServiceRepeatMode.all;
      case RepeatMode.one:
        return AudioServiceRepeatMode.one;
    }
  }

  RepeatMode _toRepeatMode(AudioServiceRepeatMode mode) {
    switch (mode) {
      case AudioServiceRepeatMode.none:
      case AudioServiceRepeatMode.group:
        return RepeatMode.off;
      case AudioServiceRepeatMode.all:
        return RepeatMode.all;
      case AudioServiceRepeatMode.one:
        return RepeatMode.one;
    }
  }

  AudioServiceShuffleMode _toAudioServiceShuffleMode(bool enabled) {
    return enabled ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none;
  }

  Future<void> _guard(String operation, Future<void> Function() action) async {
    try {
      await action();
    } catch (error, stackTrace) {
      debugPrint('FlindAudioHandler: $operation failed: $error\n$stackTrace');
    }
  }

  void _publish(String what, void Function() action) {
    try {
      action();
    } catch (error, stackTrace) {
      // Never let a platform publish failure escape into the controller's
      // stream; the previously published (last good) state stays in place.
      debugPrint(
        'FlindAudioHandler: failed to publish $what: $error\n$stackTrace',
      );
    }
  }

  void _onError(Object error, StackTrace stackTrace) {
    debugPrint(
      'FlindAudioHandler: playback state stream error: $error\n$stackTrace',
    );
  }
}
