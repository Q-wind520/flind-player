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

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/models/track_sort.dart';
import 'package:flind_player/data/providers/database_providers.dart';
import 'package:flind_player/features/library/library_sort_provider.dart';
import 'package:flind_player/data/services/library_sync_service.dart';
import 'package:flind_player/data/sources/local/artwork_cache.dart';
import 'package:flind_player/data/sources/local/local_file_importer.dart';
import 'package:flind_player/data/sources/local/local_library_scanner.dart';
import 'package:flind_player/data/sources/local/local_metadata_reader.dart';

/// Reads embedded metadata from local audio files.
final localMetadataReaderProvider = Provider<LocalMetadataReader>(
  (ref) => LocalMetadataReader(),
);

/// Picks and imports local audio files.
final localFileImporterProvider = Provider<LocalFileImporter>(
  (ref) => LocalFileImporter(ref.watch(localMetadataReaderProvider)),
);

/// Reactive view of the whole library, newest database state included.
///
/// Watches [librarySortProvider] so the list re-sorts when the user changes
/// the sort order.
final libraryTracksProvider = StreamProvider<List<Track>>((ref) {
  final sort = ref.watch(librarySortProvider).value ?? TrackSort.title;
  return ref.watch(musicLibraryRepositoryProvider).watchTracks(sort: sort);
});

/// Content-addressed cover cache under `<app support>/covers`.
///
/// The directory is resolved lazily through `path_provider` on first use, so
/// this provider stays synchronous.
final artworkCacheProvider = Provider<ArtworkCache>((ref) {
  return ArtworkCache.lazy(
    resolveBaseDir: () async {
      final support = await getApplicationSupportDirectory();
      return Directory(p.join(support.path, 'covers'));
    },
  );
});

/// Walks configured roots and extracts local track metadata in parallel.
final localLibraryScannerProvider = Provider<LocalLibraryScanner>(
  (ref) => LocalLibraryScanner(reader: ref.watch(localMetadataReaderProvider)),
);

/// Orchestrates full local-library syncs.
final librarySyncServiceProvider = Provider<LibrarySyncService>((ref) {
  final service = LibrarySyncService(
    scanner: ref.watch(localLibraryScannerProvider),
    repository: ref.watch(musicLibraryRepositoryProvider),
    artworkCache: ref.watch(artworkCacheProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Progress stream of the active (or last) library sync.
final librarySyncStateProvider = StreamProvider<LibrarySyncState>(
  (ref) => ref.watch(librarySyncServiceProvider).state,
);

/// The configured local scan roots.
final scanRootsProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(musicLibraryRepositoryProvider).scanRoots(),
);

/// Full-text search over the local library.
///
/// A blank query resolves to an empty list instead of the whole library.
final librarySearchProvider = FutureProvider.family<List<Track>, String>((
  ref,
  query,
) async {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return const <Track>[];
  return ref.watch(musicLibraryRepositoryProvider).searchTracks(trimmed);
});
