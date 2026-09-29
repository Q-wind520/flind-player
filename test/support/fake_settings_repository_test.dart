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

/// Implements only the library slice: the rest must fall through to
/// `noSuchMethod` so a stray call fails loudly.
class _LibraryOnly extends FakeSettingsBase with FakeLibrarySettings {}

void main() {
  test('FakeSettingsRepository implements every settings slice', () {
    final fake = FakeSettingsRepository();

    expect(fake, isA<CacheSettingsRepository>());
    expect(fake, isA<LibrarySettingsRepository>());
    expect(fake, isA<AppearanceSettingsRepository>());
  });

  test('a slice-only fake throws outside its slice', () {
    final SettingsRepository fake = _LibraryOnly();

    expect(fake, isA<LibrarySettingsRepository>());
    expect(() => fake.cacheSettings(), throwsNoSuchMethodError);
  });
}
