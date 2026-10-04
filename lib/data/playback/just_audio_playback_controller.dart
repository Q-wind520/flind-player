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

  /// Quietest volume the UI can select (1%).
  static const double minVolume = 0.01;

  /// Loudest volume the UI can select (140%).
  static const double maxVolume = 1.4;

  /// How long the fade-in/fade-out gain ramp takes.
  static const Duration _fadeDuration = Duration(milliseconds: 400);

  /// Steps the gain ramp is split into; each step is [_fadeDuration] / this.
  static const int _fadeSteps = 10;

  final StreamResolver _resolver;
  final AudioPlayer _player;

  final StreamController<PlaybackState> _stateController =
      StreamController<PlaybackState>.broadcast();

  final List<StreamSubscription<Object?>> _subscriptions =
      <StreamSubscription<Object?>>[];

  PlaybackQueue _queue = PlaybackQueue.empty;
  RepeatMode _repeatMode = RepeatMode.off;
  bool _shuffle = false;
  double _volume = 1.0;
  double _speed = 1.0;

  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _isCompleted = false;
  Duration _position = Duration.zero;
  Duration? _duration;

  bool _disposed = false;
  bool _handlingCompletion = false;

  /// Whether the user currently wants playback to be running.
  ///
  /// Source loading is asynchronous ([_playCurrent]); recording the desired
  /// state separately lets a transport command issued while a track is
  /// resolving win over the load finishing. Without this, pausing during a
  /// slow (first, uncached) resolve was silently undone by the trailing
  /// `play()`, restarting the track from the beginning.
  bool _playIntent = false;

  /// True while [_playCurrent] is resolving/loading a source.
  ///
  /// [AudioPlayer.play] on an empty playlist never completes, so transport
  /// commands must not reach the player until the source is loaded;
  /// [_playCurrent] honours [_playIntent] once loading finishes.
  bool _loadInFlight = false;

  /// Incremented for every [_playCurrent]; lets a stale load that is overtaken
  /// by a newer one abandon its work instead of clobbering the live source.
  int _loadGeneration = 0;

  /// Bumped to cancel an in-flight pause/switch gain ramp.
  int _fadeGeneration = 0;

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
    _playIntent = autoPlay;
    _emit();
    await _playCurrent();
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
    _playIntent = true;
    // A resume supersedes any in-flight ramp.
    _fadeGeneration++;
    if (_isCompleted) {
      // just_audio will not restart a completed source; rewind first.
      _isCompleted = false;
      _position = Duration.zero;
      _cancelPositionThrottle();
      _emit();
      await _player.seek(Duration.zero);
    }
    if (_player.playing) {
      // Already audible (e.g. a resumed mid-fade pause): restore the gain
      // instead of restarting a fade-in.
      await _setPlayerVolume(_volume);
      return;
    }
    await _startIfReady();
  }

  @override
  Future<void> pause() async {
    if (_disposed) {
      return;
    }
    _playIntent = false;
    await _fadeOutAndPause();
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
    _playIntent = true;
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
    _playIntent = true;
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
  Future<void> setVolume(double volume) async {
    if (_disposed) {
      return;
    }
    final clamped = volume.clamp(minVolume, maxVolume);
    if ((clamped - _volume).abs() < 0.0001) {
      return;
    }
    _volume = clamped;
    _emit();
    await _setPlayerVolume(_volume);
  }

  @override
  Future<void> setSpeed(double speed) async {
    if (_disposed) {
      return;
    }
    final clamped = speed.clamp(
      PlaybackController.minSpeed,
      PlaybackController.maxSpeed,
    );
    if ((clamped - _speed).abs() < 0.0001) {
      return;
    }
    _speed = clamped;
    _emit();
    try {
      await _player.setSpeed(_speed);
    } catch (error, stackTrace) {
      debugPrint(
        'JustAudioPlaybackController: setSpeed failed: $error\n$stackTrace',
      );
    }
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
      // A transport command that landed in the same instant the track ended
      // must win. Without this, a `completed` event racing a pause would
      // auto-advance to the next track, or (repeat-one) `seek(0)` + play the
      // same track again — the "pause restarts the song" bug.
      if (!_playIntent) {
        _position = _player.position;
        _isCompleted = true;
        _isPlaying = false;
        await _player.pause();
        _emit();
        return;
      }

      if (_repeatMode == RepeatMode.one) {
        _playIntent = true;
        await seek(Duration.zero);
        await _startIfReady();
        return;
      }

      if (_queue.nextIndex(repeatMode: _repeatMode) == null) {
        // End of queue with repeat off: stop and keep the final position.
        _position = _player.position;
        _isCompleted = true;
        _isPlaying = false;
        _playIntent = false;
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

  /// Resolves and loads [_queue]'s current track, then honours [_playIntent].
  ///
  /// The resolve/load is asynchronous and may take a long time for a cold
  /// online source. User transport commands issued meanwhile update
  /// [_playIntent] (and [_loadGeneration] when a newer track supersedes this
  /// one); those values are re-checked after every `await` so a pause can never
  /// be undone by the load finishing.
  Future<void> _playCurrent() async {
    final track = _queue.currentTrack;
    if (track == null) {
      _loadGeneration++;
      _loadInFlight = false;
      _playIntent = false;
      _cancelPositionThrottle();
      _isPlaying = false;
      _isBuffering = false;
      _isCompleted = false;
      _position = Duration.zero;
      _duration = null;
      _emit();
      return;
    }

    final generation = ++_loadGeneration;
    _loadInFlight = true;
    // Stop the outgoing track immediately: a switch must not leave the previous
    // song audible through the (possibly slow) resolve of the next one. This
    // also cancels any in-flight pause fade and restores the user's gain.
    _fadeGeneration++;
    if (_player.playing) {
      await _player.pause();
    }
    await _setPlayerVolume(_volume);
    _cancelPositionThrottle();
    _isCompleted = false;
    _position = Duration.zero;
    _duration = track.duration;
    _emit();

    try {
      final info = await _resolver.resolve(track);
      if (generation != _loadGeneration) {
        return;
      }
      await _player.setAudioSource(
        AudioSource.uri(
          info.url,
          headers: info.headers.isEmpty ? null : info.headers,
        ),
      );
      if (generation != _loadGeneration) {
        return;
      }
      // Some platforms reset the gain when a new source is loaded; re-apply
      // the user's chosen volume so switching tracks never changes loudness.
      await _setPlayerVolume(_volume);
      if (generation != _loadGeneration) {
        return;
      }
    } catch (error, stackTrace) {
      if (generation != _loadGeneration) {
        return;
      }
      debugPrint(
        'JustAudioPlaybackController: failed to play "${track.uri}": '
        '$error\n$stackTrace',
      );
      _loadInFlight = false;
      _isPlaying = false;
      _isBuffering = false;
      _emit();
      return;
    }

    _loadInFlight = false;
    // Honour the latest intent. A pause issued while this track was resolving
    // or loading must win over the load finishing.
    if (_playIntent) {
      await _startIfReady();
    } else {
      // Enforce the pause in case the platform auto-started the fresh source.
      await _player.pause();
    }
  }

  /// Starts playback once a source is loaded and no load is in flight.
  ///
  /// Calling [AudioPlayer.play] before an audio source exists leaves its future
  /// pending forever, so commands issued while a track loads defer to
  /// [_playCurrent], which calls this after the source is ready.
  ///
  /// The track starts silent and its gain ramps up to the user's level, so
  /// starting/resuming/switching fades in.
  Future<void> _startIfReady() async {
    if (_disposed ||
        _loadInFlight ||
        !_playIntent ||
        _player.audioSource == null) {
      return;
    }
    if (_player.playing) {
      // Already audible: an in-flight ramp owns the gain.
      return;
    }
    final generation = ++_fadeGeneration;
    await _setPlayerVolume(0);
    if (_disposed ||
        _fadeGeneration != generation ||
        !_playIntent ||
        _loadInFlight) {
      return;
    }
    await _player.play();
    unawaited(_rampVolumeTo(_volume, generation));
  }

  /// Ramps the output gain to zero over [_fadeDuration], pauses, then restores
  /// the user's gain so the next play resumes at the chosen level.
  ///
  /// Cancellable: a resume or track switch bumps [_fadeGeneration], aborting the
  /// ramp and leaving the player to that command.
  Future<void> _fadeOutAndPause() async {
    final generation = ++_fadeGeneration;
    final target = _volume;
    if (_isPlaying && target > 0 && _player.playing) {
      await _rampVolumeTo(0, generation);
      if (_disposed || _fadeGeneration != generation) {
        return;
      }
    }
    await _player.pause();
    if (!_disposed && _fadeGeneration == generation) {
      await _setPlayerVolume(target);
    }
  }

  /// Ramps the engine gain from its current value to [target] in [_fadeSteps]
  /// steps over [_fadeDuration]. No-op once [generation] is superseded.
  Future<void> _rampVolumeTo(double target, int generation) async {
    final start = _player.volume;
    final stepDelay = _fadeDuration ~/ _fadeSteps;
    for (var step = 1; step <= _fadeSteps; step++) {
      if (_disposed || _fadeGeneration != generation) {
        return;
      }
      await _setPlayerVolume(start + (target - start) * (step / _fadeSteps));
      await Future<void>.delayed(stepDelay);
    }
    if (_disposed || _fadeGeneration != generation) {
      return;
    }
    await _setPlayerVolume(target);
  }

  /// Applies [value] to the engine, logging and swallowing failures so a
  /// platform that rejects the call never breaks transport handling.
  Future<void> _setPlayerVolume(double value) async {
    try {
      await _player.setVolume(value);
    } catch (error, stackTrace) {
      debugPrint(
        'JustAudioPlaybackController: setVolume failed: $error\n$stackTrace',
      );
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
      volume: _volume,
      speed: _speed,
    );
  }
}
