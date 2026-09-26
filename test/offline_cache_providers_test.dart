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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:flind_player/data/cache/audio_cache_store.dart';
import 'package:flind_player/data/cache/cover_cache_store.dart';
import 'package:flind_player/data/database/app_database.dart';
import 'package:flind_player/data/providers/cache_providers.dart';
import 'package:flind_player/data/providers/cover_providers.dart';
import 'package:flind_player/data/providers/offline_cache_providers.dart';

import 'audio_cache_store_test.dart' show FakeSettingsRepository;

void main() {
  late Directory root;
  late AppDatabase db;
  late AudioCacheStore audio;
  late CoverCacheStore covers;
  late ProviderContainer container;

  setUp(() {
    root = Directory.systemTemp.createTempSync('flind_offline_providers');
    db = AppDatabase(NativeDatabase.memory());
    audio = AudioCacheStore(
      database: db,
      baseDir: Directory(p.join(root.path, 'audio')),
      settings: FakeSettingsRepository(),
    );
    covers = CoverCacheStore(
      database: db,
      baseDir: Directory(p.join(root.path, 'cover')),
    );
    // Both stores are overridden, so no path_provider call is ever made.
    container = ProviderContainer(
      overrides: [
        audioCacheStoreProvider.overrideWithValue(audio),
        coverCacheStoreProvider.overrideWithValue(covers),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  /// Registers a cached song backed by a real file of [bytes] bytes.
  Future<CachedAudio> addEntry(
    String trackId, {
    required bool pinned,
    int bytes = 100,
  }) async {
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
      pinned: pinned,
    );
  }

  String pathFor(String trackId) => audio
      .fileFor(source: 'bilibili', sourceTrackId: trackId, extension: 'm4a')
      .path;

  group('cacheMaintenanceProvider.onClearAll', () {
    test('clears the online layer but keeps pinned downloads', () async {
      await addEntry('online', pinned: false);
      await addEntry('saved', pinned: true);

      await container.read(cacheMaintenanceProvider).onClearAll();

      expect(await audio.lookup('bilibili', 'online'), isNull);
      expect(await audio.lookup('bilibili', 'saved'), isNotNull);
      expect(File(pathFor('online')).existsSync(), isFalse);
      expect(File(pathFor('saved')).existsSync(), isTrue);
    });

    test('clears the layer-2 cover cache', () async {
      await covers.insert(
        urlHash: 'hash-url',
        contentHash: 'hash-content',
        bytes: Uint8List.fromList(const [1, 2, 3]),
      );
      expect(await covers.totalBytes(), greaterThan(0));

      await container.read(cacheMaintenanceProvider).onClearAll();

      expect(await covers.totalBytes(), 0);
      expect(await covers.entries(), isEmpty);
    });
  });

  group('offlineCacheEntriesProvider', () {
    test('lists only pinned downloads, oldest access first', () async {
      await addEntry('online', pinned: false);
      final first = await addEntry('a', pinned: true);
      final second = await addEntry('b', pinned: true);
      await audio.touch(second.id); // 'b' is now the most recent.

      final entries = await container.read(offlineCacheEntriesProvider.future);

      expect(entries.map((e) => e.sourceTrackId), ['a', 'b']);
      expect(entries.every((e) => e.pinned), isTrue);
      expect(entries.first.id, first.id);
    });
  });

  group('offlineCacheUsageProvider', () {
    test('sums the pinned entries only', () async {
      await addEntry('online', pinned: false, bytes: 500);
      await addEntry('a', pinned: true, bytes: 100);
      await addEntry('b', pinned: true, bytes: 250);

      expect(await container.read(offlineCacheUsageProvider.future), 350);
    });

    test('includes the companion-cover bytes of pinned entries', () async {
      final a = await addEntry('a', pinned: true, bytes: 100);
      final cover = audio.coverFileFor(
        source: 'bilibili',
        sourceTrackId: 'a',
        extension: 'jpg',
      )..writeAsBytesSync(List<int>.filled(50, 7));
      await audio.setCoverPath(a.id, cover.path, bytes: 50);
      await addEntry('b', pinned: true, bytes: 250);
      // An unpinned row's cover must not leak into the offline figure.
      final online = await addEntry('online', pinned: false, bytes: 900);
      final onlineCover = audio.coverFileFor(
        source: 'bilibili',
        sourceTrackId: 'online',
        extension: 'jpg',
      )..writeAsBytesSync(const [1]);
      await audio.setCoverPath(online.id, onlineCover.path, bytes: 1);

      // 100 + 50 (cover) + 250; the unpinned row and its cover are excluded.
      expect(await container.read(offlineCacheUsageProvider.future), 400);
    });
  });

  group('offlineCacheMaintenanceProvider', () {
    test('onRemove deletes a pinned download with its file', () async {
      final entry = await addEntry('a', pinned: true);
      final cover = audio.coverFileFor(
        source: 'bilibili',
        sourceTrackId: 'a',
        extension: 'jpg',
      )..writeAsBytesSync(const [1]);
      await audio.setCoverPath(entry.id, cover.path, bytes: 1);
      await addEntry('online', pinned: false);

      await container.read(offlineCacheMaintenanceProvider).onRemove(entry.id);

      expect(await audio.lookup('bilibili', 'a'), isNull);
      expect(File(pathFor('a')).existsSync(), isFalse);
      expect(File(cover.path).existsSync(), isFalse);
      // The online row is untouched.
      expect(await audio.lookup('bilibili', 'online'), isNotNull);
    });

    test('onRemove ignores a non-pinned entry', () async {
      final online = await addEntry('online', pinned: false);

      await container.read(offlineCacheMaintenanceProvider).onRemove(online.id);

      expect(await audio.lookup('bilibili', 'online'), isNotNull);
    });

    test('onRemove tolerates an unknown id', () async {
      await expectLater(
        container.read(offlineCacheMaintenanceProvider).onRemove(4242),
        completes,
      );
    });

    test('onClearAll removes downloads only', () async {
      await addEntry('a', pinned: true);
      await addEntry('b', pinned: true);
      await addEntry('online', pinned: false);

      await container.read(offlineCacheMaintenanceProvider).onClearAll();

      expect(await audio.entries(), hasLength(1));
      expect((await audio.entries()).single.sourceTrackId, 'online');
      expect(File(pathFor('a')).existsSync(), isFalse);
      expect(File(pathFor('online')).existsSync(), isTrue);
    });
  });

  group('combinedCacheUsageProvider', () {
    test('excludes pinned downloads from the cap figure', () async {
      await addEntry('online', pinned: false, bytes: 500);
      await addEntry('saved', pinned: true, bytes: 900);

      // Only the online row counts against the user's cap.
      expect(await container.read(combinedCacheUsageProvider.future), 500);
    });
  });
}
