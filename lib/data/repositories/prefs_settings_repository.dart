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

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flind_player/core/repositories/settings_repository.dart';

/// [SettingsRepository] backed by `shared_preferences`.
///
/// Reads never throw: a missing, corrupt, or platform-unavailable value falls
/// back to [CacheSettings.defaults], which enforces the 1 GiB cap.
/// [watchCacheSettings] is broadcast and seeds each subscriber with the current
/// value before forwarding updates pushed by [updateCacheSettings].
class PrefsSettingsRepository implements SettingsRepository {
  /// Preferences key for [CacheSettings.enabled].
  static const String enabledKey = 'cache.enabled';

  /// Preferences key for [CacheSettings.limitBytes].
  static const String limitBytesKey = 'cache.limitBytes';

  /// Preferences key for [CacheSettings.autoOnPlay].
  static const String autoOnPlayKey = 'cache.autoOnPlay';

  final StreamController<CacheSettings> _updates =
      StreamController<CacheSettings>.broadcast();

  @override
  Future<CacheSettings> cacheSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return _read(prefs);
    } catch (error) {
      debugPrint('PrefsSettingsRepository: read failed: $error');
      return CacheSettings.defaults;
    }
  }

  @override
  Future<void> updateCacheSettings(CacheSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(enabledKey, settings.enabled);
    await prefs.setInt(limitBytesKey, settings.limitBytes);
    await prefs.setBool(autoOnPlayKey, settings.autoOnPlay);
    _updates.add(settings);
  }

  @override
  Stream<CacheSettings> watchCacheSettings() {
    return Stream<CacheSettings>.multi((controller) {
      // Seed the subscriber with the current value before any update arrives.
      unawaited(
        cacheSettings().then((settings) {
          if (!controller.isClosed) controller.add(settings);
        }),
      );

      final subscription = _updates.stream.listen(
        (settings) {
          if (!controller.isClosed) controller.add(settings);
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!controller.isClosed) controller.addError(error, stackTrace);
        },
        onDone: () {
          if (!controller.isClosed) controller.close();
        },
      );
      controller.onCancel = subscription.cancel;
    }, isBroadcast: true);
  }

  /// Closes the update stream; the repository is unusable afterwards.
  Future<void> dispose() => _updates.close();

  CacheSettings _read(SharedPreferences prefs) {
    final enabled = prefs.getBool(enabledKey);
    final limitBytes = prefs.getInt(limitBytesKey);
    final autoOnPlay = prefs.getBool(autoOnPlayKey);

    return CacheSettings(
      enabled: enabled ?? CacheSettings.defaults.enabled,
      // A non-positive cap is corrupt data; keep the documented 1 GiB default.
      limitBytes: (limitBytes != null && limitBytes > 0)
          ? limitBytes
          : CacheSettings.defaults.limitBytes,
      autoOnPlay: autoOnPlay ?? CacheSettings.defaults.autoOnPlay,
    );
  }
}
