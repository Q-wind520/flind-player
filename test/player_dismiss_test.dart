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
import 'package:flind_player/features/player/mini_player_bar.dart';
import 'package:flind_player/features/player/player_screen.dart';

import 'support/l10n.dart';

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

Widget _host() => ProviderScope(
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
  child: localizedApp(
    Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).push(playerRoute(context)),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('dragging the header down past the threshold dismisses', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(PlayerScreen), findsOneWidget);

    await tester.drag(find.byKey(playerDismissHandleKey), const Offset(0, 500));
    await tester.pumpAndSettle();

    expect(find.byType(PlayerScreen), findsNothing);
  });

  testWidgets('a short downward drag springs back', (tester) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.drag(find.byKey(playerDismissHandleKey), const Offset(0, 30));
    await tester.pumpAndSettle();

    expect(find.byType(PlayerScreen), findsOneWidget);
  });
}
