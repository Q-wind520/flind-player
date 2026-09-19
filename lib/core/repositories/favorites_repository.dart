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

/// Persistence for the user's favourite tracks.
///
/// Favourites are a **denormalised snapshot** of the track: each row carries
/// its own copy of the metadata so it survives the track leaving the library
/// (a removed scan root, a soft-deleted row, or an offline Bilibili item). The
/// canonical [Track.uri] is the unique key.
abstract interface class FavoritesRepository {
  /// Emits every favourite, newest first, whenever the set changes.
  Stream<List<Track>> watchFavorites();

  /// Every favourite, newest first.
  Future<List<Track>> allFavorites();

  /// Whether [uri] is currently favourited.
  Future<bool> isFavorite(String uri);

  /// Adds [track] to the favourites, refreshing the snapshot if [Track.uri]
  /// already exists.
  Future<void> addFavorite(Track track);

  /// Removes the favourite with [uri]; a no-op when absent.
  Future<void> removeFavorite(String uri);

  /// Updates the cached cover pointer of an existing favourite, identified by
  /// its canonical [uri].
  ///
  /// A no-op when [uri] is not favourited, and it never touches `favoritedAt`,
  /// so refreshing a cover cannot reorder the favourites list.
  Future<void> updateFavoriteCover(
    String uri, {
    String? coverPath,
    String? coverUrl,
  });

  /// Adds [track] when absent, removes it when present.
  ///
  /// Returns the new state (`true` = now favourited).
  Future<bool> toggleFavorite(Track track);
}
