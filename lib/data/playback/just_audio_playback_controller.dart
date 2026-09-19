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
import 'dart:math';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'package:flind_player/core/models/playback_queue.dart';
import 'package:flind_player/core/models/playback_state.dart';
import 'package:flind_player/core/models/repeat_mode.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/services/playback_controller.dart';
import 'package:flind_player/core/sources/stream_resolver.dart';

/// [PlaybackController] backed by a single [AudioPlayer] from `just_audio`.
///
/// Playback is deliberately **one track at a time**: the current track is
/// resolved on demand through the injected [StreamResolver] and handed to
/// [AudioPlayer.setAudioSource]. Advancing the queue re-resolves the next
/// track. A static `ConcatenatingAudioSource` playlist is not used because
/// future sources (Bilibili) produce per-track, expiring URLs that require
/// request headers; those cannot be baked into a long-lived playlist.
class JustAudioPlaybackController implements PlaybackController {
  /// Minimum interval between position updates folded into [PlaybackState].
  static const Duration _positionThrottleInterval = Duration(milliseconds: 200);

  final StreamResolver _resolver;
  final AudioPlayer _player;

  final StreamController<PlaybackState> _stateController =
      StreamController<PlaybackState>.broadcast();

  final List<StreamSubscription<Object?>> _subscriptions =
      <StreamSubscription<Object?>>[];

  PlaybackQueue _queue = PlaybackQueue.empty;
  RepeatMode _repeatMode = RepeatMode.off;
  bool _shuffle = false;

  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _isCompleted = false;
  Duration _position = Duration.zero;
  Duration? _duration;

  bool _disposed = false;
  bool _handlingCompletion = false;

  PlaybackState _currentState = PlaybackState.idle;

  DateTime? _lastPositionEmit;
  Timer? _positionTimer;
  Duration? _pendingPosition;

  /// Creates a controller.
  ///
  /// [player] is injectable for testing; when omitted a new [AudioPlayer] is
  /// created. The injected player is disposed by [dispose].
  JustAudioPlaybackController({
    required StreamResolver resolver,
    AudioPlayer? player,
  }) : _resolver = resolver, // ignore: prefer_initializing_formals
       _player = player ?? AudioPlayer() {
    _configureAudioSession();
    _bindPlayerStreams();
    _emit();
  }

  @override
  Stream<PlaybackState> get state => _stateController.stream;

  @override
  PlaybackState get currentState => _currentState;

  @override
  PlaybackQueue get queue => _queue;

  @override
  Future<void> playQueue(
    PlaybackQueue queue, {
    int index = 0,
    bool autoPlay = true,
  }) async {
    if (_disposed) {
      return;
    }

    final clamped = queue.isEmpty ? -1 : index.clamp(0, queue.length - 1);
    var next = queue.copyWith(currentIndex: clamped);
    if (_shuffle) {
      next = next.shuffled(Random());
    }

    _queue = next;
    _emit();
    await _playCurrent(autoPlay: autoPlay);
  }

  @override
  Future<void> updateTrackCover(
    String uri, {
    String? coverPath,
    String? coverUrl,
  }) async {
    if (_disposed) {
      return;
    }
    final index = _queue.tracks.indexWhere((track) => track.uri == uri);
    if (index < 0) {
      return;
    }
    final tracks = List<Track>.of(_queue.tracks);
    tracks[index] = tracks[index].copyWith(
      coverPath: coverPath,
      coverUrl: coverUrl,
    );
    _queue = _queue.copyWith(tracks: tracks);
    _emit();
  }

  @override
  Future<void> play() async {
    if (_disposed) {
      return;
    }
    if (_isCompleted) {
      // just_audio will not restart a completed source; rewind first.
      _isCompleted = false;
      _position = Duration.zero;
      _cancelPositionThrottle();
      _emit();
      await _player.seek(Duration.zero);
    }
    await _player.play();
  }

  @override
  Future<void> pause() async {
    if (_disposed) {
      return;
    }
    await _player.pause();
  }

  @override
  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  @override
  Future<void> next() async {
    if (_disposed) {
      return;
    }
    final target = _queue.nextIndex(repeatMode: _repeatMode);
    if (target == null) {
      return;
    }
    _queue = _queue.copyWith(currentIndex: target);
    _emit();
    await _playCurrent();
  }

  @override
  Future<void> previous() async {
    if (_disposed) {
      return;
    }
    final target = _queue.previousIndex(repeatMode: _repeatMode);
    if (target == null) {
      return;
    }
    _queue = _queue.copyWith(currentIndex: target);
    _emit();
    await _playCurrent();
  }

  @override
  Future<void> seek(Duration position) async {
    if (_disposed) {
      return;
    }
    _cancelPositionThrottle();
    _position = position;
    _isCompleted = false;
    _emit();
    await _player.seek(position);
  }

  @override
  Future<void> setRepeatMode(RepeatMode mode) async {
    if (_disposed || _repeatMode == mode) {
      return;
    }
    _repeatMode = mode;
    _emit();
  }

  @override
  Future<void> setShuffle(bool enabled) async {
    if (_disposed || _shuffle == enabled) {
      return;
    }
    _shuffle = enabled;
    // shuffled()/unshuffled() keep the current track; playback is untouched.
    _queue = enabled ? _queue.shuffled(Random()) : _queue.unshuffled();
    _emit();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;

    _cancelPositionThrottle();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();

    try {
      await _player.dispose();
    } catch (error) {
      debugPrint('JustAudioPlaybackController: player dispose failed: $error');
    }

    await _stateController.close();
  }

