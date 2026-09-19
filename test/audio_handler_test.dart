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
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/playback_queue.dart';
import 'package:flind_player/core/models/playback_state.dart' as domain;
import 'package:flind_player/core/models/repeat_mode.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/services/playback_controller.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/platform/audio_handler.dart';

/// A [PlaybackController] whose state stream is driven by the test.
class _FakePlaybackController implements PlaybackController {
  final StreamController<domain.PlaybackState> _states =
      StreamController<domain.PlaybackState>.broadcast();

  domain.PlaybackState _current = domain.PlaybackState.idle;
  PlaybackQueue _queue = PlaybackQueue.empty;

  int playCalls = 0;
  int pauseCalls = 0;
  int nextCalls = 0;
  int previousCalls = 0;
  Duration? lastSeek;
  RepeatMode? lastRepeatMode;
  bool? lastShuffle;
  double? lastVolume;

  @override
  Stream<domain.PlaybackState> get state => _states.stream;

  @override
  domain.PlaybackState get currentState => _current;

  @override
  PlaybackQueue get queue => _queue;

  void setQueue(PlaybackQueue queue) {
    _queue = queue;
  }

  void emit(domain.PlaybackState state) {
    _current = state;
    _states.add(state);
  }

  @override
  Future<void> play() async {
    playCalls++;
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
  }

  @override
  Future<void> togglePlayPause() async {}

  @override
  Future<void> next() async {
    nextCalls++;
  }

  @override
  Future<void> previous() async {
    previousCalls++;
  }

  @override
  Future<void> seek(Duration position) async {
    lastSeek = position;
  }

  @override
  Future<void> setRepeatMode(RepeatMode mode) async {
    lastRepeatMode = mode;
  }

  @override
  Future<void> setShuffle(bool enabled) async {
    lastShuffle = enabled;
  }

  @override
  Future<void> setVolume(double volume) async {
    lastVolume = volume;
  }

  @override
  Future<void> playQueue(
    PlaybackQueue queue, {
    int index = 0,
    bool autoPlay = true,
  }) async {}

  @override
  Future<void> updateTrackCover(
    String uri, {
    String? coverPath,
    String? coverUrl,
  }) async {}

  @override
  Future<void> dispose() async {
    await _states.close();
  }
}

Track _track({
  String uri = 'local:/music/a.mp3',
  String title = 'Title',
  String? artist = 'Artist',
  String? album = 'Album',
  Duration? duration = const Duration(minutes: 3),
  String source = 'local',
}) {
  return Track(
    source: source,
    sourceTrackId: LocalTrackId(uri),
    uri: uri,
    title: title,
    artist: artist,
    album: album,
    duration: duration,
  );
}

domain.PlaybackState _state({
  bool isPlaying = false,
  bool isBuffering = false,
  bool isCompleted = false,
  Duration position = Duration.zero,
  Track? track,
  RepeatMode repeatMode = RepeatMode.off,
  bool shuffleEnabled = false,
}) {
  return domain.PlaybackState(
    isPlaying: isPlaying,
    isBuffering: isBuffering,
    isCompleted: isCompleted,
    position: position,
    currentTrack: track,
    repeatMode: repeatMode,
    shuffleEnabled: shuffleEnabled,
  );
}

PlaybackQueue _queueOf(List<Track> tracks, {int currentIndex = 0}) {
  return PlaybackQueue(
    tracks: tracks,
    currentIndex: currentIndex,
    originalOrder: [for (var i = 0; i < tracks.length; i++) i],
  );
}

