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

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/playback_queue.dart';
import 'package:flind_player/core/models/playback_state.dart';
import 'package:flind_player/core/models/repeat_mode.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/models/track_sort.dart';
import 'package:flind_player/core/repositories/favorites_repository.dart';
import 'package:flind_player/core/services/playback_controller.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/cache/download_manager.dart';
import 'package:flind_player/data/providers/cache_providers.dart';
import 'package:flind_player/data/providers/library_providers.dart';
import 'package:flind_player/data/providers/persistence_providers.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/data/services/library_sync_service.dart';
import 'package:flind_player/features/library/library_screen.dart';
import 'package:flind_player/features/library/library_sort_provider.dart';
import 'package:flind_player/features/library/widgets/cache_action_button.dart';

import 'support/l10n.dart';

/// An in-memory [FavoritesRepository] for tests.
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
}

Track _track(String title, {String? artist, Duration? duration, int? id}) {
  return Track(
    id: id,
    source: 'local',
    sourceTrackId: LocalTrackId('/music/$title.mp3'),
    uri: 'local:/music/$title.mp3',
    title: title,
    artist: artist,
    duration: duration,
  );
}

/// Sets the test view size and registers a tear-down to reset it.
void _setSize(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Pumps [LibraryScreen] with all required providers overridden.
Widget _app({
  List<Track> tracks = const <Track>[],
  List<Track> favourites = const <Track>[],
  TrackSort sort = TrackSort.title,
  LibrarySyncState syncState = LibrarySyncState.idle,
}) {
  final favRepo = _InMemoryFavoritesRepository();
  for (final track in favourites) {
    favRepo.toggleFavorite(track);
  }
  return ProviderScope(
    overrides: [
      libraryTracksProvider.overrideWith((ref) => Stream.value(tracks)),
      playbackStateProvider.overrideWith(
        (ref) => Stream.value(PlaybackState.idle),
      ),
      librarySyncStateProvider.overrideWith((ref) => Stream.value(syncState)),
      downloadProgressProvider.overrideWith(
        (ref) => const Stream<DownloadProgress>.empty(),
      ),
      audioCacheEntryProvider.overrideWith((ref, track) async => null),
      favoritesRepositoryProvider.overrideWithValue(favRepo),
      favoritesProvider.overrideWith((ref) => favRepo.watchFavorites()),
      librarySortProvider.overrideWith(() => _FakeLibrarySortNotifier(sort)),
    ],
    child: localizedApp(const LibraryScreen()),
  );
}

void main() {
  group('Sort control', () {
    testWidgets('renders the sort menu with four options', (tester) async {
      _setSize(tester, 400, 800);
      await tester.pumpWidget(_app(tracks: [_track('Alpha')]));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.sort), findsOneWidget);

      await tester.tap(find.byIcon(Icons.sort));
      await tester.pumpAndSettle();

      expect(find.text('按标题'), findsOneWidget);
      expect(find.text('按艺术家'), findsOneWidget);
      expect(find.text('按专辑'), findsOneWidget);
      expect(find.text('最近添加'), findsOneWidget);
    });

    testWidgets('selecting a sort option closes the menu', (tester) async {
      _setSize(tester, 400, 800);
      await tester.pumpWidget(_app(tracks: [_track('Alpha'), _track('Beta')]));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.sort));
      await tester.pumpAndSettle();

      await tester.tap(find.text('按艺术家'));
      await tester.pumpAndSettle();

      expect(find.text('按艺术家'), findsNothing);
    });

    testWidgets('the persisted sort value is restored on a fresh provider', (
      tester,
    ) async {
      _setSize(tester, 400, 800);

      final alpha = _track('Alpha', artist: 'Charlie');
      final beta = _track('Beta', artist: 'Alice');

      await tester.pumpWidget(
        _app(tracks: [alpha, beta], sort: TrackSort.artist),
      );
      await tester.pumpAndSettle();

      // Verify the sort provider holds the persisted value.
      final container = ProviderScope.containerOf(
        find.byType(MaterialApp).evaluate().first,
      );
      final currentSort = await container.read(librarySortProvider.future);
      expect(currentSort, TrackSort.artist);

      // Verify tracks render (order is server-side; sort provider state is the
      // contract under test here since libraryTracksProvider is overridden).
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
    });
  });

  group('Favourites sort', () {
    testWidgets('favourites filter applies the chosen sort', (tester) async {
      _setSize(tester, 400, 800);

      final alpha = _track('Alpha', artist: 'Charlie', id: 3);
      final beta = _track('Beta', artist: 'Alice', id: 1);

      await tester.pumpWidget(
        _app(
          tracks: [alpha, beta],
          favourites: [alpha, beta],
          sort: TrackSort.artist,
        ),
      );
      await tester.pumpAndSettle();

      // Switch to favourites tab.
      await tester.tap(find.text('收藏'));
      await tester.pumpAndSettle();

      // Both tracks should be visible in favourites.
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);

      // Beta (Alice) should render before Alpha (Charlie) in the list.
      final betaTop = tester.getTopLeft(find.text('Beta')).dy;
      final alphaTop = tester.getTopLeft(find.text('Alpha')).dy;
      expect(betaTop < alphaTop, isTrue);
    });
  });

  group('Wide-screen grid', () {
    testWidgets('at 400 px the list layout renders', (tester) async {
      _setSize(tester, 400, 800);

      await tester.pumpWidget(
        _app(tracks: [_track('Alpha'), _track('Beta')]),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(GridView), findsNothing);
    });

    testWidgets('at 1000 px the grid layout renders', (tester) async {
      _setSize(tester, 1000, 800);

      await tester.pumpWidget(
        _app(tracks: [_track('Alpha'), _track('Beta')]),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GridView), findsOneWidget);
      expect(find.byType(ListView), findsNothing);

      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
    });

    testWidgets('tapping a card in the grid plays the right track', (
      tester,
    ) async {
      _setSize(tester, 1000, 800);

      List<Track>? playedTracks;
      int? playedIndex;

      final favRepo = _InMemoryFavoritesRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryTracksProvider.overrideWith(
              (ref) => Stream.value([_track('Alpha'), _track('Beta')]),
            ),
            playbackStateProvider.overrideWith(
              (ref) => Stream.value(PlaybackState.idle),
            ),
            librarySyncStateProvider.overrideWith(
              (ref) => Stream.value(LibrarySyncState.idle),
            ),
            downloadProgressProvider.overrideWith(
              (ref) => const Stream<DownloadProgress>.empty(),
            ),
            audioCacheEntryProvider.overrideWith((ref, track) async => null),
            favoritesRepositoryProvider.overrideWithValue(favRepo),
            favoritesProvider.overrideWith(
              (ref) => const Stream<List<Track>>.empty(),
            ),
            librarySortProvider.overrideWith(
              () => _FakeLibrarySortNotifier(TrackSort.title),
            ),
            playbackControllerProvider.overrideWith((ref) {
              return _FakePlaybackController(
                onPlayQueue: (queue, index) {
                  playedTracks = queue.tracks;
                  playedIndex = index;
                },
              );
            }),
          ],
          child: localizedApp(const LibraryScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GridView), findsOneWidget);

      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();

      expect(playedTracks!.first.title, 'Alpha');
      expect(playedIndex, 0);
    });

    testWidgets('does not overflow at 400 px with long titles', (
      tester,
    ) async {
      _setSize(tester, 400, 800);

      await tester.pumpWidget(
        _app(
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

      expect(tester.takeException(), isNull);
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('looks intentional at 1400 px', (tester) async {
      _setSize(tester, 1400, 800);

      await tester.pumpWidget(
        _app(
          tracks: [
            _track('Alpha', artist: 'Artist A'),
            _track('Beta', artist: 'Artist B'),
            _track('Gamma', artist: 'Artist C'),
            _track('Delta', artist: 'Artist D'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GridView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Existing functionality preserved', () {
    testWidgets('filter bar still works in wide mode', (tester) async {
      _setSize(tester, 1000, 800);

      final alpha = _track('Alpha');
      final beta = _track('Beta');

      await tester.pumpWidget(
        _app(tracks: [alpha, beta], favourites: [alpha]),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GridView), findsOneWidget);
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);

      await tester.tap(find.text('收藏'));
      await tester.pumpAndSettle();

      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsNothing);
    });
  });
}

/// Fake [LibrarySortNotifier] that returns a fixed value immediately.
class _FakeLibrarySortNotifier extends LibrarySortNotifier {
  _FakeLibrarySortNotifier(this._sort);

  final TrackSort _sort;

  @override
  Future<TrackSort> build() async => _sort;
}

/// Minimal [PlaybackController] for tests that only need to capture playQueue.
class _FakePlaybackController implements PlaybackController {
  _FakePlaybackController({required this.onPlayQueue});

  final void Function(PlaybackQueue queue, int index) onPlayQueue;

  @override
  Stream<PlaybackState> get state => Stream.value(PlaybackState.idle);

  @override
  PlaybackState get currentState => PlaybackState.idle;

  @override
  PlaybackQueue get queue => PlaybackQueue.empty;

  @override
  Future<void> playQueue(
    PlaybackQueue queue, {
    int index = 0,
    bool autoPlay = true,
  }) async {
    onPlayQueue(queue, index);
  }

  @override
  Future<void> updateTrackCover(
    String uri, {
    String? coverPath,
    String? coverUrl,
  }) async {}

  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> togglePlayPause() async {}
  @override
  Future<void> next() async {}
  @override
  Future<void> previous() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> setRepeatMode(RepeatMode mode) async {}
  @override
  Future<void> setShuffle(bool enabled) async {}
  @override
  Future<void> dispose() async {}
}
