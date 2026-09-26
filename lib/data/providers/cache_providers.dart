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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:flind_player/core/repositories/settings_repository.dart';
import 'package:flind_player/core/sources/stream_resolver.dart';
import 'package:flind_player/data/cache/audio_cache_store.dart';
import 'package:flind_player/data/cache/audio_downloader.dart';
import 'package:flind_player/data/cache/download_manager.dart';
import 'package:flind_player/data/providers/bilibili_providers.dart';
import 'package:flind_player/data/providers/cover_providers.dart';
import 'package:flind_player/data/providers/database_providers.dart';
import 'package:flind_player/data/repositories/prefs_settings_repository.dart';
import 'package:flind_player/data/sources/composite_stream_resolver.dart';
import 'package:flind_player/data/sources/local/local_stream_resolver.dart';

/// Persisted user settings, including the offline cache configuration.
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final repository = PrefsSettingsRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

/// Offline audio cache index rooted at `<app support>/cache/audio`.
///
/// Layer 1 of the cache: audio files plus their companion covers, in a subtree
/// that never overlaps layer 2's `cache/cover`. The directory is resolved
/// lazily through `path_provider`, so this provider stays synchronous.
final audioCacheStoreProvider = Provider<AudioCacheStore>((ref) {
  return AudioCacheStore.lazy(
    database: ref.watch(appDatabaseProvider),
    settings: ref.watch(settingsRepositoryProvider),
    resolveBaseDir: () async {
      final support = await getApplicationSupportDirectory();
      return Directory(p.join(support.path, 'cache', 'audio'));
    },
  );
});

/// Reactive cache settings; emits the current value then every update.
final cacheSettingsProvider = StreamProvider<CacheSettings>(
  (ref) => ref.watch(settingsRepositoryProvider).watchCacheSettings(),
);

/// Total bytes currently occupied by the offline audio cache.
final audioCacheUsageProvider = FutureProvider<int>(
  (ref) => ref.watch(audioCacheStoreProvider).totalBytes(),
);

/// The online/local resolver used to obtain fresh stream URLs.
///
/// This is deliberately **not** the cache-first `streamResolverProvider`: the
/// [DownloadManager] must download the real network stream, so feeding it the
/// cached resolver would make it download from its own cache file (and recurse).
final innerStreamResolverProvider = Provider<StreamResolver>((ref) {
  final biliSource = ref.watch(biliSourceProvider);
  return CompositeStreamResolver(
    localResolver: const LocalStreamResolver(),
    sources: <String, StreamResolver>{biliSource.id: biliSource},
  );
});

/// Streams audio into the offline cache, one download at a time.
final audioDownloaderProvider = Provider<AudioDownloader>(
  (ref) => AudioDownloader(),
);

/// Serialises and indexes offline audio downloads.
///
/// Pinned downloads ask [CoverService.ensureCover] to materialise their
/// companion cover into layer 1; the callback reads the service lazily, so
/// there is no build-time dependency on `coverServiceProvider`.
final downloadManagerProvider = Provider<DownloadManager>((ref) {
  final manager = DownloadManager(
    store: ref.watch(audioCacheStoreProvider),
    downloader: ref.watch(audioDownloaderProvider),
    resolver: ref.watch(innerStreamResolverProvider),
    ensureCover: (track) => ref.read(coverServiceProvider).ensureCover(track),
  );
  ref.onDispose(manager.dispose);
  return manager;
});

/// Broadcasts download progress for the UI.
final downloadProgressProvider = StreamProvider<DownloadProgress>(
  (ref) => ref.watch(downloadManagerProvider).progress,
);
