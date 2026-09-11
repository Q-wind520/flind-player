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

import 'package:file_picker/file_picker.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/models/track_sort.dart';
import 'package:flind_player/core/repositories/music_library_repository.dart';
import 'package:flind_player/core/repositories/settings_repository.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/cache/audio_cache_store.dart';
import 'package:flind_player/data/providers/cache_providers.dart';
import 'package:flind_player/data/providers/database_providers.dart';
import 'package:flind_player/data/providers/library_providers.dart';
import 'package:flind_player/data/services/library_sync_service.dart';
import 'package:flind_player/data/sources/local/artwork_cache.dart';
import 'package:flind_player/data/sources/local/local_library_scanner.dart';
import 'package:flind_player/data/sources/local/local_metadata_reader.dart';
import 'package:flind_player/features/settings/settings_providers.dart';
import 'package:flind_player/features/settings/settings_screen.dart';
import 'package:flind_player/platform/permissions/permission_providers.dart';
import 'package:flind_player/platform/permissions/permission_service.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// In-memory [SettingsRepository] that records writes and replays them through
/// its watch stream.
class _FakeSettingsRepository implements SettingsRepository {
  _FakeSettingsRepository(this.current);

  CacheSettings current;
  final List<CacheSettings> writes = <CacheSettings>[];
  final StreamController<CacheSettings> _updates =
      StreamController<CacheSettings>.broadcast();

  @override
  Future<CacheSettings> cacheSettings() async => current;

  @override
  Future<TrackSort> librarySort() async => TrackSort.title;

  @override
  Future<void> setLibrarySort(TrackSort sort) async {}

  @override
  Future<void> updateCacheSettings(CacheSettings settings) async {
    current = settings;
    writes.add(settings);
    _updates.add(settings);
  }

  @override
  Stream<CacheSettings> watchCacheSettings() async* {
    yield current;
    yield* _updates.stream;
  }

  Future<void> dispose() => _updates.close();
}

/// [AudioCacheStore] stand-in that records destructive calls and never touches
/// a database or the filesystem.
class _FakeCacheStore implements AudioCacheStore {
  int clearCalls = 0;
  int removeCalls = 0;

  @override
  Future<void> clear() async {
    clearCalls++;
  }

  @override
  Future<void> remove(int id) async {
    removeCalls++;
  }

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
  }) async => throw UnimplementedError();

  @override
  Future<EvictionResult> ensureSpace(int incomingBytes) async =>
      const EvictionResult(evictedCount: 0, freedBytes: 0, hasSpace: true);

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

/// Minimal [MusicLibraryRepository] that records scan-root mutations.
class _FakeMusicLibraryRepository implements MusicLibraryRepository {
  final List<String> roots;
  final List<String> addCalls = [];
  final List<String> removeCalls = [];

  _FakeMusicLibraryRepository([List<String>? roots])
    : roots = roots != null ? List<String>.from(roots) : [];

  @override
  Future<List<String>> scanRoots() async => roots;

  @override
  Future<void> addScanRoot(String path) async {
    addCalls.add(path);
    roots.add(path);
  }

  @override
  Future<void> removeScanRoot(String path) async {
    removeCalls.add(path);
    roots.remove(path);
  }

  // -- Stubs for methods not exercised by the settings screen --

  @override
  Future<List<Track>> allTracks({TrackSort sort = TrackSort.title}) async =>
      const [];

  @override
  Stream<List<Track>> watchTracks({TrackSort sort = TrackSort.title}) =>
      const Stream.empty();

  @override
  Future<List<Track>> searchTracks(String query, {int limit = 100}) async =>
      const [];

  @override
  Future<int> upsertTrack(Track track) async => 0;

  @override
  Future<void> upsertTracks(List<Track> tracks) async {}

  @override
  Future<void> upsertScannedTracks(List<ScannedTrack> tracks) async {}

  @override
  Future<void> deleteTrack(int id) async {}

  @override
  Future<Track?> findByUri(String uri) async => null;

  @override
  Future<Set<String>> trackUrisForSource(String source) async => const {};

  @override
  Future<Map<String, FileFingerprint>> trackFingerprints(String source) async =>
      const {};

  @override
  Future<int> markMissingExcept(
    String source,
    Set<String> seenUris, {
    Set<String>? roots,
  }) async => 0;
}

