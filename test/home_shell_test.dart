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
import 'dart:io';

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:flind_player/core/models/playback_queue.dart';
import 'package:flind_player/core/models/playback_state.dart';
import 'package:flind_player/core/models/repeat_mode.dart';
import 'package:flind_player/core/models/track_sort.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/repositories/favorites_repository.dart';
import 'package:flind_player/core/repositories/settings_repository.dart';
import 'package:flind_player/core/services/playback_controller.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/cache/audio_cache_store.dart';
import 'package:flind_player/data/cache/download_manager.dart';
import 'package:flind_player/data/providers/cache_providers.dart';
import 'package:flind_player/data/providers/library_providers.dart';
import 'package:flind_player/data/providers/persistence_providers.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/data/services/library_sync_service.dart';
import 'package:flind_player/features/home/home_shell.dart';
import 'package:flind_player/features/library/widgets/cache_action_button.dart';
import 'package:flind_player/features/player/mini_player_bar.dart';
import 'package:flind_player/features/player/player_screen.dart';
import 'package:flind_player/features/search/search_providers.dart';
import 'package:flind_player/features/settings/settings_providers.dart';
import 'package:flind_player/core/models/app_language.dart';
import 'package:flind_player/core/models/app_theme_mode.dart';

import 'support/l10n.dart';

/// In-memory [SettingsRepository] that satisfies the settings screen.
class _FakeSettingsRepository implements SettingsRepository {
  @override
  Future<AppLanguage> appLanguage() async => AppLanguage.system;

  @override
  Future<void> setAppLanguage(AppLanguage language) async {}

  @override
  Future<AppThemeMode> appThemeMode() async => AppThemeMode.system;

  @override
  Future<void> setAppThemeMode(AppThemeMode mode) async {}

  _FakeSettingsRepository(this.current);

  CacheSettings current;

  @override
  Future<CacheSettings> cacheSettings() async => current;

  @override
  Future<void> updateCacheSettings(CacheSettings settings) async {
    current = settings;
  }

  @override
  Stream<CacheSettings> watchCacheSettings() async* {
    yield current;
  }

  @override
  Future<TrackSort> librarySort() async => TrackSort.title;

  @override
  Future<void> setLibrarySort(TrackSort sort) async {}

  Future<void> dispose() async {}
}

/// [AudioCacheStore] stand-in that never touches a database or filesystem.
class _FakeCacheStore implements AudioCacheStore {
  @override
  Future<void> clear() async {}

  @override
  Future<void> remove(int id) async {}

  @override
  Future<List<CachedAudio>> entries() async => const <CachedAudio>[];

  @override
  Future<int> totalBytes() async => 0;

  @override
  Future<CachedAudio?> lookup(String source, String sourceTrackId) async =>
      null;

  @override
  Future<void> touch(int id) async {}

  @override
  Future<void> setPinned(int id, bool pinned) async {}

  @override
  Future<CachedAudio> insert({
    required String source,
    required String sourceTrackId,
    required String filePath,
    required int bytes,
    required String qualityId,
    required bool pinned,
    String? contentHash,
  }) async => throw UnimplementedError();

  @override
  Future<EvictionResult> ensureSpace(int incomingBytes) async =>
      const EvictionResult(evictedCount: 0, freedBytes: 0, hasSpace: true);

  @override
  Future<EvictionResult> enforceLimit() async =>
      const EvictionResult(evictedCount: 0, freedBytes: 0, hasSpace: true);

  @override
  Future<String> cacheDirectoryPath() async => Directory.systemTemp.path;

  @override
  Future<int> deduplicateByContent() async => 0;

  @override
  Future<IntegrityReport> checkIntegrity() async =>
      const IntegrityReport(rowsRemoved: 0, orphansRemoved: 0);

  @override
  File fileFor({
    required String source,
    required String sourceTrackId,
    required String extension,
  }) => throw UnimplementedError();
}

/// Records calls so the player route never constructs the real controller.
class _FakePlaybackController implements PlaybackController {
  @override
  Stream<PlaybackState> get state => const Stream.empty();

  @override
  PlaybackState get currentState => PlaybackState.idle;

  @override
  PlaybackQueue get queue => PlaybackQueue.empty;

  @override
  Future<void> playQueue(
    PlaybackQueue queue, {
    int index = 0,
    bool autoPlay = true,
  }) async {}

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
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> dispose() async {}
}

/// Minimal in-memory [FavoritesRepository] used only for read paths.
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
  Future<void> updateFavoriteCover(
    String uri, {
    String? coverPath,
    String? coverUrl,
  }) async {}

  @override
  Future<bool> toggleFavorite(Track track) async => false;
}

/// A loaded, playing state so the mini player bar is visible.
PlaybackState _playingState() => PlaybackState(
  isPlaying: true,
  isBuffering: false,
  isCompleted: false,
  position: const Duration(seconds: 10),
  duration: const Duration(minutes: 3),
  currentTrack: Track(
    source: 'local',
    sourceTrackId: const LocalTrackId('/music/test.mp3'),
    uri: 'local:/music/test.mp3',
    title: '测试歌曲',
    artist: '测试艺术家',
  ),
);

