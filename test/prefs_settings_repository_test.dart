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
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flind_player/core/repositories/settings_repository.dart';
import 'package:flind_player/data/repositories/prefs_settings_repository.dart';

/// Polls until [condition] is true, failing after [timeout].
Future<void> _waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for condition');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('returns defaults when nothing is stored', () async {
    final repository = PrefsSettingsRepository();
    addTearDown(repository.dispose);

    expect(await repository.cacheSettings(), CacheSettings.defaults);
  });

  test('updates round-trip through shared_preferences', () async {
    final repository = PrefsSettingsRepository();
    addTearDown(repository.dispose);
    const updated = CacheSettings(
      enabled: false,
      limitBytes: 2048,
      autoOnPlay: false,
    );

    await repository.updateCacheSettings(updated);

    expect(await repository.cacheSettings(), updated);
  });

  test('falls back to defaults for a corrupt stored limit', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'cache.limitBytes': -5,
    });
    final repository = PrefsSettingsRepository();
    addTearDown(repository.dispose);

    final settings = await repository.cacheSettings();

    expect(settings.limitBytes, CacheSettings.defaults.limitBytes);
    expect(settings.enabled, CacheSettings.defaults.enabled);
    expect(settings.autoOnPlay, CacheSettings.defaults.autoOnPlay);
  });

  test('watchCacheSettings emits the current value on subscribe and '
      'again after an update', () async {
    final repository = PrefsSettingsRepository();
    addTearDown(repository.dispose);
    final emissions = <CacheSettings>[];
    final subscription = repository.watchCacheSettings().listen(emissions.add);
    addTearDown(subscription.cancel);

    await _waitFor(() => emissions.isNotEmpty);
    expect(emissions, [CacheSettings.defaults]);

    const updated = CacheSettings(
      enabled: true,
      limitBytes: 4096,
      autoOnPlay: false,
    );
    await repository.updateCacheSettings(updated);

    await _waitFor(() => emissions.length >= 2);
    expect(emissions, [CacheSettings.defaults, updated]);
  });

  test(
    'watchCacheSettings is broadcast and supports several listeners',
    () async {
      final repository = PrefsSettingsRepository();
      addTearDown(repository.dispose);
      final first = <CacheSettings>[];
      final second = <CacheSettings>[];
      final firstSubscription = repository.watchCacheSettings().listen(
        first.add,
      );
      final secondSubscription = repository.watchCacheSettings().listen(
        second.add,
      );
      addTearDown(firstSubscription.cancel);
      addTearDown(secondSubscription.cancel);

      await _waitFor(() => first.isNotEmpty && second.isNotEmpty);

      expect(first, [CacheSettings.defaults]);
      expect(second, [CacheSettings.defaults]);
    },
  );
}