void main() {
  test('publishes a MediaItem for the current track', () async {
    final controller = _FakePlaybackController();
    final track = _track(
      title: 'Song',
      artist: 'Singer',
      duration: const Duration(seconds: 185),
    );
    controller.setQueue(_queueOf([track]));
    final handler = FlindAudioHandler(playback: controller);

    controller.emit(_state(isPlaying: true, track: track));
    await pumpEventQueue();

    final item = handler.mediaItem.value;
    expect(item, isNotNull);
    expect(item!.id, track.uri);
    expect(item.title, 'Song');
    expect(item.artist, 'Singer');
    expect(item.album, 'Album');
    expect(item.duration, const Duration(seconds: 185));
    expect(item.extras, <String, dynamic>{'source': 'local'});

    await handler.dispose();
  });

  test('publishes playback controls and state', () async {
    final controller = _FakePlaybackController();
    final track = _track();
    final handler = FlindAudioHandler(playback: controller);

    controller.emit(_state(isPlaying: true, track: track));
    await pumpEventQueue();

    final state = handler.playbackState.value;
    expect(state.playing, isTrue);
    expect(state.controls, <MediaControl>[
      MediaControl.skipToPrevious,
      MediaControl.pause,
      MediaControl.skipToNext,
    ]);
    expect(state.systemActions, <MediaAction>{MediaAction.seek});
    expect(state.androidCompactActionIndices, <int>[0, 1, 2]);

    await handler.dispose();
  });

  test('does not re-publish the MediaItem on position-only ticks', () async {
    final controller = _FakePlaybackController();
    final track = _track();
    controller.setQueue(_queueOf([track]));
    final handler = FlindAudioHandler(playback: controller);

    final emissions = <MediaItem?>[];
    final subscription = handler.mediaItem.listen(emissions.add);

    controller.emit(
      _state(isPlaying: true, track: track, position: Duration.zero),
    );
    await pumpEventQueue();
    final afterFirst = emissions.whereType<MediaItem>().length;
    expect(afterFirst, 1);

    controller.emit(
      _state(
        isPlaying: true,
        track: track,
        position: const Duration(seconds: 1),
      ),
    );
    controller.emit(
      _state(
        isPlaying: true,
        track: track,
        position: const Duration(seconds: 2),
      ),
    );
    await pumpEventQueue();

    expect(emissions.whereType<MediaItem>().length, afterFirst);

    await subscription.cancel();
    await handler.dispose();
  });

  test('maps processingState for buffering, completed and ready', () async {
    final controller = _FakePlaybackController();
    final track = _track();
    final handler = FlindAudioHandler(playback: controller);

    controller.emit(_state(isBuffering: true, track: track));
    await pumpEventQueue();
    expect(
      handler.playbackState.value.processingState,
      AudioProcessingState.buffering,
    );

    controller.emit(_state(isCompleted: true, track: track));
    await pumpEventQueue();
    expect(
      handler.playbackState.value.processingState,
      AudioProcessingState.completed,
    );

    controller.emit(_state(track: track));
    await pumpEventQueue();
    expect(
      handler.playbackState.value.processingState,
      AudioProcessingState.ready,
    );

    await handler.dispose();
  });

  test('maps repeatMode and shuffleMode from the domain model', () async {
    final controller = _FakePlaybackController();
    final track = _track();
    final handler = FlindAudioHandler(playback: controller);

    controller.emit(
      _state(track: track, repeatMode: RepeatMode.all, shuffleEnabled: true),
    );
    await pumpEventQueue();
    expect(handler.playbackState.value.repeatMode, AudioServiceRepeatMode.all);
    expect(
      handler.playbackState.value.shuffleMode,
      AudioServiceShuffleMode.all,
    );

    controller.emit(
      _state(track: track, repeatMode: RepeatMode.one, shuffleEnabled: false),
    );
    await pumpEventQueue();
    expect(handler.playbackState.value.repeatMode, AudioServiceRepeatMode.one);
    expect(
      handler.playbackState.value.shuffleMode,
      AudioServiceShuffleMode.none,
    );

    controller.emit(_state(track: track));
    await pumpEventQueue();
    expect(handler.playbackState.value.repeatMode, AudioServiceRepeatMode.none);

    await handler.dispose();
  });

  test('transport commands delegate to the controller', () async {
    final controller = _FakePlaybackController();
    final handler = FlindAudioHandler(playback: controller);

    await handler.play();
    await handler.pause();
    await handler.skipToNext();
    await handler.skipToPrevious();
    await handler.seek(const Duration(seconds: 42));

    expect(controller.playCalls, 1);
    expect(controller.pauseCalls, 1);
    expect(controller.nextCalls, 1);
    expect(controller.previousCalls, 1);
    expect(controller.lastSeek, const Duration(seconds: 42));

    await handler.dispose();
  });

  test('repeat/shuffle/stop commands delegate to the controller', () async {
    final controller = _FakePlaybackController();
    final handler = FlindAudioHandler(playback: controller);

    await handler.setRepeatMode(AudioServiceRepeatMode.one);
    expect(controller.lastRepeatMode, RepeatMode.one);

    await handler.setShuffleMode(AudioServiceShuffleMode.all);
    expect(controller.lastShuffle, isTrue);

    await handler.setShuffleMode(AudioServiceShuffleMode.none);
    expect(controller.lastShuffle, isFalse);

    await handler.stop();
    expect(controller.pauseCalls, 1);
    expect(
      handler.playbackState.value.processingState,
      AudioProcessingState.idle,
    );
    expect(handler.playbackState.value.playing, isFalse);

    await handler.dispose();
  });

  test('caps the published queue at maxQueueWindow entries', () async {
    final controller = _FakePlaybackController();
    final tracks = [
      for (var i = 0; i < 300; i++)
        _track(uri: 'local:/music/$i.mp3', title: 'Track $i'),
    ];
    controller.setQueue(_queueOf(tracks));
    final handler = FlindAudioHandler(playback: controller);

    await pumpEventQueue();

    expect(handler.queue.value, hasLength(FlindAudioHandler.maxQueueWindow));
    expect(handler.queue.value.first.id, 'local:/music/0.mp3');
    expect(handler.queue.value.last.id, 'local:/music/249.mp3');

    await handler.dispose();
  });
}
