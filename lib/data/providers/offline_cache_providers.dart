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
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flind_player/data/cache/audio_cache_store.dart';
import 'package:flind_player/data/providers/cache_providers.dart';

/// Every pinned (offline) download, oldest access first.
final offlineCacheEntriesProvider = FutureProvider<List<CachedAudio>>((
  ref,
) async {
  final entries = await ref.watch(audioCacheStoreProvider).entries();
  return entries.where((e) => e.pinned).toList(growable: false);
});

/// Bytes occupied by pinned downloads.
final offlineCacheUsageProvider = FutureProvider<int>((ref) async {
  final entries = await ref.watch(offlineCacheEntriesProvider.future);
  return entries.fold<int>(0, (sum, e) => sum + e.bytes);
});

/// Delete actions for the offline cache entry.
///
/// A plain callback holder rather than a store reference, so widget tests can
/// substitute recording callbacks without constructing a database or a
/// filesystem-backed cache.
@immutable
class OfflineCacheMaintenance {
  /// Creates a maintenance handle from the two delete actions.
  const OfflineCacheMaintenance({
    required this.onRemove,
    required this.onClearAll,
  });

  /// Deletes the pinned entry [id]; a non-pinned id is ignored.
  final Future<void> Function(int id) onRemove;

  /// Deletes every pinned entry.
  final Future<void> Function() onClearAll;
}

/// Applies deletions across the offline (pinned) part of the audio cache.
///
/// Never throws: a failing delete is logged and skipped so the settings screen
/// cannot be broken by a cache error.
final offlineCacheMaintenanceProvider = Provider<OfflineCacheMaintenance>((
  ref,
) {
  final store = ref.watch(audioCacheStoreProvider);
  return OfflineCacheMaintenance(
    onRemove: (id) async {
      try {
        for (final entry in await store.entries()) {
          if (entry.id != id) continue;
          if (entry.pinned) await store.remove(id);
          return;
        }
      } catch (error) {
        debugPrint('OfflineCacheMaintenance: remove($id) failed: $error');
      }
    },
    onClearAll: () async {
      try {
        final entries = await store.entries();
        for (final entry in entries.where((e) => e.pinned)) {
          await store.remove(entry.id);
        }
      } catch (error) {
        debugPrint('OfflineCacheMaintenance: clearAll failed: $error');
      }
    },
  );
});
