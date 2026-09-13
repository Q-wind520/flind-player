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

import 'package:flind_player/core/models/track_sort.dart';

/// User-configurable offline audio cache settings.
///
/// Mirrors the `SettingsRepository` keys in `docs/local-library.md` §4.4: the
/// cache is always on and capped in bytes; LRU eviction keeps it under the cap.
@immutable
class CacheSettings {
  const CacheSettings({required this.limitBytes});

  /// Maximum number of bytes the cache may occupy before LRU eviction runs.
  final int limitBytes;

  /// Defaults from `docs/local-library.md` §4.4: 1 GiB.
  static const CacheSettings defaults = CacheSettings(
    limitBytes: 1024 * 1024 * 1024,
  );

  CacheSettings copyWith({int? limitBytes}) {
    return CacheSettings(limitBytes: limitBytes ?? this.limitBytes);
  }

  @override
  bool operator ==(Object other) {
    return other is CacheSettings && other.limitBytes == limitBytes;
  }

  @override
  int get hashCode => limitBytes.hashCode;

  @override
  String toString() => 'CacheSettings(limitBytes: $limitBytes)';
}

/// Persistence for user settings.
abstract interface class SettingsRepository {
  /// The current cache settings, falling back to [CacheSettings.defaults].
  Future<CacheSettings> cacheSettings();

  /// Persists [settings] and notifies [watchCacheSettings] subscribers.
  Future<void> updateCacheSettings(CacheSettings settings);

  /// Emits the current value on subscribe and again after every update.
  Stream<CacheSettings> watchCacheSettings();

  /// The persisted library sort order, falling back to [TrackSort.title].
  Future<TrackSort> librarySort();

  /// Persists [sort] as the library sort order.
  Future<void> setLibrarySort(TrackSort sort);
}
