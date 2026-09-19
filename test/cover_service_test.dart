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

import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:flind_player/core/models/app_language.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/models/track_sort.dart';
import 'package:flind_player/core/repositories/favorites_repository.dart';
import 'package:flind_player/core/repositories/music_library_repository.dart';
import 'package:flind_player/core/repositories/settings_repository.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/cache/cover_cache_store.dart';
import 'package:flind_player/data/cache/cover_downloader.dart';
import 'package:flind_player/data/database/app_database.dart';
import 'package:flind_player/data/services/cover_service.dart';
import 'package:flind_player/data/sources/local/local_library_scanner.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// In-memory [SettingsRepository] with the default cache quota.
class _FakeSettingsRepository implements SettingsRepository {
  @override
  Future<AppLanguage> appLanguage() async => AppLanguage.system;

  @override
  Future<void> setAppLanguage(AppLanguage language) async {}

  CacheSettings current = CacheSettings.defaults;

  @override
  Future<CacheSettings> cacheSettings() async => current;

  @override
  Future<void> updateCacheSettings(CacheSettings settings) async {
    current = settings;
  }

  @override
  Stream<CacheSettings> watchCacheSettings() =>
      const Stream<CacheSettings>.empty();

  @override
  Future<TrackSort> librarySort() async => TrackSort.title;

  @override
  Future<void> setLibrarySort(TrackSort sort) async {}
}

/// [CoverDownloader] stand-in that returns canned image bytes and records each
/// requested URL. Set [returnNull] to simulate a failed fetch.
class _FakeCoverDownloader extends CoverDownloader {
  _FakeCoverDownloader(this.bytes);

  final Uint8List bytes;
  final List<String> requestedUrls = <String>[];
  bool returnNull = false;

  @override
  Future<Uint8List?> download(String url) async {
    requestedUrls.add(url);
    if (returnNull) return null;
    return bytes;
  }
}

/// A recorded cover write-back.
typedef _CoverWrite = ({String uri, String? coverPath, String? coverUrl});

/// Minimal [MusicLibraryRepository] that records cover write-backs.
class _FakeMusicLibraryRepository implements MusicLibraryRepository {
  final List<_CoverWrite> coverWrites = <_CoverWrite>[];

  @override
  Future<void> updateTrackCover(
    String uri, {
    String? coverPath,
    String? coverUrl,
  }) async {
    coverWrites.add((uri: uri, coverPath: coverPath, coverUrl: coverUrl));
  }

  // -- Stubs for methods not exercised by the cover service --

  @override
  Future<List<Track>> allTracks({TrackSort sort = TrackSort.title}) async =>
      const <Track>[];

  @override
  Stream<List<Track>> watchTracks({TrackSort sort = TrackSort.title}) =>
      const Stream<List<Track>>.empty();

  @override
  Future<List<Track>> searchTracks(String query, {int limit = 100}) async =>
      const <Track>[];

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
  Future<Set<String>> trackUrisForSource(String source) async =>
      const <String>{};

  @override
  Future<Map<String, FileFingerprint>> trackFingerprints(String source) async =>
      const <String, FileFingerprint>{};

  @override
  Future<int> markMissingExcept(
    String source,
    Set<String> seenUris, {
    Set<String>? roots,
  }) async => 0;

  @override
  Future<List<String>> scanRoots() async => const <String>[];

  @override
  Future<void> addScanRoot(String path) async {}

  @override
  Future<void> removeScanRoot(String path) async {}
}

/// Minimal [FavoritesRepository] that records cover write-backs.
class _FakeFavoritesRepository implements FavoritesRepository {
  final List<_CoverWrite> coverWrites = <_CoverWrite>[];

  @override
  Future<void> updateFavoriteCover(
    String uri, {
    String? coverPath,
    String? coverUrl,
  }) async {
    coverWrites.add((uri: uri, coverPath: coverPath, coverUrl: coverUrl));
  }

  // -- Stubs for methods not exercised by the cover service --

