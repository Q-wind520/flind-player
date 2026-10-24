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
import 'package:flind_player/data/providers/cover_providers.dart';
import 'package:flind_player/data/providers/persistence_providers.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/data/services/cover_original_resolver.dart';
import 'package:flind_player/features/player/cover_viewer_screen.dart';
import 'package:flind_player/features/player/player_screen.dart';
import 'package:flind_player/shared/cover_hero.dart';

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

Widget _app(PlaybackState state) => ProviderScope(
  overrides: [
    playbackStateProvider.overrideWith((ref) => Stream.value(state)),
    favoritesRepositoryProvider.overrideWithValue(_FakeFavoritesRepository()),
    coverOriginalResolverProvider.overrideWithValue(
      CoverOriginalResolver(
        fetchRemote: (url) async => null,
        readLocal: (path) async => null,
      ),
    ),
  ],
  child: localizedApp(const PlayerScreen()),
);

void main() {
  setUpAll(disableTestMotion);
  testWidgets('long-pressing the cover opens the viewer', (tester) async {
    final state = PlaybackState(
      isPlaying: true,
      isBuffering: false,
      isCompleted: false,
      position: Duration.zero,
      currentTrack: _track(),
    );

    await tester.pumpWidget(_app(state));
    await tester.pumpAndSettle();

    await tester.longPress(find.byType(CoverHero));
    await tester.pumpAndSettle();

    expect(find.byType(CoverViewerScreen), findsOneWidget);
  });
}
