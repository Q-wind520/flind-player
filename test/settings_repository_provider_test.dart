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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/data/providers/settings_repository_provider.dart';
import 'package:flind_player/data/repositories/prefs_settings_repository.dart';

void main() {
  test('settingsRepositoryProvider wires the prefs-backed repository', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(settingsRepositoryProvider),
      isA<PrefsSettingsRepository>(),
    );
  });
}
