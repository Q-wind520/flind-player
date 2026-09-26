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

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:flind_player/data/cache/cover_cache_store.dart';
import 'package:flind_player/data/cache/cover_downloader.dart';
import 'package:flind_player/data/providers/bilibili_providers.dart';
import 'package:flind_player/data/providers/cache_providers.dart';
import 'package:flind_player/data/providers/database_providers.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/data/services/cover_prefetch_coordinator.dart';
import 'package:flind_player/data/services/cover_service.dart';

/// Content-addressed remote-cover cache rooted at `<app support>/cache/cover`.
///
/// Layer 2 of the cache: session-scoped covers for un-cached songs, capped by
/// the store's own fixed [CoverCacheStore.ephemeralLimitBytes] and wiped on
/// start. The directory is resolved lazily through `path_provider`, so this
/// provider stays synchronous.
final coverCacheStoreProvider = Provider<CoverCacheStore>((ref) {
  return CoverCacheStore.lazy(
    database: ref.watch(appDatabaseProvider),
    resolveBaseDir: () async {
      final support = await getApplicationSupportDirectory();
      return Directory(p.join(support.path, 'cache', 'cover'));
    },
  );
});

/// Downloads remote cover bytes with the headers Bilibili's CDN expects.
final coverDownloaderProvider = Provider<CoverDownloader>(
  (ref) => CoverDownloader(),
);

/// Resolves, downloads and caches a track's remote cover.
final coverServiceProvider = Provider<CoverService>((ref) {
  return CoverService(
    store: ref.watch(coverCacheStoreProvider),
    audioStore: ref.watch(audioCacheStoreProvider),
    downloader: ref.watch(coverDownloaderProvider),
    library: ref.watch(musicLibraryRepositoryProvider),
    // Bilibili search/view payloads normally carry the cover URL, so this is
    // the fallback for tracks persisted before the URL was stored.
    resolveRemoteUrl: (bvid) async {
      final info = await ref.watch(biliApiProvider).videoInfo(bvid);
      return info.coverUrl;
    },
  );
});

/// Bytes occupied by the remote-cover cache on disk.
final coverCacheUsageProvider = FutureProvider<int>(
  (ref) => ref.watch(coverCacheStoreProvider).totalBytes(),
);

/// Bytes occupied by the audio cache plus the cover cache.
///
/// The audio side counts against the user's cap and the cover side against the
/// fixed layer-2 cap; the settings screen still reports the combined figure.
final combinedCacheUsageProvider = FutureProvider<int>((ref) async {
  final audio = await ref.watch(audioCacheStoreProvider).totalBytes();
  final covers = await ref.watch(coverCacheStoreProvider).totalBytes();
  return audio + covers;
});

/// Keeps the cover cache warm for whatever is in the playback queue.
///
/// Watched once from the app root so it lives for the whole session.
final coverPrefetchCoordinatorProvider = Provider<CoverPrefetchCoordinator>((
  ref,
) {
  final coordinator = CoverPrefetchCoordinator(
    service: ref.watch(coverServiceProvider),
    controller: ref.watch(playbackControllerProvider),
  );
  coordinator.start();
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

/// Maintenance actions the settings screen applies across both caches: audio
/// against the user's byte quota, covers against the fixed layer-2 cap.
///
/// A plain callback holder rather than a store reference, so widget tests can
/// substitute recording callbacks without constructing a database or a
/// filesystem-backed cache.
@immutable
class CacheMaintenance {
  /// Creates a maintenance handle from the two quota operations.
  const CacheMaintenance({
    required this.onEnforceLimits,
    required this.onClearAll,
  });

  /// Shrinks each cache to its own cap (audio to the user's limit, covers to
  /// the fixed layer-2 cap).
  final Future<void> Function() onEnforceLimits;

  /// Removes the online cache: every non-pinned audio row plus the whole
  /// layer-2 cover cache. Pinned (offline) downloads are kept; they have their
  /// own entry in the settings screen.
  final Future<void> Function() onClearAll;
}

/// Applies quota changes and clears across both caches.
final cacheMaintenanceProvider = Provider<CacheMaintenance>((ref) {
  final audio = ref.watch(audioCacheStoreProvider);
  final covers = ref.watch(coverCacheStoreProvider);
  return CacheMaintenance(
    onEnforceLimits: () async {
      await audio.enforceLimit();
      await covers.enforceLimit();
    },
    onClearAll: () async {
      await audio.clearUnpinned();
      await covers.clear();
    },
  );
});