  /// Configures the platform audio session once, for music playback.
  ///
  /// This is a no-op on Linux desktop but required for correct audio focus on
  /// Android and iOS.
  void _configureAudioSession() {
    try {
      unawaited(
        AudioSession.instance
            .then(
              (session) =>
                  session.configure(const AudioSessionConfiguration.music()),
            )
            .catchError((Object error) {
              debugPrint(
                'JustAudioPlaybackController: audio session config failed: '
                '$error',
              );
              return false;
            }),
      );
    } catch (error) {
      debugPrint(
        'JustAudioPlaybackController: audio session unavailable: $error',
      );
    }
  }

  void _bindPlayerStreams() {
    _subscriptions
      ..add(_player.playingStream.listen(_onPlaying))
      ..add(_player.positionStream.listen(_onPosition))
      ..add(_player.durationStream.listen(_onDuration))
      // just_audio 0.10.6 exposes no `bufferingStream`; buffering is a
      // `ProcessingState` on `processingStateStream`.
      ..add(_player.processingStateStream.listen(_onProcessingState))
      ..add(_player.playerStateStream.listen(_onPlayerState));
  }

  void _onPlaying(bool playing) {
    if (_isPlaying == playing) {
      return;
    }
    _isPlaying = playing;
    if (playing) {
      _isCompleted = false;
    }
    _emit();
  }

  void _onProcessingState(ProcessingState state) {
    final buffering = state == ProcessingState.buffering;
    if (_isBuffering == buffering) {
      return;
    }
    _isBuffering = buffering;
    _emit();
  }

  void _onDuration(Duration? duration) {
    // Fall back to the track's metadata when the engine reports no duration.
    final next = duration ?? _queue.currentTrack?.duration ?? _duration;
    if (next == _duration) {
      return;
    }
    _duration = next;
    _emit();
  }

  void _onPlayerState(PlayerState state) {
    if (state.processingState == ProcessingState.completed) {
      unawaited(_handleCompletion());
    }
  }

  void _onPosition(Duration position) {
    final last = _lastPositionEmit;
    final now = DateTime.now();
    if (last == null || now.difference(last) >= _positionThrottleInterval) {
      _lastPositionEmit = now;
      _applyPosition(position);
      return;
    }

    _pendingPosition = position;
    _positionTimer ??= Timer(
      _positionThrottleInterval - now.difference(last),
      _flushPendingPosition,
    );
  }

  void _flushPendingPosition() {
    _positionTimer = null;
    final pending = _pendingPosition;
    _pendingPosition = null;
    if (pending == null) {
      return;
    }
    _lastPositionEmit = DateTime.now();
    _applyPosition(pending);
  }

  void _applyPosition(Duration position) {
    if (position == _position) {
      return;
    }
    _position = position;
    _emit();
  }

  void _cancelPositionThrottle() {
    _positionTimer?.cancel();
    _positionTimer = null;
    _pendingPosition = null;
    _lastPositionEmit = null;
  }

  /// Handles the end of the current track.
  Future<void> _handleCompletion() async {
    if (_disposed || _handlingCompletion) {
      return;
    }
    _handlingCompletion = true;
    try {
      if (_repeatMode == RepeatMode.one) {
        await seek(Duration.zero);
        await _player.play();
        return;
      }

      if (_queue.nextIndex(repeatMode: _repeatMode) == null) {
        // End of queue with repeat off: stop and keep the final position.
        _position = _player.position;
        _isCompleted = true;
        _isPlaying = false;
        await _player.pause();
        _emit();
        return;
      }

      await next();
    } catch (error, stackTrace) {
      debugPrint(
        'JustAudioPlaybackController: completion handling failed: $error\n'
        '$stackTrace',
      );
      _isPlaying = false;
      _emit();
    } finally {
      _handlingCompletion = false;
    }
  }

  /// Resolves and plays [_queue]'s current track.
  Future<void> _playCurrent({bool autoPlay = true}) async {
    final track = _queue.currentTrack;
    if (track == null) {
      _cancelPositionThrottle();
      _isPlaying = false;
      _isBuffering = false;
      _isCompleted = false;
      _position = Duration.zero;
      _duration = null;
      _emit();
      return;
    }

    _cancelPositionThrottle();
    _isCompleted = false;
    _position = Duration.zero;
    _duration = track.duration;
    _emit();

    try {
      final info = await _resolver.resolve(track);
      await _player.setAudioSource(
        AudioSource.uri(
          info.url,
          headers: info.headers.isEmpty ? null : info.headers,
        ),
      );
      if (autoPlay) {
        await _player.play();
      }
    } catch (error, stackTrace) {
      debugPrint(
        'JustAudioPlaybackController: failed to play "${track.uri}": '
        '$error\n$stackTrace',
      );
      _isPlaying = false;
      _isBuffering = false;
      _emit();
    }
  }

  void _emit() {
    if (_disposed) {
      return;
    }
    _currentState = _buildState();
    if (!_stateController.isClosed) {
      _stateController.add(_currentState);
    }
  }

  PlaybackState _buildState() {
    return PlaybackState(
      isPlaying: _isPlaying,
      isBuffering: _isBuffering,
      isCompleted: _isCompleted,
      position: _position,
      duration: _duration,
      currentTrack: _queue.currentTrack,
      repeatMode: _repeatMode,
      shuffleEnabled: _shuffle,
      hasNext: _queue.nextIndex(repeatMode: _repeatMode) != null,
      hasPrevious: _queue.previousIndex(repeatMode: _repeatMode) != null,
    );
  }
}
