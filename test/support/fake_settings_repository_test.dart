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

import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/repositories/settings_repository.dart';

import 'fake_settings_repository.dart';

/// Slice-only fakes: everything outside the mixed-in slice must fall through to
/// `noSuchMethod` so a stray call fails loudly.
class _CacheOnly extends FakeSettingsBase with FakeCacheSettings {}

class _AppearanceOnly extends FakeSettingsBase with FakeAppearanceSettings {}

class _LibraryOnly extends FakeSettingsBase with FakeLibrarySettings {}

void main() {
  test('FakeSettingsRepository implements every settings slice', () {
    final fake = FakeSettingsRepository();

    expect(fake, isA<CacheSettingsRepository>());
    expect(fake, isA<LibrarySettingsRepository>());
    expect(fake, isA<AppearanceSettingsRepository>());
  });

  test('a slice-only fake throws for every method outside its slice', () {
    final SettingsRepository cache = _CacheOnly();
    final SettingsRepository appearance = _AppearanceOnly();
    final SettingsRepository library = _LibraryOnly();

    // Cache-only fake: appearance and library calls must throw.
    expect(() => cache.appLanguage(), throwsNoSuchMethodError);
    expect(() => cache.appThemeMode(), throwsNoSuchMethodError);
    expect(() => cache.librarySort(), throwsNoSuchMethodError);
    expect(() => cache.libraryViews(), throwsNoSuchMethodError);

    // Appearance-only fake: cache and library calls must throw.
    expect(() => appearance.cacheSettings(), throwsNoSuchMethodError);
    expect(() => appearance.watchCacheSettings(), throwsNoSuchMethodError);
    expect(() => appearance.librarySort(), throwsNoSuchMethodError);

    // Library-only fake: cache and appearance calls must throw.
    expect(() => library.cacheSettings(), throwsNoSuchMethodError);
    expect(() => library.updateCacheSettings(CacheSettings.defaults),
        throwsNoSuchMethodError);
    expect(() => library.appThemeMode(), throwsNoSuchMethodError);
  });
}
