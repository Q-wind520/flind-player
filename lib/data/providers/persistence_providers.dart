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

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/repositories/favorites_repository.dart';
import 'package:flind_player/core/repositories/playback_snapshot_repository.dart';
import 'package:flind_player/data/providers/database_providers.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/data/repositories/drift_favorites_repository.dart';
import 'package:flind_player/data/repositories/drift_playback_snapshot_repository.dart';
import 'package:flind_player/data/services/playback_persistence_service.dart';

/// Persistence for the user's favourite tracks.
final favoritesRepositoryProvider = Provider<FavoritesRepository>(
  (ref) => DriftFavoritesRepository(ref.watch(appDatabaseProvider)),
);

/// Persistence for the single playback-session snapshot.
final playbackSnapshotRepositoryProvider = Provider<PlaybackSnapshotRepository>(
  (ref) => DriftPlaybackSnapshotRepository(ref.watch(appDatabaseProvider)),
);

/// Persists the playback queue/position across launches.
///
/// Startup drives it via `restore()` then `start()` (see `main.dart`).
final playbackPersistenceServiceProvider = Provider<PlaybackPersistenceService>(
  (ref) {
    final service = PlaybackPersistenceService(
      playback: ref.watch(playbackControllerProvider),
      repository: ref.watch(playbackSnapshotRepositoryProvider),
    );
    ref.onDispose(service.dispose);
    return service;
  },
);

/// Reactive view of the favourites, newest first.
final favoritesProvider = StreamProvider<List<Track>>(
  (ref) => ref.watch(favoritesRepositoryProvider).watchFavorites(),
);

/// Whether [uri] is currently favourited. Retries disabled so errors surface.
final isFavoriteProvider = FutureProvider.family<bool, String>((ref, uri) {
  ref.watch(favoritesProvider);
  return ref.watch(favoritesRepositoryProvider).isFavorite(uri);
}, retry: (_, _) => null);
