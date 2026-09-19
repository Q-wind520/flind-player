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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/playback_state.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/models/track_sort.dart';
import 'package:flind_player/core/repositories/favorites_repository.dart';
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
import 'package:flind_player/features/library/widgets/track_actions_button.dart';

import 'support/l10n.dart';

Track _track(String title, {String? artist, Duration? duration}) {
  final path = '/music/$title.mp3';
  return Track(
    source: 'local',
    sourceTrackId: LocalTrackId(path),
    uri: 'local:$path',
    title: title,
    artist: artist,
    duration: duration,
  );
}

Track _biliTrack(String title, {String? artist, Duration? duration}) {
  final bvid = 'BV_$title';
  return Track(
    source: 'bilibili',
    sourceTrackId: BiliTrackId(bvid: bvid, cid: -1),
    uri: 'bilibili:$bvid:-1',
    title: title,
    artist: artist,
    duration: duration,
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

  void dispose() {
    for (final c in _listeners) {
      c.close();
    }
    _listeners.clear();
  }
}

/// Pumps [LibraryScreen] with the library, sync, playback and favourites
/// providers overridden.
///
/// `playbackStateProvider` must be overridden: the screen watches it to
/// highlight the playing row, and the real provider would construct the
/// just_audio-backed controller, which cannot run under `flutter test`.
/// `librarySyncStateProvider` is overridden so the real sync service (and its
/// database) is never constructed.
///
/// The viewport is set to 400 px wide so the compact (list) layout renders
/// by default.  Tests that need the wide-screen grid layout must set the
/// viewport themselves.
Widget _app({
  List<Track> tracks = const <Track>[],
  List<Track> favourites = const <Track>[],
  LibrarySyncState syncState = LibrarySyncState.idle,
  FutureOr<List<Track>> Function(Ref ref, String query)? search,
  Stream<DownloadProgress> progress = const Stream<DownloadProgress>.empty(),
  TrackSort sort = TrackSort.title,
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
      downloadProgressProvider.overrideWith((ref) => progress),
      audioCacheEntryProvider.overrideWith((ref, track) async => null),
      favoritesRepositoryProvider.overrideWithValue(favRepo),
      favoritesProvider.overrideWith((ref) => favRepo.watchFavorites()),
      librarySortProvider.overrideWith(() => _FakeLibrarySortNotifier(sort)),
      if (search != null) librarySearchProvider.overrideWith(search),
    ],
    child: localizedApp(
      MediaQuery(
        data: const MediaQueryData(size: Size(400, 800)),
        child: const LibraryScreen(),
      ),
    ),
  );
}

