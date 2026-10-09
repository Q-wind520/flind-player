// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/playback_queue.dart';
import 'package:flind_player/core/models/playback_state.dart';
import 'package:flind_player/core/models/repeat_mode.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/repositories/favorites_repository.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/providers/persistence_providers.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/features/player/mini_player_bar.dart';
import 'package:flind_player/features/player/player_screen.dart';

import 'support/fake_playback_controller.dart';
import 'support/l10n.dart';

Track _track(int i) => Track(
  source: 'local',
  sourceTrackId: LocalTrackId('/music/$i.mp3'),
  uri: 'local:/music/$i.mp3',
  title: 'Song $i',
);

class _FakeFavoritesRepository implements FavoritesRepository {
  @override
  Stream<List<Track>> watchFavorites() => Stream.value(const <Track>[]);
  @override
  Future<List<Track>> allFavorites() async => const <Track>[];
  @override
  Future<bool> isFavorite(String uri) async => false;
  @override
  Future<void> addFavorite(Track track) async {}
  @override
  Future<void> removeFavorite(String uri) async {}
  @override
  Future<bool> toggleFavorite(Track track) async => false;
}

PlaybackQueue _queue(int index, int length) => PlaybackQueue(
  tracks: [for (var i = 0; i < length; i++) _track(i)],
  currentIndex: index,
  originalOrder: [for (var i = 0; i < length; i++) i],
);

Widget _app(
  FakePlaybackController controller, {
  int index = 1,
  int length = 3,
}) {
  final queue = _queue(index, length);
  controller.queue = queue;
  return ProviderScope(
    overrides: [
      playbackStateProvider.overrideWith(
        (ref) => Stream.value(
          PlaybackState(
            isPlaying: true,
            isBuffering: false,
            isCompleted: false,
            position: Duration.zero,
            repeatMode: RepeatMode.off,
            currentTrack: queue.currentTrack,
          ),
        ),
      ),
      playbackControllerProvider.overrideWithValue(controller),
      favoritesRepositoryProvider.overrideWithValue(_FakeFavoritesRepository()),
    ],
    child: localizedApp(const Scaffold(body: MiniPlayerBar())),
  );
}

void main() {
  testWidgets('left-swipe past the threshold skips to the next track', (
    tester,
  ) async {
    final controller = FakePlaybackController();
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    await tester.drag(find.byKey(MiniPlayerBar.barKey), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(controller.nextCalls, 1);
    expect(controller.previousCalls, 0);
  });

  testWidgets('right-swipe past the threshold goes to the previous track', (
    tester,
  ) async {
    final controller = FakePlaybackController();
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    await tester.drag(find.byKey(MiniPlayerBar.barKey), const Offset(400, 0));
    await tester.pumpAndSettle();

    expect(controller.previousCalls, 1);
    expect(controller.nextCalls, 0);
  });

  testWidgets('a short swipe settles back without skipping', (tester) async {
    final controller = FakePlaybackController();
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    await tester.drag(find.byKey(MiniPlayerBar.barKey), const Offset(-30, 0));
    await tester.pumpAndSettle();

    expect(controller.nextCalls, 0);
    expect(controller.previousCalls, 0);
  });

  testWidgets('a tap still opens the player without skipping', (tester) async {
    final controller = FakePlaybackController();
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(MiniPlayerBar.barKey));
    await tester.pumpAndSettle();

    expect(find.byType(PlayerScreen), findsOneWidget);
    expect(controller.nextCalls, 0);
    expect(controller.previousCalls, 0);
  });

  testWidgets('does not skip when there is no neighbour', (tester) async {
    final controller = FakePlaybackController();
    // A single-track queue has no neighbours.
    await tester.pumpWidget(_app(controller, index: 0, length: 1));
    await tester.pumpAndSettle();

    await tester.drag(find.byKey(MiniPlayerBar.barKey), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(controller.nextCalls, 0);
  });
}