/// [LibrarySyncService] stand-in whose [sync] is a no-op.
class _FakeLibrarySyncService extends LibrarySyncService {
  _FakeLibrarySyncService()
    : super(
        scanner: _FakeLocalLibraryScanner(),
        repository: _FakeMusicLibraryRepository(),
        artworkCache: ArtworkCache.lazy(
          resolveBaseDir: () async => Directory.systemTemp,
        ),
      );
}

/// [PermissionBackend] stand-in that grants everything without touching a
/// platform channel (the real backend would call `permission_handler`, which
/// is unavailable under `flutter test`).
class _GrantingPermissionBackend implements PermissionBackend {
  @override
  bool get requiresRuntimeRequest => false;

  @override
  Future<bool> isGranted(AppPermission permission) async => true;

  @override
  Future<bool> request(AppPermission permission) async => true;

  @override
  Future<bool> isPermanentlyDenied(AppPermission permission) async => false;
}

/// Minimal [LocalLibraryScanner] stub.
class _FakeLocalLibraryScanner extends LocalLibraryScanner {
  _FakeLocalLibraryScanner() : super(reader: LocalMetadataReader());
}

/// [FilePickerPlatform] stand-in that returns a fake directory path.
class _FakeFilePickerPlatform extends FilePickerPlatform {
  String? nextPath;

  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => const [];

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    String? initialDirectory,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => nextPath;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Pumps [SettingsScreen] with every provider overridden so no database,
/// download manager, platform channel, or network is ever constructed.
Widget _app({
  required _FakeSettingsRepository settings,
  required _FakeCacheStore store,
  int usageBytes = 0,
  int trackCount = 0,
  List<String> scanRoots = const [],
  List<Track> tracks = const [],
  LibrarySyncState syncState = LibrarySyncState.idle,
  PackageInfo? packageInfo,
}) {
  return ProviderScope(
    overrides: [
      settingsRepositoryProvider.overrideWith((ref) => settings),
      permissionServiceProvider.overrideWithValue(
        PermissionService(backend: _GrantingPermissionBackend()),
      ),
      audioCacheStoreProvider.overrideWith((ref) => store),
      audioCacheUsageProvider.overrideWith((ref) async => usageBytes),
      audioCacheEntryCountProvider.overrideWith((ref) async => trackCount),
      // Library
      libraryTracksProvider.overrideWith(
        (ref) => Stream<List<Track>>.value(tracks),
      ),
      scanRootsProvider.overrideWith((ref) async => scanRoots),
      musicLibraryRepositoryProvider.overrideWith(
        (ref) => _FakeMusicLibraryRepository(scanRoots),
      ),
      librarySyncServiceProvider.overrideWith(
        (ref) => _FakeLibrarySyncService(),
      ),
      librarySyncStateProvider.overrideWith(
        (ref) => Stream<LibrarySyncState>.value(syncState),
      ),
      // About
      packageInfoProvider.overrideWith(
        (ref) async =>
            packageInfo ??
            PackageInfo(
              appName: 'Flind Player',
              packageName: 'flind_player',
              version: '0.1.0',
              buildNumber: '1',
            ),
      ),
    ],
    child: const MaterialApp(home: SettingsScreen()),
  );
}

/// Builds a minimal [Track] with the given [title] and [path].
Track _track(String title, String path) => Track(
  source: 'local',
  sourceTrackId: LocalTrackId(path),
  uri: 'local:$path',
  title: title,
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _FakeFilePickerPlatform fakePicker;

  setUp(() {
    fakePicker = _FakeFilePickerPlatform();
    FilePickerPlatform.instance = fakePicker;
  });

  // -- Section headings --

  testWidgets('renders all three section headings', (tester) async {
    final settings = _FakeSettingsRepository(CacheSettings.defaults);
    final store = _FakeCacheStore();
    addTearDown(settings.dispose);

    await tester.pumpWidget(_app(settings: settings, store: store));
    await tester.pumpAndSettle();

    expect(find.text('播放'), findsOneWidget);
    expect(find.text('曲库'), findsOneWidget);

    // 关于 is off-screen; scroll to bring it into view.
    await tester.scrollUntilVisible(find.text('关于'), 100);
    await tester.pumpAndSettle();
    expect(find.text('关于'), findsOneWidget);
  });

  testWidgets('renders the AppBar title as 设置', (tester) async {
    final settings = _FakeSettingsRepository(CacheSettings.defaults);
    final store = _FakeCacheStore();
    addTearDown(settings.dispose);

    await tester.pumpWidget(_app(settings: settings, store: store));
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsOneWidget);
  });

