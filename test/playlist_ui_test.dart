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
import 'package:flind_player/core/models/track_sort.dart';
import 'package:flind_player/core/repositories/favorites_repository.dart';
import 'package:flind_player/core/repositories/playlist_repository.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/cache/download_manager.dart';
import 'package:flind_player/data/database/playlist_defaults.dart';
import 'package:flind_player/data/providers/cache_providers.dart';
import 'package:flind_player/data/providers/library_providers.dart';
import 'package:flind_player/data/providers/persistence_providers.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/data/providers/playlist_providers.dart';
import 'package:flind_player/data/services/library_sync_service.dart';
import 'package:flind_player/features/library/library_screen.dart';
import 'package:flind_player/features/library/library_sort_provider.dart';
import 'package:flind_player/features/library/widgets/cache_action_button.dart';
import 'package:flind_player/features/library/widgets/track_actions_button.dart';
import 'package:flind_player/shared/cover_image.dart';

import 'support/l10n.dart';

Track _track(
  String title, {
  String? artist,
  Duration? duration,
  String? coverPath,
  String? coverUrl,
}) {
  final path = '/music/$title.mp3';
  return Track(
    source: 'local',
    sourceTrackId: LocalTrackId(path),
    uri: 'local:$path',
    title: title,
    artist: artist,
    duration: duration,
    coverPath: coverPath,
    coverUrl: coverUrl,
  );
}

Playlist _playlist(
  int id,
  String name,
  PlaylistKind kind, {
  String? description,
}) {
  final now = DateTime(2026, 1, 1);
  return Playlist(
    id: id,
    name: name,
    kind: kind,
    description: description,
    createdAt: now,
    updatedAt: now,
  );
}

/// In-memory [FavoritesRepository] for tests.
///
/// Each subscriber to [watchFavorites] receives the current state immediately,
/// then live updates.
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

/// In-memory [PlaylistRepository] for tests.
///
/// Members are kept newest-first. Every watch stream yields the current state
/// immediately, then live updates, so `StreamProvider`s never miss the initial
/// emission.
class _FakePlaylistRepository implements PlaylistRepository {
  _FakePlaylistRepository({
    List<Playlist> playlists = const <Playlist>[],
    Map<int, List<Track>> tracks = const <int, List<Track>>{},
  }) : _playlists = [...playlists],
       _tracks = {
         for (final entry in tracks.entries) entry.key: [...entry.value],
       };

  final List<Playlist> _playlists;
  final Map<int, List<Track>> _tracks;
  final _playlistsController = StreamController<List<Playlist>>.broadcast();
  final _trackControllers = <int, StreamController<List<Track>>>{};
  final _coverControllers = <int, StreamController<PlaylistCover?>>{};
  int _nextId = 100;

  /// The current playlists, for direct assertions.
  List<Playlist> get playlists => List.unmodifiable(_playlists);

  /// The derived cover for [id], for direct assertions.
  PlaylistCover? coverFor(int id) => _deriveCover(id);

  StreamController<List<Track>> _trackController(int id) =>
      _trackControllers.putIfAbsent(
        id,
        () => StreamController<List<Track>>.broadcast(),
      );

  StreamController<PlaylistCover?> _coverController(int id) =>
      _coverControllers.putIfAbsent(
        id,
        () => StreamController<PlaylistCover?>.broadcast(),
      );

  PlaylistCover? _deriveCover(int id) {
    for (final playlist in _playlists) {
      if (playlist.id != id) continue;
      final path = playlist.coverPath;
      final url = playlist.coverUrl;
      if ((path != null && path.isNotEmpty) ||
          (url != null && url.isNotEmpty)) {
        return PlaylistCover(coverPath: path, coverUrl: url);
      }
    }
    final members = _tracks[id] ?? const <Track>[];
    if (members.isEmpty) return null;
    final newest = members.first;
    final path = newest.coverPath;
    final url = newest.coverUrl;
    if ((path != null && path.isNotEmpty) ||
        (url != null && url.isNotEmpty)) {
      return PlaylistCover(coverPath: path, coverUrl: url);
    }
    return null;
  }

  void _emitPlaylists() {
    if (!_playlistsController.isClosed) {
      _playlistsController.add(List.unmodifiable(_playlists));
    }
  }

  @override
  Stream<List<Playlist>> watchPlaylists() async* {
    yield List.unmodifiable(_playlists);
    yield* _playlistsController.stream;
  }

