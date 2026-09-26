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

import 'package:flind_player/data/cache/audio_cache_store.dart';
import 'package:flind_player/data/cache/cache_relocator.dart';
import 'package:flind_player/data/cache/cover_cache_store.dart';
import 'package:flind_player/data/database/app_database.dart';

import 'audio_cache_store_test.dart' show FakeSettingsRepository;

void main() {
  test('moves legacy audio files into the new root and rewrites paths', () async {
    final dir = Directory.systemTemp.createTempSync('flind_relocate');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final legacy = Directory('${dir.path}/audio_cache')..createSync();
    final newRoot = Directory('${dir.path}/cache/audio');
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    // A row pointing at the legacy root, with a companion cover beside it.
    final legacyFile = File('${legacy.path}/bilibili/abc.m4a')
      ..createSync(recursive: true)
      ..writeAsBytesSync(const [1, 2, 3]);
    final legacyCover = File('${legacy.path}/bilibili/abc.cover.jpg')
      ..createSync(recursive: true)
      ..writeAsBytesSync(const [4, 5, 6]);
    await db.into(db.audioCache).insert(
      AudioCacheCompanion.insert(
        source: 'bilibili',
        sourceTrackId: 'BV1:1',
        filePath: legacyFile.path,
        bytes: 3,
        qualityId: '30280',
        cachedAt: 1,
        lastAccessedAt: 1,
        coverPath: Value(legacyCover.path),
        coverBytes: Value(3),
      ),
    );

    final store = AudioCacheStore(
      database: db,
      baseDir: newRoot,
      settings: FakeSettingsRepository(),
    );
    await CacheRelocator(
      database: db,
      audioStore: store,
      legacyAudioRoot: legacy,
    ).relocate();

    final row = (await store.lookup('bilibili', 'BV1:1'))!;
    expect(row.filePath, startsWith(newRoot.path));
    expect(File(row.filePath).existsSync(), isTrue);
    expect(legacyFile.existsSync(), isFalse);

    // The companion cover travels with the audio file and its recorded path
    // is rewritten too, or the artwork dangles after relocation.
    expect(row.coverPath, startsWith(newRoot.path));
    expect(File(row.coverPath!).existsSync(), isTrue);
    expect(legacyCover.existsSync(), isFalse);
  });

  test('moves legacy layer-2 covers into the new root and rewrites paths', () async {
    final dir = Directory.systemTemp.createTempSync('flind_relocate_cover');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final legacy = Directory('${dir.path}/cover_cache')..createSync();
    final newRoot = Directory('${dir.path}/cache/cover');
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final legacyFile = File('${legacy.path}/aaaa.jpg')
      ..createSync(recursive: true)
      ..writeAsBytesSync(const [7, 8, 9]);
    await db.into(db.coverCache).insert(
      CoverCacheCompanion.insert(
        urlHash: 'url-hash-1',
        filePath: legacyFile.path,
        contentHash: 'content-hash-1',
        bytes: 3,
        cachedAt: 1,
        lastAccessedAt: 1,
      ),
    );

    final coverStore = CoverCacheStore(database: db, baseDir: newRoot);
    final audioStore = AudioCacheStore(
      database: db,
      baseDir: Directory('${dir.path}/cache/audio'),
      settings: FakeSettingsRepository(),
    );
    await CacheRelocator(
      database: db,
      audioStore: audioStore,
      coverStore: coverStore,
      // Never created: the audio pass must be a no-op here.
      legacyAudioRoot: Directory('${dir.path}/audio_cache'),
      legacyCoverRoot: legacy,
    ).relocate();

    final row = (await coverStore.lookup('url-hash-1'))!;
    expect(row.filePath, startsWith(newRoot.path));
    expect(File(row.filePath).existsSync(), isTrue);
    expect(legacyFile.existsSync(), isFalse);
  });
}
