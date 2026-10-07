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
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import 'package:flind_player/core/models/library_view.dart';
import 'package:flind_player/core/models/playback_state.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/models/track_sort.dart';
import 'package:flind_player/core/repositories/favorites_repository.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/cache/audio_cache_store.dart';
import 'package:flind_player/data/cache/download_manager.dart';
import 'package:flind_player/data/providers/deletion_providers.dart';
import 'package:flind_player/data/providers/offline_cache_providers.dart';
import 'package:flind_player/data/providers/cache_providers.dart';
import 'package:flind_player/data/providers/library_providers.dart';
import 'package:flind_player/data/providers/persistence_providers.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/data/services/library_sync_service.dart';
import 'package:flind_player/data/services/track_deletion_service.dart';
import 'package:flind_player/features/library/library_screen.dart';
import 'package:flind_player/features/library/library_sort_provider.dart';
import 'package:flind_player/features/library/library_view_provider.dart';
import 'package:flind_player/features/library/widgets/cache_action_button.dart';
import 'package:flind_player/features/library/widgets/track_actions_button.dart';
import 'package:flind_player/shared/empty_state.dart';

import 'support/l10n.dart';

Track _track(String title, {String? artist, Duration? duration, int? id}) {
  final path = '/music/$title.mp3';
  return Track(
    id: id,
    source: 'local',
    sourceTrackId: LocalTrackId(path),
    uri: 'local:$path',
    title: title,
    artist: artist,
    duration: duration,
  );
}

