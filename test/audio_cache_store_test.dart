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

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/track_sort.dart';
import 'package:flind_player/core/repositories/settings_repository.dart';
import 'package:flind_player/data/cache/audio_cache_store.dart';
import 'package:flind_player/data/database/app_database.dart';

/// In-memory [SettingsRepository] whose value the test can mutate.
class _FakeSettingsRepository implements SettingsRepository {
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
  late AudioCacheStore store;

  setUp(() {
    root = Directory.systemTemp.createTempSync('flind_audio_cache');
    db = AppDatabase(NativeDatabase.memory());
    settings = _FakeSettingsRepository();
    store = AudioCacheStore(database: db, baseDir: root, settings: settings);
  });

  tearDown(() async {
    await db.close();
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  /// Registers a cached entry backed by a real file of [bytes] zero bytes.
  Future<CachedAudio> addEntry(
    String trackId, {
    int bytes = 100,
    bool pinned = false,
    int? lastAccessedAt,
    String source = 'bilibili',
  }) async {
    final file = store.fileFor(
      source: source,
      sourceTrackId: trackId,
      extension: 'm4a',
    );
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(List<int>.filled(bytes, 0));

    final entry = await store.insert(
      source: source,
      sourceTrackId: trackId,
      filePath: file.path,
      bytes: bytes,
      qualityId: '30280',
      pinned: pinned,
    );

    if (lastAccessedAt != null) {
      await (db.update(db.audioCache)..where((t) => t.id.equals(entry.id)))
          .write(AudioCacheCompanion(lastAccessedAt: Value(lastAccessedAt)));
    }
    return entry;
  }

  String pathFor(String trackId) => store
      .fileFor(source: 'bilibili', sourceTrackId: trackId, extension: 'm4a')
      .path;

  group('fileFor', () {
    test('is deterministic and namespaced per source', () {
      final first = store.fileFor(
        source: 'bilibili',
        sourceTrackId: 'BV1:1',
        extension: 'm4a',
      );
      final again = store.fileFor(
        source: 'bilibili',
        sourceTrackId: 'BV1:1',
        extension: 'm4a',
      );
      final otherTrack = store.fileFor(
        source: 'bilibili',
        sourceTrackId: 'BV1:2',
        extension: 'm4a',
      );
      final otherSource = store.fileFor(
        source: 'local',
        sourceTrackId: 'BV1:1',
        extension: 'm4a',
      );

      expect(first.path, again.path);
      expect(first.path, isNot(otherTrack.path));
      expect(first.path, isNot(otherSource.path));
      expect(
        first.path,
        contains('${Platform.pathSeparator}bilibili${Platform.pathSeparator}'),
      );
      expect(first.path, endsWith('.m4a'));
    });
  });

  group('insert / lookup / touch', () {
    test('round-trips a cached entry', () async {
      final entry = await addEntry('BV1:1', bytes: 1234);

      final found = await store.lookup('bilibili', 'BV1:1');

      expect(found, isNotNull);
      expect(found!.id, entry.id);
      expect(found.source, 'bilibili');
      expect(found.sourceTrackId, 'BV1:1');
      expect(found.bytes, 1234);
      expect(found.qualityId, '30280');
      expect(found.pinned, isFalse);
      expect(found.filePath, pathFor('BV1:1'));
    });

    test('returns null for an unknown track', () async {
      expect(await store.lookup('bilibili', 'missing'), isNull);
    });

    test(
      'touch moves an entry to the most-recent end of the LRU order',
      () async {
        final a = await addEntry('a', lastAccessedAt: 1000);
        final b = await addEntry('b', lastAccessedAt: 2000);
        final c = await addEntry('c', lastAccessedAt: 3000);

        expect((await store.entries()).map((e) => e.id), [a.id, b.id, c.id]);

        await store.touch(a.id);

        expect((await store.entries()).map((e) => e.id), [b.id, c.id, a.id]);
      },
    );
  });

  group('setPinned', () {
    test('promotes a play-through entry so it survives eviction', () async {
      settings.current = CacheSettings.defaults.copyWith(limitBytes: 1000);
      final auto = await addEntry('auto', bytes: 400, lastAccessedAt: 1000);
      await addEntry('newer', bytes: 400, lastAccessedAt: 2000);

      await store.setPinned(auto.id, true);

      final result = await store.ensureSpace(400);

      expect(result.hasSpace, isTrue);
      final remaining = await store.entries();
      expect(remaining.map((e) => e.sourceTrackId), ['auto']);
      expect(remaining.single.pinned, isTrue);
    });

    test('unpinning makes the entry evictable again', () async {
      settings.current = CacheSettings.defaults.copyWith(limitBytes: 500);
      final pinned = await addEntry(
        'a',
        bytes: 400,
        pinned: true,
        lastAccessedAt: 1000,
      );

      expect((await store.ensureSpace(400)).hasSpace, isFalse);

      await store.setPinned(pinned.id, false);

      expect((await store.ensureSpace(400)).hasSpace, isTrue);
      expect(await store.entries(), isEmpty);
    });
  });

  group('ensureSpace', () {
    test('is a no-op when there is already room', () async {
      settings.current = CacheSettings.defaults.copyWith(limitBytes: 1000);
      final a = await addEntry('a', bytes: 400);

      final result = await store.ensureSpace(100);

      expect(result.evictedCount, 0);
      expect(result.freedBytes, 0);
      expect(result.hasSpace, isTrue);
      expect(await store.lookup('bilibili', 'a'), isNotNull);
      expect(File(pathFor('a')).existsSync(), isTrue);
      expect(a.id, greaterThan(0));
    });

    test('evicts the least-recently-used non-pinned entry first', () async {
      settings.current = CacheSettings.defaults.copyWith(limitBytes: 1000);
      await addEntry('a', bytes: 400, lastAccessedAt: 1000);
      await addEntry('b', bytes: 400, lastAccessedAt: 2000);
      await addEntry('c', bytes: 400, lastAccessedAt: 3000);

      final result = await store.ensureSpace(0);

      expect(result.evictedCount, 1);
      expect(result.freedBytes, 400);
      expect(result.hasSpace, isTrue);
      expect(await store.lookup('bilibili', 'a'), isNull);
      expect(File(pathFor('a')).existsSync(), isFalse);
      expect(await store.lookup('bilibili', 'b'), isNotNull);
      expect(await store.lookup('bilibili', 'c'), isNotNull);
    });

    test('never evicts pinned entries and reports no space when pinned '
        'alone exceeds the limit', () async {
      settings.current = CacheSettings.defaults.copyWith(limitBytes: 1000);
      await addEntry('a', bytes: 800, pinned: true, lastAccessedAt: 1000);
      await addEntry('b', bytes: 800, pinned: true, lastAccessedAt: 2000);

      final result = await store.ensureSpace(0);

      expect(result.evictedCount, 0);
      expect(result.freedBytes, 0);
      expect(result.hasSpace, isFalse);
      expect(await store.lookup('bilibili', 'a'), isNotNull);
      expect(await store.lookup('bilibili', 'b'), isNotNull);
      expect(File(pathFor('a')).existsSync(), isTrue);
      expect(File(pathFor('b')).existsSync(), isTrue);
    });

    test('evicts non-pinned entries while keeping pinned ones', () async {
      settings.current = CacheSettings.defaults.copyWith(limitBytes: 1000);
      await addEntry('pinned', bytes: 800, pinned: true, lastAccessedAt: 1000);
      await addEntry('streamed', bytes: 800, lastAccessedAt: 2000);

      final result = await store.ensureSpace(0);

      expect(result.evictedCount, 1);
      expect(result.freedBytes, 800);
      expect(result.hasSpace, isTrue);
      expect(await store.lookup('bilibili', 'pinned'), isNotNull);
      expect(await store.lookup('bilibili', 'streamed'), isNull);
    });

    test('a small limit forces eviction across several entries', () async {
      settings.current = CacheSettings.defaults.copyWith(limitBytes: 1000);
      for (var i = 0; i < 5; i++) {
        await addEntry('track$i', bytes: 300, lastAccessedAt: 1000 + i);
      }

      final result = await store.ensureSpace(0);

      expect(result.evictedCount, 2);
      expect(result.freedBytes, 600);
      expect(result.hasSpace, isTrue);
      expect(await store.totalBytes(), 900);
    });

    test('accounts for incoming bytes when deciding to evict', () async {
      settings.current = CacheSettings.defaults.copyWith(limitBytes: 1000);
      await addEntry('a', bytes: 400, lastAccessedAt: 1000);
      await addEntry('b', bytes: 400, lastAccessedAt: 2000);

      final result = await store.ensureSpace(500);

      expect(result.evictedCount, 1);
      expect(result.hasSpace, isTrue);
      expect(await store.totalBytes(), 400);
    });

    test('never evicts while caching is disabled', () async {
      settings.current = CacheSettings.defaults.copyWith(
        enabled: false,
        limitBytes: 1000,
      );
      await addEntry('a', bytes: 800, lastAccessedAt: 1000);
      await addEntry('b', bytes: 800, lastAccessedAt: 2000);

      final overLimit = await store.ensureSpace(0);

      // Documented: disabled means callers skip caching; ensureSpace still
      // reports whether the limit would have been respected and never evicts.
      expect(overLimit.evictedCount, 0);
      expect(overLimit.freedBytes, 0);
      expect(overLimit.hasSpace, isFalse);
      expect(await store.totalBytes(), 1600);

      settings.current = CacheSettings.defaults.copyWith(
        enabled: false,
        limitBytes: 4000,
      );
      final underLimit = await store.ensureSpace(0);

      expect(underLimit.hasSpace, isTrue);
      expect(await store.totalBytes(), 1600);
    });
  });

  group('remove / clear', () {
    test('remove deletes both the row and the file', () async {
      final entry = await addEntry('a', bytes: 100);
      expect(File(pathFor('a')).existsSync(), isTrue);

      await store.remove(entry.id);

      expect(await store.lookup('bilibili', 'a'), isNull);
      expect(File(pathFor('a')).existsSync(), isFalse);
    });

    test('clear deletes every row and file', () async {
      await addEntry('a');
      await addEntry('b');
      await addEntry('c');

      await store.clear();

      expect(await store.entries(), isEmpty);
      for (final id in ['a', 'b', 'c']) {
        expect(File(pathFor(id)).existsSync(), isFalse);
      }
    });
  });

  group('checkIntegrity', () {
    test('removes rows with vanished files and deletes orphans', () async {
      await addEntry('kept', bytes: 100);
      await addEntry('vanished', bytes: 100);
      File(pathFor('vanished')).deleteSync();

      final orphan = File('${root.path}/bilibili/orphan.bin')
        ..createSync(recursive: true)
        ..writeAsBytesSync([1, 2, 3]);

      // A file outside the cache root must never be touched.
      final outside = File(
        '${root.parent.path}/flind_outside_${DateTime.now().microsecondsSinceEpoch}.bin',
      )..writeAsBytesSync([1]);
      addTearDown(() {
        if (outside.existsSync()) outside.deleteSync();
      });

      final report = await store.checkIntegrity();

      expect(report.rowsRemoved, 1);
      expect(report.orphansRemoved, 1);
      expect(await store.lookup('bilibili', 'kept'), isNotNull);
      expect(await store.lookup('bilibili', 'vanished'), isNull);
      expect(orphan.existsSync(), isFalse);
      expect(outside.existsSync(), isTrue);
    });
  });

  group('lazy constructor', () {
    test(
      'resolves the directory and serves fileFor after an async call',
      () async {
        final lazyRoot = Directory('${root.path}/lazy');
        final lazy = AudioCacheStore.lazy(
          database: db,
          settings: settings,
          resolveBaseDir: () async => lazyRoot,
        );

        await lazy.lookup('bilibili', 'nothing');

        final file = lazy.fileFor(
          source: 'bilibili',
          sourceTrackId: 'x',
          extension: 'm4a',
        );
        expect(file.path, startsWith(lazyRoot.path));
        expect(lazyRoot.existsSync(), isTrue);
      },
    );

    test('warms the directory up eagerly so fileFor can run first', () async {
      final lazyRoot = Directory('${root.path}/warm');
      final lazy = AudioCacheStore.lazy(
        database: db,
        settings: settings,
        resolveBaseDir: () async => lazyRoot,
      );

      File? file;
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (file == null) {
        if (DateTime.now().isAfter(deadline)) {
          fail('Timed out waiting for the lazy directory warm-up');
        }
        try {
          file = lazy.fileFor(
            source: 'bilibili',
            sourceTrackId: 'x',
            extension: 'm4a',
          );
        } on StateError {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      }

      expect(file.path, startsWith(lazyRoot.path));
    });
  });
}
