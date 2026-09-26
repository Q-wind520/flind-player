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

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/repositories/favorites_repository.dart';
import 'package:flind_player/data/database/app_database.dart';
import 'package:flind_player/data/database/playlist_defaults.dart';
import 'package:flind_player/data/repositories/drift_playlist_repository.dart';

/// Drift-backed [FavoritesRepository].
///
/// Favourites are the built-in playlist (row id pinned to
/// [favoritesPlaylistId]) inside the playlist system: every method is a thin
/// adapter over [DriftPlaylistRepository] scoped to that id. Members keep the
/// old denormalised-snapshot semantics, so a favourite survives the track
/// leaving the library exactly as before.
class DriftFavoritesRepository implements FavoritesRepository {
  DriftFavoritesRepository(AppDatabase db)
    : _playlists = DriftPlaylistRepository(db);

  final DriftPlaylistRepository _playlists;

  @override
  Stream<List<Track>> watchFavorites() {
    return _playlists.watchPlaylistTracks(favoritesPlaylistId);
  }

  @override
  Future<List<Track>> allFavorites() {
    return _playlists.playlistTracks(favoritesPlaylistId);
  }

  @override
  Future<bool> isFavorite(String uri) {
    return _playlists.containsTrack(favoritesPlaylistId, uri);
  }

  @override
  Future<void> addFavorite(Track track) {
    return _playlists.addTrack(favoritesPlaylistId, track);
  }

  @override
  Future<void> removeFavorite(String uri) {
    return _playlists.removeTrack(favoritesPlaylistId, uri);
  }

  @override
  Future<bool> toggleFavorite(Track track) async {
    if (await isFavorite(track.uri)) {
      await removeFavorite(track.uri);
      return false;
    }
    await addFavorite(track);
    return true;
  }
}