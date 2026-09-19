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

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/app_language.dart';
import 'package:flind_player/core/models/track_sort.dart';
import 'package:flind_player/core/repositories/settings_repository.dart';
import 'package:flind_player/data/cache/audio_cache_store.dart';
import 'package:flind_player/data/cache/cover_cache_store.dart';
import 'package:flind_player/data/database/app_database.dart';

/// In-memory [SettingsRepository] whose value the test can mutate.
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

void main() {
  late Directory root;
  late AppDatabase db;
  late _FakeSettingsRepository settings;
  late CoverCacheStore store;

  setUp(() {
    root = Directory.systemTemp.createTempSync('flind_cover_cache');
    db = AppDatabase(NativeDatabase.memory());
    settings = _FakeSettingsRepository();
    store = CoverCacheStore(database: db, baseDir: root, settings: settings);
  });

  tearDown(() async {
    await db.close();
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  /// Inserts a cover whose bytes are [bytes] long and returns its file path.
  Future<String> addCover(
    String urlHash,
    String contentHash, {
    int bytes = 100,
    int? lastAccessedAt,
  }) async {
    final path = await store.insert(
      urlHash: urlHash,
      contentHash: contentHash,
      bytes: Uint8List.fromList(List<int>.filled(bytes, contentHash.length)),
    );
    if (lastAccessedAt != null) {
      await (db.update(db.coverCache)..where((t) => t.urlHash.equals(urlHash)))
          .write(CoverCacheCompanion(lastAccessedAt: Value(lastAccessedAt)));
    }
    return path;
  }

  /// Registers a real cached audio file of [bytes] bytes in [db].
  Future<CachedAudio> addAudio({
    required Directory audioRoot,
    required String trackId,
    required int bytes,
  }) async {
    final audio = AudioCacheStore(
      database: db,
      baseDir: audioRoot,
      settings: settings,
    );
    final file = audio.fileFor(
      source: 'bilibili',
      sourceTrackId: trackId,
      extension: 'm4a',
    );
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(List<int>.filled(bytes, trackId.hashCode & 0xFF));
    return audio.insert(
      source: 'bilibili',
      sourceTrackId: trackId,
      filePath: file.path,
      bytes: bytes,
      qualityId: '30280',
      pinned: false,
    );
  }

  group('insert / lookup', () {
    test('writes the content-addressed file and returns its path', () async {
      final path = await addCover('url-1', 'hash-1', bytes: 4);

      expect(path, endsWith('hash-1.jpg'));
      expect(File(path).existsSync(), isTrue);
      expect(File(path).readAsBytesSync(), List<int>.filled(4, 6));

      final cover = await store.lookup('url-1');
      expect(cover, isNotNull);
      expect(cover!.urlHash, 'url-1');
      expect(cover.contentHash, 'hash-1');
      expect(cover.bytes, 4);
      expect(cover.filePath, path);
    });

    test('reuses an existing file instead of rewriting it', () async {
      final path = await addCover('url-1', 'hash-1', bytes: 8);
      final modified = File(path).lastModifiedSync();

      final again = await store.insert(
        urlHash: 'url-1',
        contentHash: 'hash-1',
        bytes: Uint8List.fromList(List<int>.filled(8, 99)),
      );

      expect(again, path);
      expect(File(path).readAsBytesSync(), List<int>.filled(8, 6));
      expect(File(path).lastModifiedSync(), modified);
    });
  });

  group('lookupPath / touch', () {
    test(
      'returns the path and lookup moves the row to the recent end',
      () async {
        await addCover('a', 'hash-a', lastAccessedAt: 1000);
        await addCover('b', 'hash-b', lastAccessedAt: 2000);

        expect((await store.entries()).map((e) => e.urlHash), ['a', 'b']);

        final path = await store.lookupPath('a');
        expect(path, isNotNull);
        expect(File(path!).existsSync(), isTrue);

        await store.lookup('a');

        expect((await store.entries()).map((e) => e.urlHash), ['b', 'a']);
      },
    );

    test('returns null when the file behind the row is gone', () async {
      final path = await addCover('a', 'hash-a');
      File(path).deleteSync();

      expect(await store.lookupPath('a'), isNull);
      expect(await store.lookupPath('missing'), isNull);
    });
  });

  group('content deduplication', () {
    test('identical content under two URLs shares one physical file', () async {
      final first = await addCover('url-1', 'shared-hash', bytes: 32);
      final second = await addCover('url-2', 'shared-hash', bytes: 32);

      expect(second, first);
      expect((await store.entries()).length, 2);
      expect((await store.entries()).map((e) => e.filePath).toSet().length, 1);
      expect(await store.totalBytes(), 32);
      expect(root.listSync().whereType<File>().length, 1);
    });

    test('totalBytes counts a shared file only once', () async {
      await addCover('url-1', 'shared-hash', bytes: 48);
      await addCover('url-2', 'shared-hash', bytes: 48);

      expect(await store.totalBytes(), 48);

      final first = (await store.entries()).first;
      await store.remove(first.id);

      // The surviving row still references the shared physical file.
      expect((await store.entries()).length, 1);
      expect(await store.totalBytes(), 48);
      expect(
        File((await store.entries()).single.filePath).existsSync(),
        isTrue,
      );
    });
  });

  group('ensureSpace', () {
    test('evicts the oldest cover but never audio when both fit', () async {
      settings.current = CacheSettings.defaults.copyWith(limitBytes: 1000);
      final audioRoot = Directory('${root.path}/audio')..createSync();
      await addAudio(audioRoot: audioRoot, trackId: 'track', bytes: 400);
      await addCover('old', 'hash-old', bytes: 100, lastAccessedAt: 1000);
      await addCover('new', 'hash-new', bytes: 100, lastAccessedAt: 2000);

      final result = await store.ensureSpace(500);

      expect(result.hasSpace, isTrue);
      expect(result.evictedCount, 1);
      expect(result.freedBytes, 100);
      expect(await store.lookup('old'), isNull);
      expect(await store.lookup('new'), isNotNull);

      final audio = AudioCacheStore(
        database: db,
        baseDir: audioRoot,
        settings: settings,
      );
      expect(await audio.lookup('bilibili', 'track'), isNotNull);
      expect(await audio.totalBytes(), 400);
    });

    test('reports no space when audio alone exceeds the limit', () async {
      settings.current = CacheSettings.defaults.copyWith(limitBytes: 100);
      final audioRoot = Directory('${root.path}/audio')..createSync();
      await addAudio(audioRoot: audioRoot, trackId: 'track', bytes: 200);
      await addCover('c1', 'hash-c1', bytes: 50, lastAccessedAt: 1000);

      final result = await store.ensureSpace(0);

      expect(result.hasSpace, isFalse);
      expect(result.evictedCount, 1);
      expect(await store.entries(), isEmpty);
    });

    test('is a no-op when there is already room', () async {
      settings.current = CacheSettings.defaults.copyWith(limitBytes: 1000);
      await addCover('a', 'hash-a', bytes: 100);

      final result = await store.ensureSpace(100);

      expect(result.evictedCount, 0);
      expect(result.freedBytes, 0);
      expect(result.hasSpace, isTrue);
      expect(await store.lookup('a'), isNotNull);
    });
  });
}
