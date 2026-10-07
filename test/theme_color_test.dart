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

import 'package:flind_player/app/theme_color.dart';
import 'package:flind_player/core/models/app_theme_color.dart';
import 'package:flind_player/data/providers/settings_repository_provider.dart';

import 'support/fake_settings_repository.dart';

void main() {
  test('appThemeColorProvider loads the persisted colour', () async {
    final settings = FakeSettingsRepository()
      ..themeColor = const AppThemeColor(0xFF8B5CF6);
    final container = ProviderContainer(
      overrides: [settingsRepositoryProvider.overrideWithValue(settings)],
    );
    addTearDown(container.dispose);

    expect(
      await container.read(appThemeColorProvider.future),
      const AppThemeColor(0xFF8B5CF6),
    );
  });

  test('setThemeColor persists the choice and emits it', () async {
    final settings = FakeSettingsRepository();
    final container = ProviderContainer(
      overrides: [settingsRepositoryProvider.overrideWithValue(settings)],
    );
    addTearDown(container.dispose);

    await container.read(appThemeColorProvider.future);
    const chosen = AppThemeColor(0xFF3B82F6);
    await container.read(appThemeColorProvider.notifier).setThemeColor(chosen);

    expect(container.read(appThemeColorProvider).value, chosen);
    expect(settings.themeColor, chosen);
  });
}