/// Pumps [HomeShell] with all providers overridden so no real database,
/// network, controller or sync service is constructed.
Widget _app({PlaybackState playback = PlaybackState.idle}) {
  final settings = _FakeSettingsRepository(CacheSettings.defaults);
  final store = _FakeCacheStore();

  return ProviderScope(
    overrides: [
      // Playback.
      playbackStateProvider.overrideWith((ref) => Stream.value(playback)),
      playbackControllerProvider.overrideWith(
        (ref) => _FakePlaybackController(),
      ),
      favoritesRepositoryProvider.overrideWithValue(_FakeFavoritesRepository()),
      // Library.
      libraryTracksProvider.overrideWith((ref) => Stream.value(<Track>[])),
      librarySyncStateProvider.overrideWith(
        (ref) => Stream.value(LibrarySyncState.idle),
      ),
      downloadProgressProvider.overrideWith(
        (ref) => const Stream<DownloadProgress>.empty(),
      ),
      audioCacheEntryProvider.overrideWith((ref, track) async => null),
      // Search (not used initially, but overrides needed if the search
      // screen is pumped).
      biliSearchResultsProvider.overrideWith((ref, query) async => <Track>[]),
      // Settings.
      settingsRepositoryProvider.overrideWith((ref) => settings),
      audioCacheStoreProvider.overrideWith((ref) => store),
      audioCacheUsageProvider.overrideWith((ref) async => 0),
      audioCacheEntryCountProvider.overrideWith((ref) async => 0),
      // Settings screen's library section needs scan roots and sync service.
      scanRootsProvider.overrideWith((ref) async => <String>[]),
      librarySyncServiceProvider.overrideWith(
        (ref) => _FakeLibrarySyncService(),
      ),
      // About section requires package info.
      packageInfoProvider.overrideWith(
        (ref) async => PackageInfo(
          appName: 'Flind Player',
          packageName: 'flind_player',
          version: '0.0.0',
          buildNumber: '0',
        ),
      ),
    ],
    child: localizedApp(const HomeShell()),
  );
}

/// Minimal stand-in so the settings screen's sync actions never construct the
/// real service (and therefore never touch the database) during widget tests.
class _FakeLibrarySyncService implements LibrarySyncService {
  @override
  LibrarySyncState get current => LibrarySyncState.idle;

  @override
  bool get isRunning => false;

  @override
  Stream<LibrarySyncState> get state =>
      Stream<LibrarySyncState>.value(LibrarySyncState.idle);

  @override
  Future<void> sync() async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets('renders three destinations with correct labels', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Labels match the screen each destination shows: search / library / settings.
    // The search screen no longer has an AppBar, and the bottom bar only shows
    // the selected destination's label, so 搜索 appears exactly once.
    expect(find.text('搜索'), findsOneWidget);
    // Unselected labels stay mounted (faded) for the transition, so the finder
    // still sees them even though they are not visible.
    expect(find.text('曲库'), findsOneWidget); // nav label, faded (unselected)
    expect(find.text('设置'), findsOneWidget); // nav label, faded (unselected)

    // The previously mismatched labels are gone.
    expect(find.text('首页'), findsNothing);
    expect(find.text('账户'), findsNothing);
    expect(find.text('正在播放'), findsNothing);
    expect(find.byIcon(Icons.home_outlined), findsNothing);
    expect(find.byIcon(Icons.account_circle_outlined), findsNothing);
  });

  testWidgets(
    'bottom NavigationBar is compact and shows only the selected label',
    (tester) async {
      // A narrow portrait window uses the compact shell with a bottom bar.
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      // Unselected labels are hidden while the selected one stays visible.
      expect(
        bar.labelBehavior,
        NavigationDestinationLabelBehavior.onlyShowSelected,
      );
      // Narrower than the Material default of 80 px.
      expect(bar.height, 60);
      expect(tester.getSize(find.byType(NavigationBar)).height, 60);
    },
  );

  testWidgets('tapping 曲库 shows the library screen', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Default is 首页 (SearchScreen) which shows the search hint.
    expect(find.text('搜索 Bilibili 上的音乐'), findsOneWidget);

    // The unselected label is hidden, so tap the destination's icon instead.
    await tester.tap(find.byIcon(Icons.library_music_outlined));
    await tester.pumpAndSettle();

    // LibraryScreen shows the empty library message.
    expect(find.text('曲库还是空的'), findsOneWidget);
  });

  testWidgets('tapping 设置 shows the settings screen', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // The unselected label is hidden, so tap the destination's icon instead.
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    // SettingsScreen shows the cache settings.
    expect(find.text('缓存上限'), findsOneWidget);
  });

  testWidgets('does not have 正在播放 in navigation', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Verify no NavigationDestination with 正在播放 label exists.
    expect(find.text('正在播放'), findsNothing);
    expect(find.byIcon(Icons.play_circle_outline), findsNothing);
  });

  testWidgets('portrait desktop (700×1000) uses mobile shell', (tester) async {
    tester.view.physicalSize = const Size(700, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // A portrait-taller-than-wide desktop window must use the mobile
    // layout: bottom NavigationBar present, NavigationRail absent.
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('landscape desktop (1200×800) uses expanded shell', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // A wide landscape window must use the expanded layout with
    // NavigationRail and no bottom NavigationBar.
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  // The mini bar opens the same full-screen player regardless of window
  // width: no bottom sheet on compact, no docked panel on expanded.
  group('mini player opens the full-screen player', () {
    for (final size in <Size>[const Size(400, 800), const Size(1200, 800)]) {
      testWidgets('at ${size.width}x${size.height}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_app(playback: _playingState()));
        await tester.pumpAndSettle();

        expect(find.byKey(MiniPlayerBar.barKey), findsOneWidget);

        await tester.tap(find.byKey(MiniPlayerBar.barKey));
        await tester.pumpAndSettle();

        // The full-screen player route is pushed on every window size.
        expect(find.byType(PlayerScreen), findsOneWidget);

        // The collapse affordance returns to the shell.
        await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
        await tester.pumpAndSettle();
        expect(find.byType(PlayerScreen), findsNothing);
      });
    }
  });
}
