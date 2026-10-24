// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/playback_state.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/repositories/favorites_repository.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/providers/persistence_providers.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/features/player/lyrics_view.dart';
import 'package:flind_player/features/player/player_screen.dart';

import 'support/l10n.dart';
import 'support/motion.dart';

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

Track _track() => Track(
  source: 'local',
  sourceTrackId: const LocalTrackId('/music/a.mp3'),
  uri: 'local:/music/a.mp3',
  title: 'Now Playing',
);

Widget _app() => ProviderScope(
  overrides: [
    playbackStateProvider.overrideWith(
      (ref) => Stream.value(
        PlaybackState(
          isPlaying: true,
          isBuffering: false,
          isCompleted: false,
          position: Duration.zero,
          currentTrack: _track(),
        ),
      ),
    ),
    favoritesRepositoryProvider.overrideWithValue(_FakeFavoritesRepository()),
  ],
  child: localizedApp(const PlayerScreen()),
);

/// The lyrics pane is off-screen right when collapsed and at x≈0 when shown.
double _lyricsLeft(WidgetTester tester) =>
    tester.getTopLeft(find.byType(LyricsView)).dx;

void _portrait(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(disableTestMotion);
  testWidgets('a long left-swipe over the cover enters the lyrics pane', (
    tester,
  ) async {
    _portrait(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(_lyricsLeft(tester), greaterThan(0)); // collapsed: off to the right

    await tester.timedDrag(
      find.byType(PlayerScreen),
      const Offset(-450, 0),
      const Duration(milliseconds: 300),
    );
    await tester.pumpAndSettle();

    expect(_lyricsLeft(tester), lessThan(1)); // shown: flush left
  });

  testWidgets('a short left-swipe settles back to the cover', (tester) async {
    _portrait(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.timedDrag(
      find.byType(PlayerScreen),
      const Offset(-80, 0),
      const Duration(milliseconds: 800),
    );
    await tester.pumpAndSettle();

    expect(_lyricsLeft(tester), greaterThan(0));
  });
}
