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

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/repositories/settings_repository.dart';
import 'package:flind_player/data/cache/audio_cache_store.dart';
import 'package:flind_player/data/database/app_database.dart';
import 'package:flind_player/data/repositories/prefs_settings_repository.dart';

/// Implements only the cache slice: the point is that a consumer depending on
/// [CacheSettingsRepository] compiles without the rest of the settings surface.
///
/// Deliberately NOT the shared `FakeCacheSettings` (m4): that mixin sits on
/// `FakeSettingsBase`, which implements the full `SettingsRepository`, so a
/// consumer widened to the composite would still compile — defeating the
/// compile-time guard this test exists to provide.
class _CacheSliceFake implements CacheSettingsRepository {
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
}

void main() {
  test('PrefsSettingsRepository implements every settings slice', () {
    final repository = PrefsSettingsRepository();
    addTearDown(repository.dispose);

    expect(repository, isA<CacheSettingsRepository>());
    expect(repository, isA<LibrarySettingsRepository>());
    expect(repository, isA<AppearanceSettingsRepository>());
  });

  test('AudioCacheStore depends on the cache settings slice only', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final root = Directory.systemTemp.createTempSync('flind_slice');
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    final store = AudioCacheStore(
      database: database,
      baseDir: root,
      settings: _CacheSliceFake(),
    );

    expect(await store.entries(), isEmpty);
  });
}
