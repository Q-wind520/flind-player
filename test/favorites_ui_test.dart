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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/playback_state.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/repositories/favorites_repository.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/cache/download_manager.dart';
import 'package:flind_player/data/providers/cache_providers.dart';
import 'package:flind_player/data/providers/library_providers.dart';
import 'package:flind_player/data/providers/persistence_providers.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/data/services/library_sync_service.dart';
import 'package:flind_player/features/library/library_screen.dart';
import 'package:flind_player/features/library/widgets/cache_action_button.dart';
import 'package:flind_player/features/library/widgets/track_actions_button.dart';
import 'package:flind_player/features/player/player_screen.dart';

import 'support/l10n.dart';

Track _track(
  String title, {
  String? artist,
  Duration? duration,
  String source = 'local',
}) {
  final path = '/music/$title.mp3';
  return Track(
    source: source,
    sourceTrackId: LocalTrackId(path),
    uri: 'local:$path',
    title: title,
    artist: artist,
    duration: duration,
  );
}

/// In-memory [FavoritesRepository] for tests.
///
/// Each subscriber to [watchFavorites] receives the current state immediately,
/// then live updates.  A broadcast stream alone would lose events emitted
/// before the first listener subscribes.
class _InMemoryFavoritesRepository implements FavoritesRepository {
  final _favourites = <String, Track>{};
  final List<StreamController<List<Track>>> _listeners = [];

  @override
  Stream<List<Track>> watchFavorites() async* {
    yield _favourites.values.toList();
    final controller = StreamController<List<Track>>();
    _listeners.add(controller);
    yield* controller.stream;
    // ignore: use_key_synchronously
    controller.onCancel = () => _listeners.remove(controller);
  }

  @override
  Future<List<Track>> allFavorites() async => _favourites.values.toList();

  @override
  Future<bool> isFavorite(String uri) async => _favourites.containsKey(uri);

  @override
  Future<void> addFavorite(Track track) async {
    _favourites[track.uri] = track;
    _notify();
  }

  @override
  Future<void> removeFavorite(String uri) async {
    _favourites.remove(uri);
    _notify();
  }

  @override
  Future<void> updateFavoriteCover(
    String uri, {
    String? coverPath,
    String? coverUrl,
  }) async {}

  @override
  Future<bool> toggleFavorite(Track track) async {
    if (_favourites.containsKey(track.uri)) {
      _favourites.remove(track.uri);
      _notify();
      return false;
    } else {
      _favourites[track.uri] = track;
      _notify();
      return true;
    }
  }

  void _notify() {
    final value = _favourites.values.toList();
    for (final c in _listeners) {
      if (!c.isClosed) c.add(value);
    }
  }

  void dispose() {
    for (final c in _listeners) {
      c.close();
    }
    _listeners.clear();
  }
}

/// Pumps [LibraryScreen] with all required providers overridden.
Widget _libraryApp({
  List<Track> tracks = const <Track>[],
  List<Track> favourites = const <Track>[],
  PlaybackState playbackState = PlaybackState.idle,
  LibrarySyncState syncState = LibrarySyncState.idle,
  FutureOr<List<Track>> Function(Ref ref, String query)? search,
  Stream<DownloadProgress> progress = const Stream<DownloadProgress>.empty(),
}) {
  final favRepo = _InMemoryFavoritesRepository();
  for (final track in favourites) {
    favRepo.toggleFavorite(track);
  }
  return ProviderScope(
    overrides: [
      libraryTracksProvider.overrideWith((ref) => Stream.value(tracks)),
      playbackStateProvider.overrideWith((ref) => Stream.value(playbackState)),
      librarySyncStateProvider.overrideWith((ref) => Stream.value(syncState)),
      downloadProgressProvider.overrideWith((ref) => progress),
      audioCacheEntryProvider.overrideWith((ref, track) async => null),
      favoritesRepositoryProvider.overrideWithValue(favRepo),
      favoritesProvider.overrideWith((ref) => favRepo.watchFavorites()),
      if (search != null) librarySearchProvider.overrideWith(search),
    ],
    child: localizedApp(const LibraryScreen()),
  );
}

