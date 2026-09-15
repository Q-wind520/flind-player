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
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/models/track_sort.dart';
import 'package:flind_player/core/repositories/favorites_repository.dart';
import 'package:flind_player/core/repositories/settings_repository.dart';
import 'package:flind_player/core/services/playback_controller.dart';
import 'package:flind_player/core/sources/remote_playlist.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/cache/audio_cache_store.dart';
import 'package:flind_player/data/cache/download_manager.dart';
import 'package:flind_player/data/providers/bilibili_providers.dart';
import 'package:flind_player/data/providers/cache_providers.dart';
import 'package:flind_player/data/providers/library_providers.dart';
import 'package:flind_player/data/providers/persistence_providers.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/data/services/library_sync_service.dart';
import 'package:flind_player/features/home/home_shell.dart';
import 'package:flind_player/features/library/library_screen.dart';
import 'package:flind_player/features/library/library_sort_provider.dart';
import 'package:flind_player/features/library/widgets/cache_action_button.dart';
import 'package:flind_player/features/player/player_screen.dart';
import 'package:flind_player/features/playlists/bilibili_favorites_screen.dart';
import 'package:flind_player/features/search/search_providers.dart';
import 'package:flind_player/features/search/search_screen.dart';
import 'package:flind_player/features/settings/settings_providers.dart';
import 'package:flind_player/features/settings/settings_screen.dart';
import 'package:flind_player/core/models/app_language.dart';

import 'support/l10n.dart';

// ---------------------------------------------------------------------------
// Size matrix
// ---------------------------------------------------------------------------

/// Logical-pixel viewport sizes exercised by every surface.
///
/// The set deliberately crosses the `AppBreakpoints.isCompact` rule in both
/// directions: narrow portrait phones, short landscape phones, the exact
/// `600` px compact boundary, the exact `1000` px expanded boundary, an
/// ultra-tall portrait desktop window, and a large landscape desktop window.
const List<Size> _kSizes = <Size>[
  Size(320, 480),
  Size(360, 640),
  Size(400, 800),
  Size(480, 320),
  Size(600, 400),
  Size(800, 600),
  Size(800, 1000),
  Size(1200, 800),
  Size(1600, 900),
];

// ---------------------------------------------------------------------------
// Sample data
// ---------------------------------------------------------------------------