  @override
  Future<Playlist?> playlistById(int id) async {
    for (final playlist in _playlists) {
      if (playlist.id == id) return playlist;
    }
    return null;
  }

  @override
  Future<Playlist> createPlaylist({
    required String name,
    String? description,
    String? coverPath,
    String? coverUrl,
  }) async {
    if (name.trim().isEmpty) {
      throw ArgumentError('name must not be blank');
    }
    final now = DateTime.now();
    final playlist = Playlist(
      id: _nextId++,
      name: name.trim(),
      kind: PlaylistKind.custom,
      description: description,
      coverPath: coverPath,
      coverUrl: coverUrl,
      createdAt: now,
      updatedAt: now,
    );
    _playlists.add(playlist);
    _emitPlaylists();
    return playlist;
  }

  @override
  Future<void> updatePlaylist(
    int id, {
    String? name,
    String? description,
    String? coverPath,
    String? coverUrl,
    bool clearCover = false,
  }) async {
    final index = _playlists.indexWhere((playlist) => playlist.id == id);
    if (index < 0) return;
    final current = _playlists[index];
    if (current.kind == PlaylistKind.favorites) {
      throw StateError('the favourites playlist cannot be updated');
    }
    if (name != null && name.trim().isEmpty) {
      throw ArgumentError('name must not be blank');
    }
    // Built explicitly rather than via `copyWith`, whose `null` means "keep":
    // `clearCover` must write `null` to both cover columns.
    _playlists[index] = Playlist(
      id: current.id,
      name: name?.trim() ?? current.name,
      kind: current.kind,
      description: description ?? current.description,
      coverPath: clearCover ? null : (coverPath ?? current.coverPath),
      coverUrl: clearCover ? null : (coverUrl ?? current.coverUrl),
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
    );
    _emitPlaylists();
    _coverController(id).add(_deriveCover(id));
  }

  @override
  Future<void> deletePlaylist(int id) async {
    final index = _playlists.indexWhere((playlist) => playlist.id == id);
    if (index < 0) return;
    if (_playlists[index].kind == PlaylistKind.favorites) {
      throw StateError('the favourites playlist cannot be deleted');
    }
    _playlists.removeAt(index);
    _tracks.remove(id);
    _emitPlaylists();
  }

  @override
  Stream<List<Track>> watchPlaylistTracks(int id) async* {
    yield List.unmodifiable(_tracks[id] ?? const <Track>[]);
    yield* _trackController(id).stream;
  }

  @override
  Future<List<Track>> playlistTracks(int id) async =>
      List.unmodifiable(_tracks[id] ?? const <Track>[]);

  @override
  Future<void> addTrack(int playlistId, Track track) async {
    final members = _tracks.putIfAbsent(playlistId, () => <Track>[]);
    members.removeWhere((member) => member.uri == track.uri);
    members.insert(0, track);
    _trackController(playlistId).add(List.unmodifiable(members));
    _coverController(playlistId).add(_deriveCover(playlistId));
  }

  @override
  Future<void> removeTrack(int playlistId, String uri) async {
    final members = _tracks[playlistId];
    if (members == null) return;
    members.removeWhere((member) => member.uri == uri);
    _trackController(playlistId).add(List.unmodifiable(members));
    _coverController(playlistId).add(_deriveCover(playlistId));
  }

  @override
  Future<bool> containsTrack(int playlistId, String uri) async {
    final members = _tracks[playlistId];
    if (members == null) return false;
    return members.any((member) => member.uri == uri);
  }

  @override
  Future<void> updateTrackCover(
    int playlistId,
    String uri, {
    String? coverPath,
    String? coverUrl,
  }) async {
    _coverController(playlistId).add(_deriveCover(playlistId));
  }

  @override
  Stream<PlaylistCover?> watchPlaylistCover(int id) async* {
    yield _deriveCover(id);
    yield* _coverController(id).stream;
  }
}

/// Fake [LibrarySortNotifier] that returns a fixed value immediately.
class _FakeLibrarySortNotifier extends LibrarySortNotifier {
  _FakeLibrarySortNotifier(this._sort);

  final TrackSort _sort;

  @override
  Future<TrackSort> build() async => _sort;
}