/// Pumps [PlayerView] with all required providers overridden.
Widget _playerApp({PlaybackState playbackState = PlaybackState.idle}) {
  final favRepo = _InMemoryFavoritesRepository();
  return ProviderScope(
    overrides: [
      playbackStateProvider.overrideWith((ref) => Stream.value(playbackState)),
      favoritesRepositoryProvider.overrideWithValue(favRepo),
      favoritesProvider.overrideWith((ref) => favRepo.watchFavorites()),
    ],
    child: localizedApp(const PlayerScreen()),
  );
}

void main() {
  group('Library favourite toggle', () {
    testWidgets('shows the actions menu on a track row', (tester) async {
      await tester.pumpWidget(_libraryApp(tracks: [_track('Alpha')]));
      await tester.pumpAndSettle();

      // The TrackActionsButton should be present on the track row.
      expect(find.byType(TrackActionsButton), findsOneWidget);
    });

    testWidgets('toggling favourite shows SnackBar', (tester) async {
      await tester.pumpWidget(_libraryApp(tracks: [_track('Alpha')]));
      await tester.pumpAndSettle();

      // Open the actions menu by tapping the TrackActionsButton.
      await tester.tap(find.byType(TrackActionsButton));
      await tester.pumpAndSettle();

      // Tap the favourite menu item (.last because the filter selector also
      // contains the text "收藏").
      await tester.tap(find.text('收藏').last);
      await tester.pumpAndSettle();

      expect(find.text('已收藏'), findsOneWidget);
    });

    testWidgets('toggling favourite again shows取消收藏 SnackBar', (tester) async {
      final alpha = _track('Alpha');
      await tester.pumpWidget(
        _libraryApp(tracks: [alpha], favourites: [alpha]),
      );
      await tester.pumpAndSettle();

      // Open the actions menu.
      await tester.tap(find.byType(TrackActionsButton));
      await tester.pumpAndSettle();

      // The menu should show "取消收藏" since the track is favourited.
      await tester.tap(find.text('取消收藏'));
      await tester.pumpAndSettle();

      expect(find.text('已取消收藏'), findsOneWidget);
    });
  });

  group('Library favourites filter', () {
    testWidgets('switching to收藏 shows only favourited tracks', (tester) async {
      final alpha = _track('Alpha');
      final beta = _track('Beta');

      await tester.pumpWidget(
        _libraryApp(tracks: [alpha, beta], favourites: [alpha]),
      );
      await tester.pumpAndSettle();

      // Initially shows all tracks.
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);

      // Switch to favourites.
      await tester.tap(find.text('收藏'));
      await tester.pumpAndSettle();

      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsNothing);
    });

    testWidgets('empty favourites shows friendly message', (tester) async {
      await tester.pumpWidget(_libraryApp(tracks: [_track('Alpha')]));
      await tester.pumpAndSettle();

      // Switch to favourites.
      await tester.tap(find.text('收藏'));
      await tester.pumpAndSettle();

      expect(find.text('还没有收藏的歌曲'), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('query filters favourites list', (tester) async {
      final alpha = _track('Alpha Song');
      final beta = _track('Beta Song');

      await tester.pumpWidget(
        _libraryApp(
          tracks: [alpha, beta],
          favourites: [alpha, beta],
          search: (ref, query) async => <Track>[],
        ),
      );
      await tester.pumpAndSettle();

      // Switch to favourites.
      await tester.tap(find.text('收藏'));
      await tester.pumpAndSettle();

      // Type a search query.
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Alpha');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('Alpha Song'), findsOneWidget);
      expect(find.text('Beta Song'), findsNothing);
    });

    testWidgets('query with no matching favourites shows empty state', (
      tester,
    ) async {
      final alpha = _track('Alpha Song');

      await tester.pumpWidget(
        _libraryApp(
          tracks: [alpha],
          favourites: [alpha],
          search: (ref, query) async => <Track>[],
        ),
      );
      await tester.pumpAndSettle();

      // Switch to favourites.
      await tester.tap(find.text('收藏'));
      await tester.pumpAndSettle();

      // Type a search query that matches nothing.
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Nothing');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('没有找到匹配的收藏'), findsOneWidget);
    });

    testWidgets('a favourite without a pool id renders as unavailable', (
      tester,
    ) async {
      // `_track('Gone')` has no id, i.e. the pool row is missing.
      await tester.pumpWidget(_libraryApp(favourites: [_track('Gone')]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('收藏').last); // switch to the 收藏 section
      await tester.pumpAndSettle();
      expect(find.text('不可用'), findsWidgets); // l10n.trackUnavailable (zh)
    });

    testWidgets('currently playing highlight works in favourites mode', (
      tester,
    ) async {
      final alpha = _track('Alpha');
      final state = PlaybackState(
        isPlaying: true,
        isBuffering: false,
        isCompleted: false,
        position: Duration.zero,
        currentTrack: alpha,
      );

      await tester.pumpWidget(
        _libraryApp(tracks: [alpha], favourites: [alpha], playbackState: state),
      );
      await tester.pumpAndSettle();

      // Switch to favourites.
      await tester.tap(find.text('收藏'));
      await tester.pumpAndSettle();

      // The playing indicator should be visible.
      expect(find.byIcon(Icons.graphic_eq), findsOneWidget);
    });
  });

  group('Player favourite button', () {
    testWidgets('heart button toggles favourite state', (tester) async {
      final track = _track('Now Playing');
      final state = PlaybackState(
        isPlaying: true,
        isBuffering: false,
        isCompleted: false,
        position: Duration.zero,
        currentTrack: track,
      );

      await tester.pumpWidget(_playerApp(playbackState: state));
      await tester.pumpAndSettle();

      // The heart outline should be present (not favourited).
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsNothing);

      // Tap the heart to favourite.
      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pumpAndSettle();

      // The heart should now be filled.
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsNothing);

      // SnackBar should confirm.
      expect(find.text('已收藏'), findsOneWidget);
    });

    testWidgets('heart button hidden when no track is playing', (tester) async {
      await tester.pumpWidget(_playerApp());
      await tester.pumpAndSettle();

      // The "nothing playing" state should show, no heart button.
      expect(find.text('未在播放'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsNothing);
      expect(find.byIcon(Icons.favorite), findsNothing);
    });

    testWidgets('heart button unfavourites a favourited track', (tester) async {
      final track = _track('Now Playing');
      final state = PlaybackState(
        isPlaying: true,
        isBuffering: false,
        isCompleted: false,
        position: Duration.zero,
        currentTrack: track,
      );

      // Pre-favourite the track.
      final favRepo = _InMemoryFavoritesRepository();
      await favRepo.addFavorite(track);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playbackStateProvider.overrideWith((ref) => Stream.value(state)),
            favoritesRepositoryProvider.overrideWithValue(favRepo),
            favoritesProvider.overrideWith((ref) => favRepo.watchFavorites()),
          ],
          child: localizedApp(const PlayerScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // The heart should be filled (favourited).
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsNothing);

      // Tap to unfavourite.
      await tester.tap(find.byIcon(Icons.favorite));
      await tester.pumpAndSettle();

      // The heart should now be outline.
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsNothing);

      // SnackBar should confirm.
      expect(find.text('已取消收藏'), findsOneWidget);
    });
  });

  group('Overflow safety', () {
    testWidgets('library row does not overflow at 400 px', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _libraryApp(
          tracks: [
            _track(
              '一个非常非常长的歌曲标题用来验证在窄屏下会被省略号截断',
              artist: '一个同样非常长的艺术家名称',
              duration: const Duration(minutes: 12, seconds: 34),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('一个非常非常长的歌曲标题用来验证在窄屏下会被省略号截断'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