Track _localTrack(String title, {String? artist, Duration? duration}) {
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

/// Tracks with deliberately long CJK titles/artists to stress ellipsis and
/// trailing-action layout at 320 px.
final List<Track> _kTracks = <Track>[
  _localTrack(
    '一个非常非常长的本地歌曲标题用来验证窄屏下的省略号截断行为',
    artist: '一个同样非常长的艺术家名称',
    duration: const Duration(minutes: 12, seconds: 34),
  ),
  _biliTrack(
    '另一个很长的在线歌曲标题同样需要被截断',
    artist: '一个很长的UP主名称',
    duration: const Duration(seconds: 65),
  ),
];

PlaybackState _playingState([Track? track]) => PlaybackState(
  isPlaying: true,
  isBuffering: false,
  isCompleted: false,
  position: const Duration(seconds: 30),
  duration: const Duration(minutes: 3),
  currentTrack: track ?? _localTrack('正在播放的长标题歌曲用来压力测试播放器布局', artist: '测试艺术家'),
);

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeSettingsRepository implements SettingsRepository {
  @override
  Future<AppLanguage> appLanguage() async => AppLanguage.system;

  @override
  Future<void> setAppLanguage(AppLanguage language) async {}

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
  Future<bool> toggleFavorite(Track track) async => false;
}

/// Records queue calls so tapping a row never constructs the real controller.
class _FakePlaybackController implements PlaybackController {
  @override
  Future<void> playQueue(
    PlaybackQueue queue, {
    int index = 0,
    bool autoPlay = true,
  }) async {}

  @override
  Stream<PlaybackState> get state => const Stream.empty();

  @override
  PlaybackState get currentState => PlaybackState.idle;

  @override
  PlaybackQueue get queue => PlaybackQueue.empty;

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

/// Remote playlist source returning one long-titled folder full of tracks.
class _FakeRemotePlaylistSource implements RemotePlaylistSource {
  @override
  String get id => 'bilibili';

  @override
  Future<List<RemotePlaylist>> playlistsForUser(String userId) async =>
      <RemotePlaylist>[
        const RemotePlaylist(
          id: '1',
          title: '一个非常非常长的收藏夹标题用来验证窄屏下的省略号截断行为',
          trackCount: 12345,
        ),
      ];

  @override
  Future<RemoteTrackPage> playlistTracks(
    String playlistId, {
    int page = 1,
  }) async => RemoteTrackPage(
    tracks: _kTracks,
    page: page,
    hasMore: false,
    totalCount: _kTracks.length,
  );
}

/// Fake [LibrarySortNotifier] that returns a fixed value immediately.
class _FakeLibrarySortNotifier extends LibrarySortNotifier {
  _FakeLibrarySortNotifier(this._sort);

  final TrackSort _sort;

  @override
  Future<TrackSort> build() async => _sort;
}

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

/// Pumps [home] with every provider overridden so no database, network,
/// platform channel, real audio controller or sync service is constructed.
Widget _app({
  required Widget home,
  List<Track> tracks = const <Track>[],
  PlaybackState? playback,
  RemotePlaylistSource? remoteSource,
}) {
  _installErrorCapture();
  final settings = _FakeSettingsRepository(CacheSettings.defaults);
  final store = _FakeCacheStore();
  final favorites = _FakeFavoritesRepository();
  final playbackState = playback ?? PlaybackState.idle;

  return ProviderScope(
    overrides: [
      // Playback.
      playbackStateProvider.overrideWith((ref) => Stream.value(playbackState)),
      playbackControllerProvider.overrideWith(
        (ref) => _FakePlaybackController(),
      ),
      // Library.
      libraryTracksProvider.overrideWith((ref) => Stream.value(tracks)),
      librarySortProvider.overrideWith(
        () => _FakeLibrarySortNotifier(TrackSort.title),
      ),
      librarySearchProvider.overrideWith((ref, query) async => tracks),
      librarySyncStateProvider.overrideWith(
        (ref) => Stream.value(LibrarySyncState.idle),
      ),
      scanRootsProvider.overrideWith((ref) async => <String>[]),
      // Cache.
      downloadProgressProvider.overrideWith(
        (ref) => const Stream<DownloadProgress>.empty(),
      ),
      audioCacheEntryProvider.overrideWith((ref, track) async => null),
      audioCacheStoreProvider.overrideWith((ref) => store),
      audioCacheUsageProvider.overrideWith((ref) async => 0),
      audioCacheEntryCountProvider.overrideWith((ref) async => 0),
      settingsRepositoryProvider.overrideWith((ref) => settings),
      // Favourites.
      favoritesRepositoryProvider.overrideWithValue(favorites),
      favoritesProvider.overrideWith((ref) => Stream.value(const <Track>[])),
      // Search.
      biliSearchResultsProvider.overrideWith((ref, query) async => tracks),
      // Remote playlists.
      remotePlaylistSourceProvider.overrideWithValue(
        remoteSource ?? _FakeRemotePlaylistSource(),
      ),
      // About.
      packageInfoProvider.overrideWith(
        (ref) async => PackageInfo(
          appName: 'Flind Player',
          packageName: 'flind_player',
          version: '0.1.0',
          buildNumber: '1',
        ),
      ),
    ],
    child: localizedApp(home),
  );
}

/// Applies [size] and reports a layout overflow as a test failure.
Future<void> _pumpAt(WidgetTester tester, Size size, Widget app) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
  _reportOverflow(
    tester.takeException(),
    'layout overflow at ${size.width}x${size.height}',
  );
}

/// Asserts no layout overflow is pending after an interaction.
void _expectNoOverflow(WidgetTester tester, String label) {
  _reportOverflow(tester.takeException(), 'layout overflow: $label');
}

/// Raw framework errors captured during the current test.
///
/// `tester.takeException()` only returns the bare exception, which loses the
/// "relevant error-causing widget" diagnostics. Tapping [FlutterError.onError]
/// keeps the full [FlutterErrorDetails] so an overflow failure names the exact
/// widget and source line instead of just a pixel count.
List<FlutterErrorDetails> _capturedErrors = <FlutterErrorDetails>[];
void Function(FlutterErrorDetails)? _previousOnError;
bool _captureInstalled = false;

/// Installs the error capture lazily from inside the test body.
///
/// `TestWidgetsFlutterBinding.runTest` re-installs its own `onError` after
/// `setUp` runs, so the capture must be installed from within the body (which
/// [_app] is always called from).
void _installErrorCapture() {
  if (_captureInstalled) {
    return;
  }
  _captureInstalled = true;
  _previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    _capturedErrors.add(details);
    FlutterError.dumpErrorToConsole(details);
    _previousOnError?.call(details);
  };
}