void main() {
  testWidgets('renders tracks from the library', (tester) async {
    // Set a narrow view so the compact (list) layout renders.
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        tracks: [
          _track(
            'Alpha',
            artist: 'Artist A',
            duration: const Duration(seconds: 65),
          ),
          _track('Beta', duration: const Duration(seconds: 125)),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Artist A'), findsOneWidget);
    expect(find.text('未知艺术家'), findsOneWidget);
    expect(find.text('1:05'), findsOneWidget);
    expect(find.text('2:05'), findsOneWidget);
    expect(find.text('曲库还是空的'), findsNothing);
  });

  testWidgets('renders the empty state when the library is empty', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('曲库还是空的'), findsOneWidget);
    expect(find.text('导入本地音乐'), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
  });

  testWidgets('under iOS the local-library actions are replaced by a note', (
    tester,
  ) async {
    // flutter_test verifies foundation debug variables before package:test
    // tear-downs run, so the override must also be cleared in the body.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    try {
      await tester.pumpWidget(_app(tracks: [_track('Alpha')]));
      await tester.pumpAndSettle();

      // The note replaces the library body even when tracks exist.
      expect(find.text('iOS 暂不支持本地曲库'), findsOneWidget);
      expect(find.text('曲库还是空的'), findsNothing);

      // No library-management entry points: add folder, import, rescan, sort.
      expect(find.text('添加文件夹'), findsNothing);
      expect(find.text('导入文件'), findsNothing);
      expect(find.byIcon(Icons.sort), findsNothing);
      expect(find.byType(TextField), findsNothing);

      // The Bilibili favourites browser stays available. Its overflow icon
      // adapts to the platform, so find the button itself.
      final menuButton = find.byWidgetPredicate(
        (widget) => widget is PopupMenuButton,
      );
      expect(menuButton, findsOneWidget);
      await tester.tap(menuButton);
      await tester.pumpAndSettle();
      expect(find.text('浏览 B 站收藏夹'), findsOneWidget);
      expect(find.text('重新扫描'), findsNothing);
      expect(find.text('添加文件夹'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('renders local and bilibili tracks with source badges', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(tracks: [_track('Local Song'), _biliTrack('Online Song')]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Local Song'), findsOneWidget);
    expect(find.text('Online Song'), findsOneWidget);
    expect(find.text('本地'), findsOneWidget);
    expect(find.text('B站'), findsOneWidget);
  });

  testWidgets('typing a query shows search results and hides the full list', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        tracks: [_track('Local Song')],
        search: (ref, query) async =>
            query == 'Hit' ? <Track>[_biliTrack('Search Hit')] : <Track>[],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Local Song'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Hit');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Search Hit'), findsOneWidget);
    expect(find.text('Local Song'), findsNothing);
  });

  testWidgets('a search with no matches shows the empty-search state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        tracks: [_track('Local Song')],
        search: (ref, query) async => <Track>[],
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'nothing');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('没有找到匹配的歌曲'), findsOneWidget);
  });

  testWidgets('shows progress and counts while scanning', (tester) async {
    await tester.pumpWidget(
      _app(
        tracks: [_track('Alpha')],
        syncState: const LibrarySyncState(
          phase: LibrarySyncPhase.scanning,
          discovered: 48,
          processed: 12,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('扫描中 12/48'), findsOneWidget);
  });

  testWidgets('shows the error message when a sync fails', (tester) async {
    await tester.pumpWidget(
      _app(
        tracks: [_track('Alpha')],
        syncState: LibrarySyncState(
          phase: LibrarySyncPhase.failed,
          error: StateError('扫描目录不可读'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('扫描目录不可读'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('does not overflow at 400 px width', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        tracks: [
          _track(
            '一个非常非常长的歌曲标题用来验证在窄屏下会被省略号截断',
            artist: '一个同样非常长的艺术家名称',
            duration: const Duration(minutes: 12, seconds: 34),
          ),
          _biliTrack('另一个很长的在线歌曲标题同样需要被截断', artist: '一个很长的UP主名称'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('一个非常非常长的歌曲标题用来验证在窄屏下会被省略号截断'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the actions menu for online tracks', (tester) async {
    await tester.pumpWidget(
      _app(tracks: [_track('Local Song'), _biliTrack('Online Song')]),
    );
    await tester.pumpAndSettle();

    // Both tracks should have the actions menu button.
    expect(find.byType(TrackActionsButton), findsNWidgets(2));
  });

  testWidgets('online track actions menu has cache option', (tester) async {
    final progress = StreamController<DownloadProgress>.broadcast();
    addTearDown(progress.close);

    await tester.pumpWidget(
      _app(tracks: [_biliTrack('Online Song')], progress: progress.stream),
    );
    await tester.pumpAndSettle();

    // Open the actions menu for the online track.
    await tester.tap(find.byType(TrackActionsButton));
    await tester.pumpAndSettle();

    expect(find.text('缓存到本地'), findsOneWidget);
  });

  testWidgets('shows the favourites filter bar', (tester) async {
    await tester.pumpWidget(_app(tracks: [_track('Alpha')]));
    await tester.pumpAndSettle();

    expect(find.text('全部'), findsOneWidget);
    expect(find.text('收藏'), findsOneWidget);
  });

  testWidgets('switching to favourites filter shows empty state', (
    tester,
  ) async {
    await tester.pumpWidget(_app(tracks: [_track('Alpha')]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('收藏'));
    await tester.pumpAndSettle();

    expect(find.text('还没有收藏的歌曲'), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
  });

  testWidgets('switching to favourites filter shows only favourited tracks', (
    tester,
  ) async {
    final alpha = _track('Alpha');
    final beta = _track('Beta');

    await tester.pumpWidget(_app(tracks: [alpha, beta], favourites: [alpha]));
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

  testWidgets('favourites filter with search shows matching favourites', (
    tester,
  ) async {
    final alpha = _track('Alpha Song');
    final beta = _track('Beta Song');

    await tester.pumpWidget(
      _app(
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
    await tester.enterText(find.byType(TextField), 'Alpha');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Alpha Song'), findsOneWidget);
    expect(find.text('Beta Song'), findsNothing);
  });

  testWidgets(
    'favourites filter with search and no matches shows empty state',
    (tester) async {
      final alpha = _track('Alpha Song');

      await tester.pumpWidget(
        _app(
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
      await tester.enterText(find.byType(TextField), 'Nothing');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('没有找到匹配的收藏'), findsOneWidget);
    },
  );
}

/// Fake [LibrarySortNotifier] that returns a fixed value immediately.
class _FakeLibrarySortNotifier extends LibrarySortNotifier {
  _FakeLibrarySortNotifier(this._sort);

  final TrackSort _sort;

  @override
  Future<TrackSort> build() async => _sort;
}