  // -- 播放 section (existing tests, adapted) --

  testWidgets('renders the cache switches, chips and usage', (tester) async {
    final settings = _FakeSettingsRepository(CacheSettings.defaults);
    final store = _FakeCacheStore();
    addTearDown(settings.dispose);

    await tester.pumpWidget(
      _app(
        settings: settings,
        store: store,
        usageBytes: 300 * 1024 * 1024,
        trackCount: 3,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('启用缓存'), findsOneWidget);
    expect(find.text('播放时自动缓存'), findsOneWidget);
    expect(find.text('256 MB'), findsOneWidget);
    expect(find.text('512 MB'), findsOneWidget);
    expect(find.text('1 GB'), findsWidgets);
    expect(find.text('2 GB'), findsOneWidget);
    expect(find.text('5 GB'), findsOneWidget);
    expect(find.text('300 MB / 1 GB'), findsOneWidget);
    expect(find.text('已缓存 3 首'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('清空缓存'), findsOneWidget);
  });

  testWidgets('toggling 启用缓存 persists enabled: false', (tester) async {
    final settings = _FakeSettingsRepository(CacheSettings.defaults);
    final store = _FakeCacheStore();
    addTearDown(settings.dispose);

    await tester.pumpWidget(_app(settings: settings, store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('启用缓存'));
    await tester.pumpAndSettle();

    expect(settings.writes, isNotEmpty);
    expect(settings.current.enabled, isFalse);
    expect(settings.current.limitBytes, CacheSettings.defaults.limitBytes);
  });

  testWidgets('selecting a chip persists the new limit', (tester) async {
    final settings = _FakeSettingsRepository(CacheSettings.defaults);
    final store = _FakeCacheStore();
    addTearDown(settings.dispose);

    await tester.pumpWidget(_app(settings: settings, store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('256 MB'));
    await tester.pumpAndSettle();

    expect(settings.current.limitBytes, 256 * 1024 * 1024);
    expect(settings.current.enabled, isTrue);
  });

  testWidgets('清空缓存 asks for confirmation before clearing', (tester) async {
    final settings = _FakeSettingsRepository(CacheSettings.defaults);
    final store = _FakeCacheStore();
    addTearDown(settings.dispose);

    await tester.pumpWidget(
      _app(
        settings: settings,
        store: store,
        usageBytes: 300 * 1024 * 1024,
        trackCount: 3,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('清空缓存'));
    await tester.pumpAndSettle();

    expect(find.text('清空缓存？'), findsOneWidget);
    expect(store.clearCalls, 0);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(store.clearCalls, 0);
    expect(find.text('清空缓存？'), findsNothing);

    await tester.tap(find.text('清空缓存'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('清空'));
    await tester.pumpAndSettle();

    expect(store.clearCalls, 1);
    expect(find.textContaining('已清空缓存'), findsOneWidget);
    expect(find.textContaining('300 MB'), findsWidgets);
  });

  // -- 曲库 section --

  testWidgets('shows track count from libraryTracksProvider', (tester) async {
    final settings = _FakeSettingsRepository(CacheSettings.defaults);
    final store = _FakeCacheStore();
    addTearDown(settings.dispose);

    final tracks = [
      _track('Song A', '/a.mp3'),
      _track('Song B', '/b.mp3'),
      _track('Song C', '/c.mp3'),
    ];

    await tester.pumpWidget(
      _app(settings: settings, store: store, tracks: tracks),
    );
    await tester.pumpAndSettle();

    expect(find.text('曲库统计'), findsOneWidget);
    expect(find.textContaining('3 首曲目'), findsOneWidget);
  });

  testWidgets('shows cached-track count when > 0', (tester) async {
    final settings = _FakeSettingsRepository(CacheSettings.defaults);
    final store = _FakeCacheStore();
    addTearDown(settings.dispose);

    await tester.pumpWidget(
      _app(settings: settings, store: store, trackCount: 5),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('5 首已缓存'), findsOneWidget);
  });

  // -- Scan root management --

  testWidgets('renders scan root basenames and full paths', (tester) async {
    final settings = _FakeSettingsRepository(CacheSettings.defaults);
    final store = _FakeCacheStore();
    addTearDown(settings.dispose);

    await tester.pumpWidget(
      _app(
        settings: settings,
        store: store,
        scanRoots: ['/home/user/Music', '/mnt/usb/Songs'],
      ),
    );
    await tester.pumpAndSettle();

    // Basenames shown as titles.
    expect(find.text('Music'), findsOneWidget);
    expect(find.text('Songs'), findsOneWidget);
    // Full paths shown as subtitles.
    expect(find.text('/home/user/Music'), findsOneWidget);
    expect(find.text('/mnt/usb/Songs'), findsOneWidget);
  });

  testWidgets(
    'deleting a scan root asks for confirmation then calls removeScanRoot',
    (tester) async {
      final settings = _FakeSettingsRepository(CacheSettings.defaults);
      final store = _FakeCacheStore();
      addTearDown(settings.dispose);

      await tester.pumpWidget(
        _app(settings: settings, store: store, scanRoots: ['/home/user/Music']),
      );
      await tester.pumpAndSettle();

      // The delete icon for scan roots is inside the ListTile that shows
      // the root path. The cache section also has a delete icon, so use
      // a descendant-of-tile finder to disambiguate.
      final rootTile = find.byWidgetPredicate(
        (w) =>
            w is ListTile &&
            w.subtitle is Text &&
            (w.subtitle as Text?)?.data == '/home/user/Music',
      );
      final deleteIcon = find.descendant(
        of: rootTile,
        matching: find.byIcon(Icons.delete_outline),
      );

      // Scroll the tile into view before tapping.
      await tester.ensureVisible(rootTile);
      await tester.pumpAndSettle();

      // Tap the delete icon.
      await tester.tap(deleteIcon);
      await tester.pumpAndSettle();

      // Confirmation dialog.
      expect(find.text('删除扫描根目录？'), findsOneWidget);

      // Cancel first.
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.text('删除扫描根目录？'), findsNothing);

      // Now confirm.
      await tester.tap(deleteIcon);
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      // SnackBar confirming removal.
      expect(find.textContaining('已移除扫描根目录'), findsOneWidget);
    },
  );

  testWidgets('shows 未配置 when scan roots are empty', (tester) async {
    final settings = _FakeSettingsRepository(CacheSettings.defaults);
    final store = _FakeCacheStore();
    addTearDown(settings.dispose);

    await tester.pumpWidget(
      _app(settings: settings, store: store, scanRoots: []),
    );
    await tester.pumpAndSettle();

    expect(find.text('未配置扫描根目录'), findsOneWidget);
  });

  // -- 添加文件夹 --

  testWidgets('添加文件夹 calls the picker flow and adds root', (tester) async {
    final settings = _FakeSettingsRepository(CacheSettings.defaults);
    final store = _FakeCacheStore();
    addTearDown(settings.dispose);

    fakePicker.nextPath = '/new/music/folder';

    await tester.pumpWidget(
      _app(settings: settings, store: store, scanRoots: []),
    );
    await tester.pumpAndSettle();

    // Scroll to the 添加文件夹 tile which is in the 曲库 section.
    final addFolderTile = find.text('添加文件夹');
    await tester.ensureVisible(addFolderTile);
    await tester.pumpAndSettle();
    await tester.tap(addFolderTile);
    await tester.pumpAndSettle();

    expect(find.textContaining('已添加文件夹'), findsOneWidget);
  });

  testWidgets('添加文件夹 does nothing when picker is cancelled', (tester) async {
    final settings = _FakeSettingsRepository(CacheSettings.defaults);
    final store = _FakeCacheStore();
    addTearDown(settings.dispose);

    fakePicker.nextPath = null;

    await tester.pumpWidget(
      _app(settings: settings, store: store, scanRoots: []),
    );
    await tester.pumpAndSettle();

    final addFolderTile = find.text('添加文件夹');
    await tester.ensureVisible(addFolderTile);
    await tester.pumpAndSettle();
    await tester.tap(addFolderTile);
    await tester.pumpAndSettle();

    expect(find.textContaining('已添加文件夹'), findsNothing);
  });

  // -- 重新扫描 --

  testWidgets('重新扫描 is enabled when idle', (tester) async {
    final settings = _FakeSettingsRepository(CacheSettings.defaults);
    final store = _FakeCacheStore();
    addTearDown(settings.dispose);

    await tester.pumpWidget(
      _app(settings: settings, store: store, syncState: LibrarySyncState.idle),
    );
    await tester.pumpAndSettle();

    final tile = tester.widget<ListTile>(find.byKey(const Key('rescan')));
    expect(tile.onTap, isNotNull);
  });

  testWidgets('重新扫描 is disabled while a sync is running', (tester) async {
    final settings = _FakeSettingsRepository(CacheSettings.defaults);
    final store = _FakeCacheStore();
    addTearDown(settings.dispose);

    await tester.pumpWidget(
      _app(
        settings: settings,
        store: store,
        syncState: const LibrarySyncState(
          phase: LibrarySyncPhase.scanning,
          discovered: 10,
          processed: 3,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tile = tester.widget<ListTile>(find.byKey(const Key('rescan')));
    expect(tile.onTap, isNull);
  });

  testWidgets('重新扫描 shows sync progress while scanning', (tester) async {
    final settings = _FakeSettingsRepository(CacheSettings.defaults);
    final store = _FakeCacheStore();
    addTearDown(settings.dispose);

    await tester.pumpWidget(
      _app(
        settings: settings,
        store: store,
        syncState: const LibrarySyncState(
          phase: LibrarySyncPhase.scanning,
          discovered: 10,
          processed: 3,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('扫描中 3/10'), findsOneWidget);
  });

  // -- 关于 section --

  testWidgets('renders version string from packageInfoProvider', (
    tester,
  ) async {
    final settings = _FakeSettingsRepository(CacheSettings.defaults);
    final store = _FakeCacheStore();
    addTearDown(settings.dispose);

    await tester.pumpWidget(
      _app(
        settings: settings,
        store: store,
        packageInfo: PackageInfo(
          appName: 'Flind Player',
          packageName: 'flind_player',
          version: '1.2.3',
          buildNumber: '42',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Scroll to the about section — the ListView lazily builds the Column
    // so the version text only appears once the about section is scrolled in.
    await tester.scrollUntilVisible(find.text('v1.2.3 (42)'), 100);
    await tester.pumpAndSettle();

    expect(find.text('Flind Player'), findsWidgets);
    expect(find.text('v1.2.3 (42)'), findsOneWidget);
  });

  testWidgets('renders 开源许可 tile', (tester) async {
    final settings = _FakeSettingsRepository(CacheSettings.defaults);
    final store = _FakeCacheStore();
    addTearDown(settings.dispose);

    await tester.pumpWidget(_app(settings: settings, store: store));
    await tester.pumpAndSettle();

    // Scroll to the about section.
    await tester.scrollUntilVisible(find.text('开源许可'), 100);
    await tester.pumpAndSettle();

    expect(find.text('开源许可'), findsOneWidget);
    expect(find.text('GNU General Public License v3.0'), findsOneWidget);
  });

  testWidgets('tapping 开源许可 opens the Flutter license page', (tester) async {
    final settings = _FakeSettingsRepository(CacheSettings.defaults);
    final store = _FakeCacheStore();
    addTearDown(settings.dispose);

    await tester.pumpWidget(_app(settings: settings, store: store));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('开源许可'), 100);
    await tester.pumpAndSettle();
    await tester.tap(find.text('开源许可'));
    await tester.pumpAndSettle();

    // Flutter's built-in license page renders a license list.
    expect(find.byType(LicensePage), findsOneWidget);
  });

  testWidgets('renders project homepage URL', (tester) async {
    final settings = _FakeSettingsRepository(CacheSettings.defaults);
    final store = _FakeCacheStore();
    addTearDown(settings.dispose);

    await tester.pumpWidget(_app(settings: settings, store: store));
    await tester.pumpAndSettle();

    // Scroll to the about section.
    await tester.scrollUntilVisible(find.text('项目主页'), 100);
    await tester.pumpAndSettle();

    expect(find.text('项目主页'), findsOneWidget);
    expect(
      find.text('https://github.com/Q-wind520/flind-player'),
      findsOneWidget,
    );
  });

  testWidgets('renders GPL-3.0 notice', (tester) async {
    final settings = _FakeSettingsRepository(CacheSettings.defaults);
    final store = _FakeCacheStore();
    addTearDown(settings.dispose);

    await tester.pumpWidget(_app(settings: settings, store: store));
    await tester.pumpAndSettle();

    // Scroll to the very bottom of the list.
    await tester.scrollUntilVisible(find.textContaining('GPL-3.0'), 100);
    await tester.pumpAndSettle();

    expect(find.textContaining('基于 GPL-3.0 许可证的自由软件'), findsOneWidget);
  });
}