  @override
  Stream<List<Track>> watchFavorites() => const Stream<List<Track>>.empty();

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

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// A small but real JPEG the service's [encodeCoverJpeg] pipeline can decode.
Uint8List _jpegBytes() {
  final image = img.Image(width: 8, height: 8);
  img.fill(image, color: img.ColorRgb8(30, 120, 200));
  return Uint8List.fromList(img.encodeJpg(image));
}

/// A Bilibili [Track], optionally carrying a raw (un-normalised) cover URL.
Track _biliTrack({String? coverUrl}) => Track(
  source: 'bilibili',
  sourceTrackId: const BiliTrackId(bvid: 'BV1GJ411x7h7', cid: 137649199),
  uri: 'bilibili:BV1GJ411x7h7:137649199',
  title: 'Online Track',
  artist: 'Uploader',
  coverUrl: coverUrl,
);

/// A local [Track] pointing at [coverPath].
Track _localTrack({required String coverPath}) => Track(
  source: 'local',
  sourceTrackId: const LocalTrackId('/music/song.flac'),
  uri: 'local:/music/song.flac',
  title: 'Local Track',
  coverPath: coverPath,
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late Directory root;
  late AppDatabase db;
  late _FakeCoverDownloader downloader;
  late _FakeMusicLibraryRepository library;
  late _FakeFavoritesRepository favorites;
  late List<String> resolvedBvids;
  late CoverService service;

  setUp(() {
    root = Directory.systemTemp.createTempSync('flind_cover_service');
    db = AppDatabase(NativeDatabase.memory());
    downloader = _FakeCoverDownloader(_jpegBytes());
    library = _FakeMusicLibraryRepository();
    favorites = _FakeFavoritesRepository();
    resolvedBvids = <String>[];
    service = CoverService(
      store: CoverCacheStore(
        database: db,
        settings: _FakeSettingsRepository(),
        baseDir: root,
      ),
      downloader: downloader,
      library: library,
      favorites: favorites,
      resolveRemoteUrl: (bvid) async {
        resolvedBvids.add(bvid);
        return '//i0.hdslb.com/bfs/resolved.jpg';
      },
    );
  });

  tearDown(() async {
    await db.close();
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  test('downloads, stores under the base dir, and writes back path + URL', () async {
    final track = _biliTrack(coverUrl: '//i0.hdslb.com/bfs/a.jpg');

    final path = await service.ensureCover(track);

    expect(path, isNotNull);
    expect(File(path!).existsSync(), isTrue);
    expect(path, startsWith(root.path));
    expect(
      downloader.requestedUrls,
      const <String>['https://i0.hdslb.com/bfs/a.jpg'],
    );

    expect(library.coverWrites, hasLength(1));
    expect(library.coverWrites.single.uri, track.uri);
    expect(library.coverWrites.single.coverPath, path);
    expect(library.coverWrites.single.coverUrl, 'https://i0.hdslb.com/bfs/a.jpg');

    expect(favorites.coverWrites, hasLength(1));
    expect(favorites.coverWrites.single.uri, track.uri);
    expect(favorites.coverWrites.single.coverPath, path);
    expect(
      favorites.coverWrites.single.coverUrl,
      'https://i0.hdslb.com/bfs/a.jpg',
    );
  });

  test('serves a URL cache hit without downloading again', () async {
    final track = _biliTrack(coverUrl: 'https://i0.hdslb.com/bfs/a.jpg');

    final first = await service.ensureCover(track);
    final second = await service.ensureCover(track);

    expect(second, first);
    expect(downloader.requestedUrls, hasLength(1));
  });

  test('resolves a BiliTrackId cover URL when the track carries none', () async {
    final track = _biliTrack();

    final path = await service.ensureCover(track);

    expect(resolvedBvids, const <String>['BV1GJ411x7h7']);
    expect(
      downloader.requestedUrls,
      const <String>['https://i0.hdslb.com/bfs/resolved.jpg'],
    );
    expect(path, isNotNull);
    expect(File(path!).existsSync(), isTrue);
  });

  test('returns null and persists nothing when the download fails', () async {
    downloader.returnNull = true;
    final track = _biliTrack(coverUrl: '//i0.hdslb.com/bfs/a.jpg');

    final path = await service.ensureCover(track);

    expect(path, isNull);
    expect(library.coverWrites, isEmpty);
    expect(favorites.coverWrites, isEmpty);
  });

  test('force bypasses the cache and downloads again', () async {
    final track = _biliTrack(coverUrl: '//i0.hdslb.com/bfs/a.jpg');

    final first = await service.ensureCover(track);
    final forced = await service.ensureCover(track, force: true);

    expect(first, isNotNull);
    expect(forced, isNotNull);
    expect(downloader.requestedUrls, hasLength(2));
  });

  test('returns an existing local cover without downloading', () async {
    final coverFile = File('${root.path}/local-cover.jpg')
      ..writeAsBytesSync(_jpegBytes());
    final track = _localTrack(coverPath: coverFile.path);

    final path = await service.ensureCover(track);

    expect(path, coverFile.path);
    expect(downloader.requestedUrls, isEmpty);
    expect(library.coverWrites, isEmpty);
    expect(favorites.coverWrites, isEmpty);
  });
}