/// Sets the test view size and registers a tear-down to reset it.
void _setSize(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Pumps [LibraryScreen] with the library, sync, playback, favourites and
/// playlist providers overridden.
///
/// `playlistRepositoryProvider` is overridden so the real drift-backed
/// repository (and its database) is never constructed.
Widget _app({
  List<Track> tracks = const <Track>[],
  List<Track> favourites = const <Track>[],
  _FakePlaylistRepository? playlistRepo,
  Size size = const Size(400, 800),
}) {
  final favRepo = _InMemoryFavoritesRepository();
  for (final track in favourites) {
    favRepo.toggleFavorite(track);
  }
  final repo = playlistRepo ?? _FakePlaylistRepository();
  return ProviderScope(
    overrides: [
      libraryTracksProvider.overrideWith((ref) => Stream.value(tracks)),
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
      favoritesProvider.overrideWith((ref) => favRepo.watchFavorites()),
      librarySortProvider.overrideWith(
        () => _FakeLibrarySortNotifier(TrackSort.title),
      ),
      playlistRepositoryProvider.overrideWithValue(repo),
    ],
    child: localizedApp(
      MediaQuery(
        data: MediaQueryData(size: size),
        child: const LibraryScreen(),
      ),
    ),
  );
}

/// Switches the library to the playlists section via the filter selector.
Future<void> _openPlaylists(WidgetTester tester) async {
  await tester.tap(find.text(testL10n().tabPlaylists));
  await tester.pumpAndSettle();
}

void main() {
  group('playlists section', () {
    testWidgets('switching to 歌单 shows the pinned favourites row and the '
        'empty state', (tester) async {
      _setSize(tester, 400, 800);

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await _openPlaylists(tester);

      // The pinned favourites row (with its member count) stays visible.
      expect(find.text(testL10n().tabFavorites), findsNWidgets(2));
      expect(find.text(testL10n().playlistTrackCount(0)), findsOneWidget);
      expect(find.text(testL10n().noPlaylists), findsOneWidget);
      expect(find.text(testL10n().noPlaylistsHint), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('lists the pinned favourites row and every custom playlist',
        (tester) async {
      _setSize(tester, 400, 800);
      final repo = _FakePlaylistRepository(
        playlists: [
          _playlist(favoritesPlaylistId, '收藏', PlaylistKind.favorites),
          _playlist(2, 'Road Trip', PlaylistKind.custom),
          _playlist(3, 'Workout', PlaylistKind.custom),
        ],
        tracks: {
          favoritesPlaylistId: [_track('Alpha')],
        },
      );

      await tester.pumpWidget(_app(playlistRepo: repo));
      await tester.pumpAndSettle();

      await _openPlaylists(tester);

      expect(find.text('Road Trip'), findsOneWidget);
      expect(find.text('Workout'), findsOneWidget);
      expect(find.text(testL10n().playlistTrackCount(1)), findsOneWidget);
      expect(find.text(testL10n().noPlaylists), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders without overflow at 400 and 1280 px', (tester) async {
      final repo = _FakePlaylistRepository(
        playlists: [
          _playlist(2, 'A Playlist Name That Keeps Going And Going', PlaylistKind.custom),
          _playlist(3, 'Another', PlaylistKind.custom),
        ],
        tracks: {
          2: [_track('Alpha'), _track('Beta')],
        },
      );

      for (final size in const [Size(400, 800), Size(1280, 800)]) {
        _setSize(tester, size.width, size.height);
        await tester.pumpWidget(_app(playlistRepo: repo, size: size));
        await tester.pumpAndSettle();

        await _openPlaylists(tester);

        expect(tester.takeException(), isNull);
      }
    });
  });

  group('create and edit', () {
    testWidgets('creating a playlist with a name adds it to the list',
        (tester) async {
      _setSize(tester, 400, 800);
      final repo = _FakePlaylistRepository();

      await tester.pumpWidget(_app(playlistRepo: repo));
      await tester.pumpAndSettle();

      await _openPlaylists(tester);
      await tester.tap(find.byKey(const Key('library_add_playlist')));
      await tester.pumpAndSettle();

      expect(find.text(testL10n().newPlaylist), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'My Mix');
      await tester.tap(find.text(testL10n().confirm));
      await tester.pumpAndSettle();

      expect(find.text('My Mix'), findsOneWidget);
      expect(repo.playlists.any((p) => p.name == 'My Mix'), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a blank playlist name is rejected', (tester) async {
      _setSize(tester, 400, 800);
      final repo = _FakePlaylistRepository();

      await tester.pumpWidget(_app(playlistRepo: repo));
      await tester.pumpAndSettle();

      await _openPlaylists(tester);
      await tester.tap(find.byKey(const Key('library_add_playlist')));
      await tester.pumpAndSettle();

      await tester.tap(find.text(testL10n().confirm));
      await tester.pumpAndSettle();

      expect(find.text(testL10n().playlistNameRequired), findsOneWidget);
      expect(
        repo.playlists.where((p) => p.kind == PlaylistKind.custom),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('editing a playlist updates its name and description',
        (tester) async {
      _setSize(tester, 400, 800);
      final repo = _FakePlaylistRepository(
        playlists: [
          _playlist(2, 'Old Name', PlaylistKind.custom, description: 'Old desc'),
        ],
      );

      await tester.pumpWidget(_app(playlistRepo: repo));
      await tester.pumpAndSettle();

      await _openPlaylists(tester);
      await tester.tap(find.text('Old Name'));
      await tester.pumpAndSettle();

      // Detail screen: app bar + header both show the name.
      expect(find.text('Old Name'), findsNWidgets(2));
      await tester.tap(find.byTooltip(testL10n().editPlaylist));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'New Name');
      await tester.enterText(find.byType(TextField).at(1), 'New desc');
      await tester.tap(find.text(testL10n().confirm));
      await tester.pumpAndSettle();

      expect(find.text('New Name'), findsNWidgets(2));
      expect(find.text('New desc'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('deleting a playlist removes it and returns to the list',
        (tester) async {
      _setSize(tester, 400, 800);
      final repo = _FakePlaylistRepository(
        playlists: [_playlist(2, 'Doomed', PlaylistKind.custom)],
      );

      await tester.pumpWidget(_app(playlistRepo: repo));
      await tester.pumpAndSettle();

      await _openPlaylists(tester);
      await tester.tap(find.text('Doomed'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(testL10n().deletePlaylistTitle));
      await tester.pumpAndSettle();

      expect(find.text(testL10n().deletePlaylistTitle), findsOneWidget);
      await tester.tap(find.text(testL10n().delete));
      await tester.pumpAndSettle();

      // Back on the playlists section, the playlist is gone.
      expect(find.text('Doomed'), findsNothing);
      expect(find.text(testL10n().noPlaylists), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('add to playlist', () {
    testWidgets('adding a track to a playlist shows a confirmation',
        (tester) async {
      _setSize(tester, 400, 800);
      final alpha = _track('Alpha');
      final repo = _FakePlaylistRepository(
        playlists: [_playlist(2, 'Road Trip', PlaylistKind.custom)],
      );

      await tester.pumpWidget(_app(tracks: [alpha], playlistRepo: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TrackActionsButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(testL10n().addToPlaylist));
      await tester.pumpAndSettle();

      expect(find.text(testL10n().selectPlaylist), findsOneWidget);
      await tester.tap(find.text('Road Trip'));
      await tester.pumpAndSettle();

      expect(find.text(testL10n().addedToPlaylist('Road Trip')), findsOneWidget);
      expect(await repo.containsTrack(2, alpha.uri), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a track already in a playlist is shown as contained and '
        'cannot be added again', (tester) async {
      _setSize(tester, 400, 800);
      final alpha = _track('Alpha');
      final repo = _FakePlaylistRepository(
        playlists: [_playlist(2, 'Road Trip', PlaylistKind.custom)],
        tracks: {
          2: [alpha],
        },
      );

      await tester.pumpWidget(_app(tracks: [alpha], playlistRepo: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TrackActionsButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(testL10n().addToPlaylist));
      await tester.pumpAndSettle();

      expect(find.text(testL10n().playlistAlreadyContains), findsOneWidget);
      // The row is disabled: tapping it leaves the sheet open.
      await tester.tap(find.text('Road Trip'));
      await tester.pumpAndSettle();
      expect(find.text(testL10n().selectPlaylist), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('member availability', () {
    testWidgets('playlist detail renders members as playable when id is set',
        (tester) async {
      _setSize(tester, 400, 800);
      final playable = Track(
        id: 42,
        source: 'local',
        sourceTrackId: const LocalTrackId('/m/a.mp3'),
        uri: 'local:/m/a.mp3',
        title: 'Playable',
      );
      final repo = _FakePlaylistRepository(
        playlists: [_playlist(2, 'Mix', PlaylistKind.custom)],
        tracks: {
          2: [playable],
        },
      );
      await tester.pumpWidget(_app(playlistRepo: repo));
      await tester.pumpAndSettle();
      await _openPlaylists(tester);
      await tester.tap(find.text('Mix'));
      await tester.pumpAndSettle();

      final tile = tester.widget<ListTile>(
        find.ancestor(
          of: find.text('Playable'),
          matching: find.byType(ListTile),
        ),
      );
      expect(tile.enabled, isTrue);
      expect(find.text(testL10n().trackUnavailable), findsNothing);
    });
  });

  group('covers', () {
    testWidgets('a playlist cover falls back to the newest member cover',
        (tester) async {
      _setSize(tester, 400, 800);
      final repo = _FakePlaylistRepository(
        playlists: [_playlist(2, 'Covered List', PlaylistKind.custom)],
        tracks: {
          2: [_track('Covered', coverPath: '/tmp/cover.jpg')],
        },
      );

      await tester.pumpWidget(_app(playlistRepo: repo));
      await tester.pumpAndSettle();

      await _openPlaylists(tester);

      expect(repo.coverFor(2)?.coverPath, '/tmp/cover.jpg');
      expect(find.byType(CoverImage), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a playlist without any cover shows the placeholder icon',
        (tester) async {
      _setSize(tester, 400, 800);
      final repo = _FakePlaylistRepository(
        playlists: [_playlist(2, 'Plain', PlaylistKind.custom)],
      );

      await tester.pumpWidget(_app(playlistRepo: repo));
      await tester.pumpAndSettle();

      await _openPlaylists(tester);

      expect(repo.coverFor(2), isNull);
      expect(find.byIcon(Icons.queue_music), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('section selector ring', () {
    testWidgets('selected section sits in the middle with wrapped candidates', (
      tester,
    ) async {
      _setSize(tester, 400, 800);
      await tester.pumpWidget(_app(tracks: [_track('Alpha')]));
      await tester.pumpAndSettle();

      // 全部 selected: left 收藏 (next — arrives on a rightward swipe), right 歌单.
      _expectRing(
        tester,
        left: testL10n().tabFavorites,
        middle: testL10n().tabAll,
        right: testL10n().tabPlaylists,
      );
      expect(find.text('Alpha'), findsOneWidget);

      // 收藏 selected: left 歌单, right 全部.
      await tester.tap(_ringLabel(testL10n().tabFavorites));
      await tester.pumpAndSettle();
      _expectRing(
        tester,
        left: testL10n().tabPlaylists,
        middle: testL10n().tabFavorites,
        right: testL10n().tabAll,
      );
      expect(find.text(testL10n().noFavorites), findsOneWidget);

      // 歌单 selected: left 全部, right 收藏.
      await tester.tap(_ringLabel(testL10n().tabPlaylists));
      await tester.pumpAndSettle();
      _expectRing(
        tester,
        left: testL10n().tabAll,
        middle: testL10n().tabPlaylists,
        right: testL10n().tabFavorites,
      );
      expect(find.text(testL10n().noPlaylists), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping a candidate selects that section and renders its body', (
      tester,
    ) async {
      _setSize(tester, 400, 800);
      await tester.pumpWidget(_app(tracks: [_track('Alpha')]));
      await tester.pumpAndSettle();

      // From 全部 the right candidate 歌单 retreats (wrap backwards).
      await tester.tap(_ringLabel(testL10n().tabPlaylists));
      await tester.pumpAndSettle();
      expect(find.text(testL10n().noPlaylists), findsOneWidget);
      expect(find.text('Alpha'), findsNothing);

      // From 歌单 the left candidate 全部 advances back.
      await tester.tap(_ringLabel(testL10n().tabAll));
      await tester.pumpAndSettle();
      expect(find.text('Alpha'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('cyclic section swipe', () {
    testWidgets('rightward swipes cycle 全部 → 收藏 → 歌单 → 全部 seamlessly', (
      tester,
    ) async {
      _setSize(tester, 400, 800);
      await tester.pumpWidget(_app(tracks: [_track('Alpha')]));
      await tester.pumpAndSettle();

      final page = find.byType(PageView);

      // 全部 → 收藏.
      await tester.fling(page, const Offset(300, 0), 800);
      await tester.pumpAndSettle();
      expect(find.text(testL10n().noFavorites), findsOneWidget);
      _expectRing(
        tester,
        left: testL10n().tabPlaylists,
        middle: testL10n().tabFavorites,
        right: testL10n().tabAll,
      );

      // 收藏 → 歌单.
      await tester.fling(page, const Offset(300, 0), 800);
      await tester.pumpAndSettle();
      expect(find.text(testL10n().noPlaylists), findsOneWidget);
      _expectRing(
        tester,
        left: testL10n().tabAll,
        middle: testL10n().tabPlaylists,
        right: testL10n().tabFavorites,
      );

      // 歌单 → 全部: the wrap-around lands back on 全部 with no dead end.
      await tester.fling(page, const Offset(300, 0), 800);
      await tester.pumpAndSettle();
      expect(find.text('Alpha'), findsOneWidget);
      _expectRing(
        tester,
        left: testL10n().tabFavorites,
        middle: testL10n().tabAll,
        right: testL10n().tabPlaylists,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a leftward swipe from 全部 wraps back to 歌单', (tester) async {
      _setSize(tester, 400, 800);
      await tester.pumpWidget(_app(tracks: [_track('Alpha')]));
      await tester.pumpAndSettle();

      await tester.fling(find.byType(PageView), const Offset(-300, 0), 800);
      await tester.pumpAndSettle();

      expect(find.text(testL10n().noPlaylists), findsOneWidget);
      expect(find.text('Alpha'), findsNothing);
      _expectRing(
        tester,
        left: testL10n().tabAll,
        middle: testL10n().tabPlaylists,
        right: testL10n().tabFavorites,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('header layout', () {
    testWidgets('more is leftmost, add rightmost, search between, selector '
        'centred', (tester) async {
      _setSize(tester, 400, 800);
      await tester.pumpWidget(_app(tracks: [_track('Alpha')]));
      await tester.pumpAndSettle();

      final more = find.byKey(const Key('library_more_menu'));
      final search = find.byKey(const Key('library_search_button'));
      final add = find.byKey(const Key('library_add_playlist'));
      final selector = find.byKey(const Key('library_filter_selector'));

      final moreX = tester.getCenter(more).dx;
      final searchX = tester.getCenter(search).dx;
      final addX = tester.getCenter(add).dx;
      final selectorX = tester.getCenter(selector).dx;

      // 更多 is the leftmost element.
      expect(moreX, lessThan(searchX));
      expect(moreX, lessThan(addX));
      expect(moreX, lessThan(selectorX));
      // 搜索 sits between 更多 and ＋.
      expect(searchX, greaterThan(moreX));
      expect(searchX, lessThan(addX));
      // ＋ is the rightmost element.
      expect(addX, greaterThan(searchX));
      expect(addX, greaterThan(selectorX));
      expect(addX, greaterThan(moreX));
      // The selector is horizontally centred on screen.
      expect(selectorX, closeTo(200, 1));

      // ＋ stays visible in every section (not only 歌单).
      await tester.tap(_ringLabel(testL10n().tabFavorites));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('library_add_playlist')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no overflow at 400×800 and 1280×800', (tester) async {
      for (final size in const [Size(400, 800), Size(1280, 800)]) {
        _setSize(tester, size.width, size.height);
        await tester.pumpWidget(_app(tracks: [_track('Alpha')], size: size));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Exercise the widest ring state (歌单) and the pager too.
        await tester.tap(_ringLabel(testL10n().tabPlaylists));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  });
}

/// The section selector's own label finder.
///
/// Scoped to `library_filter_selector` so it never collides with the same
/// text rendered by a section body (e.g. the pinned 「收藏」 row on the 歌单
/// page).
Finder _ringLabel(String label) => find.descendant(
  of: find.byKey(const Key('library_filter_selector')),
  matching: find.text(label),
);

/// Asserts the ring renders [left] / [middle] / [right] left-to-right and
/// that the middle (selected) label is emphasised over the candidates.
void _expectRing(
  WidgetTester tester, {
  required String left,
  required String middle,
  required String right,
}) {
  expect(_ringLabel(left), findsOneWidget);
  expect(_ringLabel(middle), findsOneWidget);
  expect(_ringLabel(right), findsOneWidget);

  final lx = tester.getCenter(_ringLabel(left)).dx;
  final mx = tester.getCenter(_ringLabel(middle)).dx;
  final rx = tester.getCenter(_ringLabel(right)).dx;
  expect(lx < mx, isTrue, reason: 'left candidate must sit left of the middle');
  expect(mx < rx, isTrue, reason: 'right candidate must sit right of the middle');

  double fontSize(String label) {
    final rich = find.descendant(
      of: _ringLabel(label),
      matching: find.byType(RichText),
    );
    return tester.widget<RichText>(rich.first).text.style!.fontSize!;
  }

  final middleSize = fontSize(middle);
  expect(middleSize, greaterThan(fontSize(left)));
  expect(middleSize, greaterThan(fontSize(right)));
}