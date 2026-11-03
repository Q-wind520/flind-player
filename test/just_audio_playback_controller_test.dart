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
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

import 'package:flind_player/core/models/playback_queue.dart';
import 'package:flind_player/core/models/repeat_mode.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/music_source.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/core/sources/stream_resolver.dart';
import 'package:flind_player/core/services/playback_controller.dart';
import 'package:flind_player/data/playback/just_audio_playback_controller.dart';

/// Resolver returning a fixed, non-network stream.
class _FakeResolver implements StreamResolver {
  @override
  Future<StreamInfo> resolve(Track track) async =>
      StreamInfo(url: Uri.parse('https://cdn.example/${track.title}.mp3'));
}

/// Resolver whose stream carries the request headers online sources need
/// (Referer / User-Agent), which makes just_audio route it through its proxy.
class _HeaderResolver implements StreamResolver {
  @override
  Future<StreamInfo> resolve(Track track) async => StreamInfo(
    url: Uri.parse('https://cdn.example/${track.title}.mp3'),
    headers: const {'Referer': 'https://example.com'},
  );
}

Track _biliTrack(String title) => Track(
  source: 'bilibili',
  sourceTrackId: BiliTrackId(bvid: 'BV_$title', cid: 1),
  uri: 'bilibili:BV_$title:1',
  title: title,
  duration: const Duration(minutes: 3),
);

PlaybackQueue _queueOf(List<Track> tracks) => PlaybackQueue(
  tracks: tracks,
  currentIndex: 0,
  originalOrder: [for (var i = 0; i < tracks.length; i++) i],
);

/// A `JustAudioPlatform` whose player is fully controllable from the test.
class _FakeJustAudio extends JustAudioPlatform {
  _FakeAudioPlayer? player;

  /// Applied to the player created by `init`.
  bool holdPlayFuture = false;

  /// Applied to [load] calls, mirroring a stream that cannot be opened.
  bool failNextLoad = false;

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    return player = _FakeAudioPlayer(request.id)
      ..holdPlayFuture = holdPlayFuture
      ..failNextLoad = failNextLoad;
  }

  @override
  Future<DisposePlayerResponse> disposePlayer(
    DisposePlayerRequest request,
  ) async => DisposePlayerResponse();

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(
    DisposeAllPlayersRequest request,
  ) async => DisposeAllPlayersResponse();
}

class _FakeAudioPlayer extends AudioPlayerPlatform {
  _FakeAudioPlayer(super.id);

  final _events = StreamController<PlaybackEventMessage>.broadcast();
  final List<String> calls = <String>[];

  ProcessingStateMessage _processingState = ProcessingStateMessage.idle;
  Duration _position = Duration.zero;
  DateTime _updateTime = DateTime.now();
  bool _playing = false;
  bool _active = false;
  Duration? _duration;
  int? _index;

  int playCalls = 0;
  int pauseCalls = 0;

  /// Mirrors Android: the platform only resolves `play` once playback stops
  /// (pause or end of source), never while a track is simply playing.
  bool holdPlayFuture = false;
  final List<Completer<void>> _heldPlays = <Completer<void>>[];

  /// When set, the next [load] call fails like an unreachable or 403 stream.
  bool failNextLoad = false;
  int loadCalls = 0;

  /// URI the platform was actually asked to load (after any proxy rewrite).
  final List<String> loadUris = <String>[];

