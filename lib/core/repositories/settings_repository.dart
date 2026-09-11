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

import 'package:flutter/foundation.dart';

/// User-configurable offline audio cache settings.
///
/// Mirrors the `SettingsRepository` keys in `docs/local-library.md` §4.4: the
/// cache can be toggled, capped in bytes, and written automatically while a
/// track streams.
@immutable
class CacheSettings {
  const CacheSettings({
    required this.enabled,
    required this.limitBytes,
    required this.autoOnPlay,
  });

  /// Whether offline caching is enabled at all.
  final bool enabled;

  /// Maximum number of bytes the cache may occupy before LRU eviction runs.
  final int limitBytes;

  /// Whether playing a track should cache it in the background.
  final bool autoOnPlay;

  /// Defaults from `docs/local-library.md` §4.4: enabled, 1 GiB, cache on play.
  static const CacheSettings defaults = CacheSettings(
    enabled: true,
    limitBytes: 1024 * 1024 * 1024,
    autoOnPlay: true,
  );

  CacheSettings copyWith({bool? enabled, int? limitBytes, bool? autoOnPlay}) {
    return CacheSettings(
      enabled: enabled ?? this.enabled,
      limitBytes: limitBytes ?? this.limitBytes,
      autoOnPlay: autoOnPlay ?? this.autoOnPlay,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CacheSettings &&
        other.enabled == enabled &&
        other.limitBytes == limitBytes &&
        other.autoOnPlay == autoOnPlay;
  }

  @override
  int get hashCode => Object.hash(enabled, limitBytes, autoOnPlay);

  @override
  String toString() {
    return 'CacheSettings(enabled: $enabled, limitBytes: $limitBytes, '
        'autoOnPlay: $autoOnPlay)';
  }
}

/// Persistence for user settings.
abstract interface class SettingsRepository {
  /// The current cache settings, falling back to [CacheSettings.defaults].
  Future<CacheSettings> cacheSettings();

  /// Persists [settings] and notifies [watchCacheSettings] subscribers.
  Future<void> updateCacheSettings(CacheSettings settings);

  /// Emits the current value on subscribe and again after every update.
  Stream<CacheSettings> watchCacheSettings();
}
