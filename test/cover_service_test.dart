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

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/models/track_sort.dart';
import 'package:flind_player/core/repositories/music_library_repository.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/cache/audio_cache_store.dart';
import 'package:flind_player/data/cache/cover_cache_store.dart';
import 'package:flind_player/data/cache/cover_downloader.dart';
import 'package:flind_player/data/database/app_database.dart';
import 'package:flind_player/data/services/cover_service.dart';
import 'package:flind_player/data/sources/local/local_library_scanner.dart';

import 'audio_cache_store_test.dart' show FakeSettingsRepository;

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

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
  Future<int> promoteTrack(Track track) async => 0;

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

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// A small but real JPEG the service's decode-validation accepts.
Uint8List _jpegBytes() {
  final image = img.Image(width: 8, height: 8);
  img.fill(image, color: img.ColorRgb8(30, 120, 200));
  return Uint8List.fromList(img.encodeJpg(image));
}

/// A Bilibili [Track], optionally carrying a raw (un-normalised) cover URL or
/// an already-known local cover path.
Track _biliTrack({String? coverUrl, String? coverPath}) => Track(
  source: 'bilibili',
  sourceTrackId: const BiliTrackId(bvid: 'BV1GJ411x7h7', cid: 137649199),
  uri: 'bilibili:BV1GJ411x7h7:137649199',
  title: 'Online Track',
  artist: 'Uploader',
  coverUrl: coverUrl,
  coverPath: coverPath,
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
  late FakeSettingsRepository settings;
  late AudioCacheStore audio;
  late _FakeCoverDownloader downloader;
  late _FakeMusicLibraryRepository library;
  late List<String> resolvedBvids;
  late CoverService service;

  setUp(() {
    root = Directory.systemTemp.createTempSync('flind_cover_service');
    db = AppDatabase(NativeDatabase.memory());
    settings = FakeSettingsRepository();
    audio = AudioCacheStore(database: db, baseDir: root, settings: settings);
    downloader = _FakeCoverDownloader(_jpegBytes());
    library = _FakeMusicLibraryRepository();
    resolvedBvids = <String>[];
    service = CoverService(
      store: CoverCacheStore(database: db, baseDir: root),
      audioStore: audio,
      downloader: downloader,
      library: library,
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

  /// Indexes the Bilibili fixture song in the audio cache (layer 1), as a
  /// completed pin/download would.
  Future<void> addCachedSong() async {
    final audioFile = audio.fileFor(
      source: 'bilibili',
      sourceTrackId: 'BV1GJ411x7h7:137649199',
      extension: 'm4a',
    );
    audioFile.parent.createSync(recursive: true);
    audioFile.writeAsBytesSync(const [1, 2, 3]);
    await audio.insert(
      source: 'bilibili',
      sourceTrackId: 'BV1GJ411x7h7:137649199',
      filePath: audioFile.path,
      bytes: 3,
      qualityId: '30280',
      pinned: true,
    );
  }

  test(
    'downloads, stores under the base dir, and writes back path + URL',
    () async {
      final track = _biliTrack(coverUrl: '//i0.hdslb.com/bfs/a.jpg');

      final path = await service.ensureCover(track);

      expect(path, isNotNull);
      expect(File(path!).existsSync(), isTrue);
      expect(path, startsWith(root.path));
      expect(File(path).readAsBytesSync(), downloader.bytes);
      expect(downloader.requestedUrls, const <String>[
        'https://i0.hdslb.com/bfs/a.jpg',
      ]);

      expect(library.coverWrites, hasLength(1));
      expect(library.coverWrites.single.uri, track.uri);
      expect(library.coverWrites.single.coverPath, path);
      expect(
        library.coverWrites.single.coverUrl,
        'https://i0.hdslb.com/bfs/a.jpg',
      );
    },
  );

  test('serves a URL cache hit without downloading again', () async {
    final track = _biliTrack(coverUrl: 'https://i0.hdslb.com/bfs/a.jpg');

    final first = await service.ensureCover(track);
    final second = await service.ensureCover(track);

    expect(second, first);
    expect(downloader.requestedUrls, hasLength(1));
  });

  test(
    'resolves a BiliTrackId cover URL when the track carries none',
    () async {
      final track = _biliTrack();

      final path = await service.ensureCover(track);

      expect(resolvedBvids, const <String>['BV1GJ411x7h7']);
      expect(downloader.requestedUrls, const <String>[
        'https://i0.hdslb.com/bfs/resolved.jpg',
      ]);
      expect(path, isNotNull);
      expect(File(path!).existsSync(), isTrue);
    },
  );

  test('returns null and persists nothing when the download fails', () async {
    downloader.returnNull = true;
    final track = _biliTrack(coverUrl: '//i0.hdslb.com/bfs/a.jpg');

    final path = await service.ensureCover(track);

    expect(path, isNull);
    expect(library.coverWrites, isEmpty);
  });

  test('rejects a non-decodable payload without storing anything', () async {
    final bad = _FakeCoverDownloader(
      Uint8List.fromList(utf8.encode('<html>not an image</html>')),
    );
    final service = CoverService(
      store: CoverCacheStore(database: db, baseDir: root),
      audioStore: audio,
      downloader: bad,
      library: library,
      resolveRemoteUrl: (bvid) async => '//i0.hdslb.com/bfs/resolved.jpg',
    );
    final track = _biliTrack(coverUrl: '//i0.hdslb.com/bfs/a.jpg');

    final path = await service.ensureCover(track);

    expect(path, isNull);
    expect(library.coverWrites, isEmpty);
    expect(root.listSync().whereType<File>(), isEmpty);
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
  });

  test('stores a cover in layer 1 when the song is already cached', () async {
    await addCachedSong();

    final path = await service.ensureCover(
      _biliTrack(coverUrl: '//i0.hdslb.com/bfs/a.jpg'),
    );

    expect(path, isNotNull);
    expect(
      (await audio.lookup('bilibili', 'BV1GJ411x7h7:137649199'))!.coverPath,
      path,
    );
    // The companion cover lives beside the audio file and its bytes count
    // toward the layer-1 quota (audio: 3 + cover: jpeg size).
    expect(await audio.totalBytes(), 3 + downloader.bytes.length);
  });

  test(
    'copies a layer-2 cover into layer 1 once the song is cached',
    () async {
      // The cover is fetched into layer 2 first (prefetch on enqueue, song
      // not cached yet) ...
      final layer2Path = await service.ensureCover(
        _biliTrack(coverUrl: '//i0.hdslb.com/bfs/a.jpg'),
      );
      expect(layer2Path, isNotNull);
      expect(downloader.requestedUrls, hasLength(1));

      // ... then the song gets pinned/downloaded.
      await addCachedSong();

      // A fresh track instance without coverPath, as the download flow sees it.
      final path = await service.ensureCover(
        _biliTrack(coverUrl: '//i0.hdslb.com/bfs/a.jpg'),
      );

      expect(
        path,
        audio
            .coverFileFor(
              source: 'bilibili',
              sourceTrackId: 'BV1GJ411x7h7:137649199',
              extension: 'jpg',
            )
            .path,
      );
      expect(File(path!).existsSync(), isTrue);
      expect(
        (await audio.lookup('bilibili', 'BV1GJ411x7h7:137649199'))!.coverPath,
        path,
      );
      // The layer-2 bytes were reused: no second download.
      expect(downloader.requestedUrls, hasLength(1));
    },
  );

  test(
    'copies an existing track cover into layer 1 once the song is cached',
    () async {
      await addCachedSong();
      // A cover the library row already points at (e.g. fetched into layer 2
      // before the song was pinned).
      final existing = File('${root.path}/prefetched.jpg')
        ..writeAsBytesSync(_jpegBytes());

      final path = await service.ensureCover(
        _biliTrack(
          coverUrl: '//i0.hdslb.com/bfs/a.jpg',
          coverPath: existing.path,
        ),
      );

      expect(
        path,
        audio
            .coverFileFor(
              source: 'bilibili',
              sourceTrackId: 'BV1GJ411x7h7:137649199',
              extension: 'jpg',
            )
            .path,
      );
      expect(File(path!).existsSync(), isTrue);
      expect(
        (await audio.lookup('bilibili', 'BV1GJ411x7h7:137649199'))!.coverPath,
        path,
      );
      expect(File(path).readAsBytesSync(), _jpegBytes());
      expect(downloader.requestedUrls, isEmpty);
    },
  );
}