  void _collectLoadUris(AudioSourceMessage message) {
    if (message is UriAudioSourceMessage) {
      loadUris.add(message.uri);
    }
    if (message is ConcatenatingAudioSourceMessage) {
      for (final child in message.children) {
        _collectLoadUris(child);
      }
    }
  }
  final List<double> volumes = <double>[];
  final List<double> speeds = <double>[];
  double volume = 1.0;
  double speed = 1.0;

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream => _events.stream;

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    calls.add('load');
    loadCalls++;
    _collectLoadUris(request.audioSourceMessage);
    if (failNextLoad) {
      failNextLoad = false;
      throw PlatformException(code: 'error', message: 'stream unavailable');
    }
    _duration = const Duration(minutes: 3);
    _index = request.initialIndex ?? 0;
    _position = request.initialPosition ?? Duration.zero;
    _active = true;
    _processingState = ProcessingStateMessage.loading;
    _emit();
    _processingState = ProcessingStateMessage.ready;
    _emit();
    return LoadResponse(duration: _duration);
  }

  @override
  Future<PlayResponse> play(PlayRequest request) async {
    calls.add('play');
    playCalls++;
    _playing = true;
    _emit();
    if (holdPlayFuture) {
      final completer = Completer<void>();
      _heldPlays.add(completer);
      await completer.future;
    }
    return PlayResponse();
  }

  @override
  Future<PauseResponse> pause(PauseRequest request) async {
    calls.add('pause');
    pauseCalls++;
    _playing = false;
    _resolveHeldPlays();
    _emit();
    return PauseResponse();
  }

  /// Resolves pending [play] futures the way the platform does when playback
  /// stops for any reason.
  void _resolveHeldPlays() {
    for (final completer in _heldPlays) {
      if (!completer.isCompleted) completer.complete();
    }
    _heldPlays.clear();
  }

  @override
  Future<SeekResponse> seek(SeekRequest request) async {
    calls.add('seek:${request.position?.inMilliseconds}');
    _position = request.position ?? Duration.zero;
    _updateTime = DateTime.now();
    _emit();
    return SeekResponse();
  }

  /// Simulates the platform reaching the end of the current source.
  void emitCompleted() {
    _processingState = ProcessingStateMessage.completed;
    _emit();
  }

  /// Simulates a mid-stream playback failure (HTTP 403, decoder error, ...).
  void emitError(int code, String message) {
    _events.add(
      PlaybackEventMessage(
        processingState: _processingState,
        updateTime: _updateTime,
        updatePosition: _position,
        bufferedPosition: _position,
        duration: _duration,
        icyMetadata: null,
        currentIndex: _index,
        androidAudioSessionId: null,
        errorCode: code,
        errorMessage: message,
      ),
    );
  }

  /// Simulates the platform resuming/paused state without a transport command.
  /// (Used to drive `playingStream` if ever needed.)
  bool get isPlaying => _playing;
  Duration get position => _position;

  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async {
    volumes.add(request.volume);
    volume = request.volume;
    calls.add('volume:${request.volume}');
    return SetVolumeResponse();
  }

  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async {
    speeds.add(request.speed);
    speed = request.speed;
    calls.add('speed:${request.speed}');
    return SetSpeedResponse();
  }

  @override
  Future<SetPitchResponse> setPitch(SetPitchRequest request) async =>
      SetPitchResponse();

  @override
  Future<SetSkipSilenceResponse> setSkipSilence(
    SetSkipSilenceRequest request,
  ) async => SetSkipSilenceResponse();

  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async =>
      SetLoopModeResponse();

  @override
  Future<SetShuffleModeResponse> setShuffleMode(
    SetShuffleModeRequest request,
  ) async => SetShuffleModeResponse();

  @override
  Future<SetShuffleOrderResponse> setShuffleOrder(
    SetShuffleOrderRequest request,
  ) async => SetShuffleOrderResponse();

  @override
  Future<SetAndroidAudioAttributesResponse> setAndroidAudioAttributes(
    SetAndroidAudioAttributesRequest request,
  ) async => SetAndroidAudioAttributesResponse();

  @override
  Future<SetAutomaticallyWaitsToMinimizeStallingResponse>
  setAutomaticallyWaitsToMinimizeStalling(
    SetAutomaticallyWaitsToMinimizeStallingRequest request,
  ) async => SetAutomaticallyWaitsToMinimizeStallingResponse();

  @override
  Future<AudioEffectSetEnabledResponse> audioEffectSetEnabled(
    AudioEffectSetEnabledRequest request,
  ) async => AudioEffectSetEnabledResponse();

  @override
  Future<DisposeResponse> dispose(DisposeRequest request) async {
    await _events.close();
    return DisposeResponse();
  }

  void _emit() {
    if (!_active || _events.isClosed) return;
    _events.add(
      PlaybackEventMessage(
        processingState: _processingState,
        updateTime: _updateTime,
        updatePosition: _position,
        bufferedPosition: _position,
        duration: _duration,
        icyMetadata: null,
        currentIndex: _index,
        androidAudioSessionId: null,
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeJustAudio platform;

  setUp(() {
    platform = _FakeJustAudio();
    JustAudioPlatform.instance = platform;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.ryanheise.audio_session'),
          (call) async => null,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.ryanheise.audio_session'),
          null,
        );
  });

  const timeout = Duration(seconds: 1);

  test('a completion racing a pause does not auto-advance or resume', () async {
    final controller = JustAudioPlaybackController(resolver: _FakeResolver());
    addTearDown(controller.dispose);
    final trackA = _biliTrack('A');
    final trackB = _biliTrack('B');

    await controller.playQueue(_queueOf([trackA, trackB]));
    await Future<void>.delayed(timeout);
    expect(controller.currentState.isPlaying, isTrue);

    final playsBeforePause = platform.player!.playCalls;
    await controller.pause();
    expect(controller.currentState.isPlaying, isFalse);

    // The platform's completed event for the track that just ended arrives
    // after the user's pause: it must not start the next track.
    platform.player!.emitCompleted();
    await Future<void>.delayed(timeout);

    expect(controller.currentState.isPlaying, isFalse);
    expect(controller.currentState.currentTrack?.title, 'A');
    expect(platform.player!.playCalls, playsBeforePause);
  });

  test('a completion racing a pause in repeat-one does not restart', () async {
    final controller = JustAudioPlaybackController(resolver: _FakeResolver());
    addTearDown(controller.dispose);

    await controller.playQueue(_queueOf([_biliTrack('A')]));
    await controller.setRepeatMode(RepeatMode.one);
    await Future<void>.delayed(timeout);

    await controller.pause();
    final callsBeforeCompletion = List<String>.of(platform.player!.calls);

    platform.player!.emitCompleted();
    await Future<void>.delayed(timeout);

    expect(controller.currentState.isPlaying, isFalse);
    // Repeat-one must not rewind (`seek:0`) or restart (`play`) a paused player.
    expect(
      platform.player!.calls.sublist(callsBeforeCompletion.length),
      isEmpty,
    );
  });

  test('a normal completion still advances to the next track', () async {
    final controller = JustAudioPlaybackController(resolver: _FakeResolver());
    addTearDown(controller.dispose);
    final trackA = _biliTrack('A');
    final trackB = _biliTrack('B');

    await controller.playQueue(_queueOf([trackA, trackB]));
    await Future<void>.delayed(timeout);

    platform.player!.emitCompleted();
    await Future<void>.delayed(timeout);

    expect(controller.currentState.currentTrack?.title, 'B');
    expect(controller.currentState.isPlaying, isTrue);
  });

  test('end of queue marks completed and stays paused', () async {
    final controller = JustAudioPlaybackController(resolver: _FakeResolver());
    addTearDown(controller.dispose);

    await controller.playQueue(_queueOf([_biliTrack('A')]));
    await Future<void>.delayed(timeout);

    platform.player!.emitCompleted();
    await Future<void>.delayed(timeout);

    expect(controller.currentState.isPlaying, isFalse);
    expect(controller.currentState.isCompleted, isTrue);
  });

  test('setSpeed applies and clamps the playback rate', () async {
    final controller = JustAudioPlaybackController(resolver: _FakeResolver());
    addTearDown(controller.dispose);

    await controller.playQueue(_queueOf([_biliTrack('A')]));
    await Future<void>.delayed(timeout);

    await controller.setSpeed(1.5);
    expect(controller.currentState.speed, 1.5);
    expect(platform.player!.speeds.last, 1.5);

    await controller.setSpeed(9);
    expect(controller.currentState.speed, PlaybackController.maxSpeed);
    await controller.setSpeed(0.1);
    expect(controller.currentState.speed, PlaybackController.minSpeed);
  });

  test('pause fades the gain down then restores it', () async {
    final controller = JustAudioPlaybackController(resolver: _FakeResolver());
    addTearDown(controller.dispose);

    await controller.playQueue(_queueOf([_biliTrack('A')]));
    await Future<void>.delayed(timeout);
    expect(controller.currentState.isPlaying, isTrue);

    platform.player!.volumes.clear();
    await controller.pause();

    final volumes = platform.player!.volumes;
    expect(controller.currentState.isPlaying, isFalse);
    // The gain ramps through intermediate values on the way to silence...
    expect(volumes.any((v) => v > 0 && v < 1), isTrue);
    // ...and is restored so the next play resumes at the user's level.
    expect(volumes.last, closeTo(controller.currentState.volume, 0.001));
  });

  test('pause flips isPlaying before the fade-out completes', () async {
    final controller = JustAudioPlaybackController(resolver: _FakeResolver());
    addTearDown(controller.dispose);

    await controller.playQueue(_queueOf([_biliTrack('A')]));
    await Future<void>.delayed(timeout);
    expect(controller.currentState.isPlaying, isTrue);

    final pause = controller.pause();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    // The button/UI state changes on the press; the engine keeps playing
    // silently for the fade window before it actually pauses.
    expect(controller.currentState.isPlaying, isFalse);
    expect(platform.player!.isPlaying, isTrue);

    await pause;
    expect(platform.player!.isPlaying, isFalse);
  });

  test('play fades the gain in from silence', () async {
    final controller = JustAudioPlaybackController(resolver: _FakeResolver());
    addTearDown(controller.dispose);

    await controller.playQueue(_queueOf([_biliTrack('A')]));
    await Future<void>.delayed(timeout);
    await controller.pause();

    platform.player!.volumes.clear();
    await controller.play();
    await Future<void>.delayed(timeout);

    final volumes = platform.player!.volumes;
    expect(controller.currentState.isPlaying, isTrue);
    expect(volumes.first, 0);
    expect(volumes.any((v) => v > 0 && v < 1), isTrue);
    expect(volumes.last, closeTo(controller.currentState.volume, 0.001));
  });

  test('play fades in even when the platform play future stays pending', () async {
    // Android's `play` future resolves only once playback stops (pause or end
    // of source). Awaiting it before the gain ramp leaves the engine silent at
    // volume 0 for the whole track.
    platform.holdPlayFuture = true;
    final controller = JustAudioPlaybackController(resolver: _FakeResolver());
    addTearDown(controller.dispose);

    unawaited(controller.playQueue(_queueOf([_biliTrack('A')])));
    await Future<void>.delayed(timeout);

    final player = platform.player!;
    expect(controller.currentState.isPlaying, isTrue);
    expect(player.volumes.any((v) => v > 0 && v < 1), isTrue);
    expect(player.volume, closeTo(controller.currentState.volume, 0.001));
  });

  test('a failed load leaves playback paused and the next play retries it', () async {
    platform.failNextLoad = true;
    final controller = JustAudioPlaybackController(resolver: _FakeResolver());
    addTearDown(controller.dispose);

    await controller.playQueue(_queueOf([_biliTrack('A')]));
    await Future<void>.delayed(timeout);

    // The load failed: the UI must not claim to be playing.
    expect(controller.currentState.isPlaying, isFalse);
    final player = platform.player!;
    expect(player.loadCalls, 1);

    platform.player!.volumes.clear();
    await controller.play();
    await Future<void>.delayed(timeout);

    // Pressing play re-resolves and loads instead of "playing" the dead source.
    expect(player.loadCalls, 2);
    expect(controller.currentState.isPlaying, isTrue);
    expect(player.volumes.any((v) => v > 0 && v < 1), isTrue);
    expect(player.volume, closeTo(controller.currentState.volume, 0.001));
  });

  test('a playback error stops the UI from claiming to play', () async {
    final controller = JustAudioPlaybackController(resolver: _FakeResolver());
    addTearDown(controller.dispose);

    await controller.playQueue(_queueOf([_biliTrack('A')]));
    await Future<void>.delayed(timeout);
    expect(controller.currentState.isPlaying, isTrue);

    platform.player!.emitError(2, 'HTTP 403');
    await Future<void>.delayed(timeout);

    expect(controller.currentState.isPlaying, isFalse);
    expect(platform.player!.isPlaying, isFalse);

    // The track stays selected, so the next play can re-resolve a fresh URL.
    expect(controller.currentState.currentTrack?.title, 'A');
    final loadsBeforeReplay = platform.player!.loadCalls;
    await controller.play();
    await Future<void>.delayed(timeout);
    expect(platform.player!.loadCalls, loadsBeforeReplay + 1);
    expect(controller.currentState.isPlaying, isTrue);
  });

  test('on Android header sources bypass the loopback proxy', () async {
    // Android blocks cleartext by default. just_audio would otherwise rewrite
    // a header-bearing source to http://127.0.0.1:PORT, which the platform
    // rejects ("Cleartext HTTP traffic not permitted"), so the first tap on an
    // uncached online track stayed silent until the background downloader
    // cached the file. ExoPlayer applies the headers itself.
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final controller = JustAudioPlaybackController(resolver: _HeaderResolver());
    addTearDown(controller.dispose);

    await controller.playQueue(_queueOf([_biliTrack('A')]));
    await Future<void>.delayed(timeout);

    final uri = Uri.parse(platform.player!.loadUris.single);
    expect(uri.scheme, 'https');
    expect(uri.host, 'cdn.example');
    expect(controller.currentState.isPlaying, isTrue);
  });

  test('switching tracks stops the outgoing one before loading', () async {
    final controller = JustAudioPlaybackController(resolver: _FakeResolver());
    addTearDown(controller.dispose);
    final trackA = _biliTrack('A');
    final trackB = _biliTrack('B');

    await controller.playQueue(_queueOf([trackA, trackB]));
    await Future<void>.delayed(timeout);

    platform.player!.calls.clear();
    await controller.playQueue(_queueOf([trackA, trackB]), index: 1);
    await Future<void>.delayed(timeout);

    final calls = platform.player!.calls;
    expect(calls.indexOf('pause'), isNonNegative);
    expect(
      calls.indexOf('pause'),
      lessThan(calls.indexOf('load')),
      reason: 'the previous track must be stopped before the next loads',
    );
    expect(controller.currentState.currentTrack?.title, 'B');
    expect(controller.currentState.isPlaying, isTrue);
  });
}