Track _biliTrack(String title, {String? artist, Duration? duration, int? id}) {
  final bvid = 'BV_$title';
  return Track(
    id: id,
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
  Future<CachedAudio?> Function(Ref ref, Track track)? cacheEntry,
  LibraryView view = LibraryView.list,
  Track? currentTrack,
  Future<void> Function(Track track)? deleteTrack,
  Future<List<CachedAudio>> Function(Ref ref)? offlineEntries,
}) {
  final favRepo = _InMemoryFavoritesRepository();
  for (final track in favourites) {
    favRepo.toggleFavorite(track);
  }
  return ProviderScope(
    overrides: [
      libraryTracksProvider.overrideWith((ref) => Stream.value(tracks)),
      playbackStateProvider.overrideWith(
        (ref) => Stream.value(
          currentTrack == null
              ? PlaybackState.idle
              : PlaybackState.idle.copyWith(currentTrack: currentTrack),
        ),
      ),
      librarySyncStateProvider.overrideWith((ref) => Stream.value(syncState)),
      downloadProgressProvider.overrideWith((ref) => progress),
      audioCacheEntryProvider.overrideWith(
        cacheEntry ?? (ref, track) async => null,
      ),
      favoritesRepositoryProvider.overrideWithValue(favRepo),
      favoritesProvider.overrideWith((ref) => favRepo.watchFavorites()),
      librarySortProvider.overrideWith(() => _FakeLibrarySortNotifier(sort)),
      libraryViewsProvider.overrideWith(() => _FakeLibraryViewsNotifier(view)),
      if (search != null) librarySearchProvider.overrideWith(search),
      if (deleteTrack != null)
        trackDeletionServiceProvider.overrideWithValue(
          _FakeDeletionService(deleteTrack),
        ),
      if (offlineEntries != null)
        offlineCacheEntriesProvider.overrideWith(offlineEntries),
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
            id: 1,
          ),
          _track('Beta', duration: const Duration(seconds: 125), id: 2),
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

  testWidgets('全部 can render the waterfall view', (tester) async {
    await tester.pumpWidget(
      _app(
        tracks: [_track('Alpha', id: 1), _track('Beta', id: 2)],
        view: LibraryView.waterfall,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MasonryGridView), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
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

  testWidgets('empty library renders a single EmptyState panel', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // The empty library panel is an EmptyState, not a bespoke layout.
    expect(find.byType(EmptyState), findsOneWidget);
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

      // The Bilibili favourites browser stays available via the more menu.
      expect(find.byKey(const Key('library_more_menu')), findsOneWidget);
      await tester.tap(find.byKey(const Key('library_more_menu')));
      await tester.pumpAndSettle();
      expect(find.text('浏览 B 站收藏夹'), findsOneWidget);
      // No local-library submenu on iOS.
      expect(find.text('本地'), findsNothing);
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

  testWidgets('uncached online track shows the offline-cache action', (
    tester,
  ) async {
    await tester.pumpWidget(_app(tracks: [_biliTrack('Online Song')]));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TrackActionsButton));
    await tester.pumpAndSettle();

    expect(find.text('离线缓存'), findsOneWidget);
    expect(find.text('已缓存'), findsNothing);
  });

  testWidgets(
    'online-cached online track still offers the offline-cache action',
    (tester) async {
      final track = _biliTrack('Online Song');
      await tester.pumpWidget(
        _app(
          tracks: [track],
          // A play-through "online" cache entry (pinned = false) must keep
          // offering 离线缓存 so it can be promoted to an offline download.
          cacheEntry: (ref, t) async => CachedAudio(
            id: 1,
            source: t.source,
            sourceTrackId: 'BV_Online Song:-1',
            filePath: '/cache/audio.m4a',
            bytes: 1024,
            qualityId: 'q',
            pinned: false,
            cachedAt: DateTime(2026),
            lastAccessedAt: DateTime(2026),
            coverBytes: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TrackActionsButton));
      await tester.pumpAndSettle();

      expect(find.text('离线缓存'), findsOneWidget);
      expect(find.text('已缓存'), findsNothing);
      final item = tester.widget<PopupMenuItem<dynamic>>(
        find.ancestor(
          of: find.text('离线缓存'),
          matching: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
        ),
      );
      expect(item.enabled, isTrue);
    },
  );

  testWidgets('offline-cached online track shows a disabled cached label', (
    tester,
  ) async {
    final track = _biliTrack('Online Song');
    await tester.pumpWidget(
      _app(
        tracks: [track],
        cacheEntry: (ref, t) async => CachedAudio(
          id: 1,
          source: t.source,
          sourceTrackId: 'BV_Online Song:-1',
          filePath: '/cache/audio.m4a',
          bytes: 1024,
          qualityId: 'q',
          pinned: true,
          cachedAt: DateTime(2026),
          lastAccessedAt: DateTime(2026),
          coverBytes: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TrackActionsButton));
    await tester.pumpAndSettle();

    expect(find.text('已缓存'), findsOneWidget);
    expect(find.text('离线缓存'), findsNothing);
    // The item is a `PopupMenuItem<_TrackAction>`; `find.byType` would not
    // match the private type argument, so match the base type by predicate.
    final item = tester.widget<PopupMenuItem<dynamic>>(
      find.ancestor(
        of: find.text('已缓存'),
        matching: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
      ),
    );
    expect(item.enabled, isFalse);
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

  testWidgets('the search field is always visible on 全部', (tester) async {
    await tester.pumpWidget(_app(tracks: [_track('Alpha', id: 1)]));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    // No toggle button: the field is always shown on 全部.
    expect(find.byKey(const Key('library_search_button')), findsNothing);
  });

  testWidgets('the search field is hidden on 收藏 and 歌单', (tester) async {
    await tester.pumpWidget(_app(tracks: [_track('Alpha', id: 1)]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('收藏'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('歌单'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('the new-playlist button is only shown on 歌单', (tester) async {
    await tester.pumpWidget(_app(tracks: [_track('Alpha', id: 1)]));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('library_add_playlist')), findsNothing);

    await tester.tap(find.text('歌单'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('library_add_playlist')), findsOneWidget);
  });

  testWidgets('a query is retained when leaving and returning to 全部', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        tracks: [_track('Local Song', id: 1)],
        search: (ref, query) async =>
            query == 'Hit' ? <Track>[_biliTrack('Search Hit')] : <Track>[],
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Hit');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('Search Hit'), findsOneWidget);

    await tester.tap(find.text('收藏'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('全部'));
    await tester.pumpAndSettle();
    expect(find.text('Search Hit'), findsOneWidget);
  });

  testWidgets('the search field rides along with the 全部 page on a swipe', (
    tester,
  ) async {
    await tester.pumpWidget(_app(tracks: [_track('Alpha', id: 1)]));
    await tester.pumpAndSettle();

    final field = find.byType(TextField);
    expect(field, findsOneWidget);
    final restingX = tester.getTopLeft(field).dx;

    // Drag the pager leftwards without releasing, so the 全部 page is
    // mid-transition; the field must travel with that page.
    final page = tester.getRect(find.byType(PageView));
    final gesture = await tester.startGesture(
      Offset(page.center.dx, page.bottom - 40),
    );
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(-50, 0));
      await tester.pump();
    }

    expect(tester.getTopLeft(field).dx, lessThan(restingX));

    await gesture.up();
    await tester.pumpAndSettle();
    // Once the swipe settles on 收藏 the field has left with its page.
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('the header row shows the selector and two icons', (
    tester,
  ) async {
    await tester.pumpWidget(_app(tracks: [_track('Alpha')]));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('library_filter_selector')), findsOneWidget);
    expect(find.text('全部'), findsOneWidget);
    expect(find.text('收藏'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byKey(const Key('library_more_menu')), findsOneWidget);
    // The old sort icon is gone: sort lives in the overflow menu now.
    expect(find.byIcon(Icons.sort), findsNothing);
  });

  testWidgets('swiping the selector changes the filter', (tester) async {
    await tester.pumpWidget(_app(tracks: [_track('Alpha')]));
    await tester.pumpAndSettle();

    expect(find.text('Alpha'), findsOneWidget);

    await tester.fling(
      find.byKey(const Key('library_filter_selector')),
      const Offset(120, 0),
      800,
    );
    await tester.pumpAndSettle();

    // The favourites filter is now active and empty.
    expect(find.text('还没有收藏的歌曲'), findsOneWidget);
  });

  testWidgets('the more menu exposes local, sort and view submenus', (
    tester,
  ) async {
    await tester.pumpWidget(_app(tracks: [_biliTrack('Online', id: 2)]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('library_more_menu')));
    await tester.pumpAndSettle();

    expect(find.text('本地'), findsOneWidget);
    expect(find.text('排序'), findsOneWidget);
    expect(find.text('视图'), findsOneWidget);

    await tester.tap(find.text('本地'));
    await tester.pumpAndSettle();
    expect(find.text('添加文件夹'), findsOneWidget);
    expect(find.text('重新扫描'), findsOneWidget);
    expect(find.text('导入文件'), findsOneWidget);
  });

  testWidgets('the view submenu on 全部 offers all three views', (tester) async {
    await tester.pumpWidget(_app(tracks: [_track('Alpha', id: 1)]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('library_more_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('视图'));
    await tester.pumpAndSettle();

    expect(find.text('展柜视图'), findsOneWidget);
    expect(find.text('列表视图'), findsOneWidget);
    expect(find.text('瀑布流视图'), findsOneWidget);
  });

  testWidgets('the more menu does not overflow at 400 px', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(tracks: [_track('Alpha', id: 1)]));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library_more_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('排序'));
    await tester.pumpAndSettle();

    expect(find.text('最近添加'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sync-disabled local actions are not tappable', (tester) async {
    await tester.pumpWidget(
      _app(
        tracks: [_biliTrack('Alpha', id: 1)],
        syncState: const LibrarySyncState(
          phase: LibrarySyncPhase.scanning,
          discovered: 1,
          processed: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library_more_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('本地'));
    await tester.pumpAndSettle();

    final addFolder = tester.widget<MenuItemButton>(
      find.ancestor(
        of: find.text('添加文件夹'),
        matching: find.byType(MenuItemButton),
      ),
    );
    expect(addFolder.onPressed, isNull);
  });

  testWidgets('全部 track menu offers delete but not remove-from-playlist', (
    tester,
  ) async {
    await tester.pumpWidget(_app(tracks: [_track('Alpha', id: 1)]));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TrackActionsButton));
    await tester.pumpAndSettle();

    expect(find.text('删除歌曲'), findsOneWidget);
    expect(find.text('移出歌单'), findsNothing);
  });

  testWidgets('deleting asks for confirmation, then removes the row', (
    tester,
  ) async {
    final deleted = <String>[];
    await tester.pumpWidget(
      _app(
        tracks: [_track('Alpha', id: 1)],
        deleteTrack: (track) async => deleted.add(track.uri),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TrackActionsButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除歌曲'));
    await tester.pumpAndSettle();

    expect(find.text('删除歌曲？'), findsOneWidget);
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(deleted, ['local:/music/Alpha.mp3']);
  });

  testWidgets('deleting the currently playing track does not throw', (
    tester,
  ) async {
    final track = _track('Alpha', id: 1);
    await tester.pumpWidget(
      _app(tracks: [track], currentTrack: track, deleteTrack: (t) async {}),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TrackActionsButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除歌曲'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('deleting a search result clears it from the list', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      _app(
        tracks: [_track('Local Song', id: 1)],
        search: (ref, query) async {
          calls++;
          return calls == 1
              ? <Track>[_biliTrack('Search Hit', id: 2)]
              : <Track>[];
        },
        deleteTrack: (track) async {},
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Hit');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('Search Hit'), findsOneWidget);

    await tester.tap(find.byType(TrackActionsButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除歌曲'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(find.text('Search Hit'), findsNothing);
  });

  testWidgets('deleting refreshes the offline-cache list', (tester) async {
    var reads = 0;
    await tester.pumpWidget(
      _app(
        tracks: [_track('Alpha', id: 1)],
        deleteTrack: (track) async {},
        offlineEntries: (ref) async {
          reads++;
          return const <CachedAudio>[];
        },
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(LibraryScreen)),
    );
    final subscription = container.listen(
      offlineCacheEntriesProvider,
      (previous, next) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    await tester.pumpAndSettle();
    final before = reads;

    await tester.tap(find.byType(TrackActionsButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除歌曲'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(reads, greaterThan(before));
  });
}

/// Fake [LibrarySortNotifier] that returns a fixed value immediately.
class _FakeLibrarySortNotifier extends LibrarySortNotifier {
  _FakeLibrarySortNotifier(this._sort);

  final TrackSort _sort;

  @override
  Future<TrackSort> build() async => _sort;
}

/// Fake [LibraryViewsNotifier] returning [view] for every scope.
class _FakeLibraryViewsNotifier extends LibraryViewsNotifier {
  _FakeLibraryViewsNotifier(this._view);

  final LibraryView _view;

  @override
  Future<LibraryViews> build() async =>
      LibraryViews({for (final scope in LibraryViewScope.values) scope: _view});
}

/// Fake [TrackDeletionService] that forwards to an in-test callback.
class _FakeDeletionService implements TrackDeletionService {
  _FakeDeletionService(this._onDelete);

  final Future<void> Function(Track track) _onDelete;

  @override
  Future<void> deleteEverywhere(Track track) => _onDelete(track);
}
