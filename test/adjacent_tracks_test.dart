// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/playback_queue.dart';
import 'package:flind_player/core/models/playback_state.dart';
import 'package:flind_player/core/models/repeat_mode.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/providers/playback_providers.dart';

import 'support/fake_playback_controller.dart';

Track _track(int i) => Track(
  source: 'local',
  sourceTrackId: LocalTrackId('/music/$i.mp3'),
  uri: 'local:/music/$i.mp3',
  title: 'Song $i',
);

ProviderContainer _container({
  required PlaybackQueue queue,
  required RepeatMode repeatMode,
}) {
  return ProviderContainer(
    overrides: [
      playbackStateProvider.overrideWith(
        (ref) => Stream.value(
          PlaybackState(
            isPlaying: true,
            isBuffering: false,
            isCompleted: false,
            position: Duration.zero,
            repeatMode: repeatMode,
            currentTrack: queue.currentTrack,
          ),
        ),
      ),
      playbackControllerProvider.overrideWithValue(
        FakePlaybackController(queue: queue),
      ),
    ],
  );
}

/// Subscribes once and yields so the overridden state stream has emitted.
Future<ProviderContainer> _ready(ProviderContainer container) async {
  final subscription = container.listen(
    playbackStateProvider,
    (previous, next) {},
  );
  addTearDown(subscription.close);
  await Future<void>.delayed(Duration.zero);
  return container;
}

PlaybackQueue _queue(int index, int length) => PlaybackQueue(
  tracks: [for (var i = 0; i < length; i++) _track(i)],
  currentIndex: index,
  originalOrder: [for (var i = 0; i < length; i++) i],
);

void main() {
  test('returns the neighbours in the middle of the queue', () async {
    final container = await _ready(
      _container(queue: _queue(1, 3), repeatMode: RepeatMode.off),
    );
    addTearDown(container.dispose);
    expect(container.read(previousTrackProvider)?.title, 'Song 0');
    expect(container.read(nextTrackProvider)?.title, 'Song 2');
  });

  test('returns null past the ends with repeat off', () async {
    final last = await _ready(
      _container(queue: _queue(2, 3), repeatMode: RepeatMode.off),
    );
    addTearDown(last.dispose);
    expect(last.read(nextTrackProvider), isNull);

    final first = await _ready(
      _container(queue: _queue(0, 3), repeatMode: RepeatMode.off),
    );
    addTearDown(first.dispose);
    expect(first.read(previousTrackProvider), isNull);
  });

  test('wraps past the ends with repeat all', () async {
    final last = await _ready(
      _container(queue: _queue(2, 3), repeatMode: RepeatMode.all),
    );
    addTearDown(last.dispose);
    expect(last.read(nextTrackProvider)?.title, 'Song 0');
  });

  test('returns null when nothing is playing', () async {
    final container = await _ready(
      ProviderContainer(
        overrides: [
          playbackStateProvider.overrideWith(
            (ref) => Stream.value(PlaybackState.idle),
          ),
          playbackControllerProvider.overrideWithValue(
            FakePlaybackController(queue: PlaybackQueue.empty),
          ),
        ],
      ),
    );
    addTearDown(container.dispose);
    expect(container.read(previousTrackProvider), isNull);
    expect(container.read(nextTrackProvider), isNull);
  });
}