/// Fails with the full framework diagnostics (widget + pixel count) when
/// [exception] is non-null.
void _reportOverflow(Object? exception, String label) {
  if (exception == null) {
    return;
  }
  final details = _capturedErrors.map((d) => d.toString()).join('\n');
  fail('$label:\n$exception\n$details');
}

void main() {
  setUp(() {
    _capturedErrors = <FlutterErrorDetails>[];
    _previousOnError = null;
    _captureInstalled = false;
  });

  tearDown(() {
    final previous = _previousOnError;
    if (previous != null) {
      FlutterError.onError = previous;
    }
  });

  group('HomeShell', () {
    for (final size in _kSizes) {
      testWidgets('no overflow at ${size.width}x${size.height}', (
        tester,
      ) async {
        await _pumpAt(
          tester,
          size,
          _app(
            home: const HomeShell(),
            tracks: _kTracks,
            playback: _playingState(),
          ),
        );
      });
    }
  });

  group('SettingsScreen', () {
    for (final size in _kSizes) {
      testWidgets('no overflow at ${size.width}x${size.height}', (
        tester,
      ) async {
        await _pumpAt(tester, size, _app(home: const SettingsScreen()));
      });
    }

    // Dialogs are the tallest thing the screen can show, so exercise them at
    // the smallest portrait and landscape viewports.
    for (final size in <Size>[const Size(320, 480), const Size(480, 320)]) {
      testWidgets(
        'cache dialogs have no overflow at ${size.width}x${size.height}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(_app(home: const SettingsScreen()));
          await tester.pumpAndSettle();

          // Cache-location dialog.
          await tester.tap(find.text('缓存位置'));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          _expectNoOverflow(tester, 'cache-location dialog');
          await tester.tap(find.text('关闭'));
          await tester.pumpAndSettle();

          // Custom-limit dialog.
          await tester.tap(find.text('缓存上限'));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          _expectNoOverflow(tester, 'custom-limit dialog');
        },
      );
    }
  });

  group('LibraryScreen', () {
    for (final size in _kSizes) {
      testWidgets('populated at ${size.width}x${size.height}', (tester) async {
        await _pumpAt(
          tester,
          size,
          _app(home: const LibraryScreen(), tracks: _kTracks),
        );
      });
    }

    // Empty state carries two stacked buttons and is the tallest body layout.
    for (final size in <Size>[
      const Size(320, 480),
      const Size(480, 320),
      const Size(800, 1000),
    ]) {
      testWidgets('empty at ${size.width}x${size.height}', (tester) async {
        await _pumpAt(tester, size, _app(home: const LibraryScreen()));
      });
    }
  });

  group('SearchScreen', () {
    for (final size in _kSizes) {
      testWidgets('hint at ${size.width}x${size.height}', (tester) async {
        await _pumpAt(tester, size, _app(home: const SearchScreen()));
      });
    }

    for (final size in <Size>[
      const Size(320, 480),
      const Size(480, 320),
      const Size(800, 1000),
    ]) {
      testWidgets('results at ${size.width}x${size.height}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _app(home: const SearchScreen(), tracks: _kTracks),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), '周杰伦');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        _expectNoOverflow(tester, 'SearchScreen results');
      });
    }
  });

  group('PlayerScreen', () {
    for (final size in _kSizes) {
      testWidgets('playing at ${size.width}x${size.height}', (tester) async {
        await _pumpAt(
          tester,
          size,
          _app(home: const PlayerScreen(), playback: _playingState()),
        );
      });

      testWidgets('idle at ${size.width}x${size.height}', (tester) async {
        await _pumpAt(tester, size, _app(home: const PlayerScreen()));
      });
    }
  });

  group('BilibiliFavoritesScreen', () {
    for (final size in _kSizes) {
      testWidgets('hint at ${size.width}x${size.height}', (tester) async {
        await _pumpAt(
          tester,
          size,
          _app(home: const BilibiliFavoritesScreen()),
        );
      });
    }

    for (final size in <Size>[
      const Size(320, 480),
      const Size(480, 320),
      const Size(800, 1000),
    ]) {
      testWidgets('folder and tracks at ${size.width}x${size.height}', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_app(home: const BilibiliFavoritesScreen()));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), '17340771');
        await tester.tap(find.text('加载'));
        await tester.pumpAndSettle();
        _expectNoOverflow(tester, 'Bilibili folder list');

        await tester.tap(find.text('一个非常非常长的收藏夹标题用来验证窄屏下的省略号截断行为'));
        await tester.pumpAndSettle();
        _expectNoOverflow(tester, 'Bilibili track list');
      });
    }
  });
}
