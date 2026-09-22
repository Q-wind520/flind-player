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

/// Shared constants for the built-in favourites playlist.
///
/// Favourites are a normal `playlists` row pinned to [favoritesPlaylistId]
/// with [playlistKindFavorites]. The UI overrides the display name with l10n;
/// [favoritesPlaylistStoredName] is the neutral name persisted in the database.
/// Both the v7 -> v8 migration and the repositories import these so the pinned
/// id and kind strings can never drift apart.
library;

/// Row id of the built-in favourites playlist.
const int favoritesPlaylistId = 1;

/// Neutral stored name of the built-in favourites playlist.
const String favoritesPlaylistStoredName = 'Favorites';

/// `playlists.kind` value for the built-in favourites playlist.
const String playlistKindFavorites = 'favorites';

/// `playlists.kind` value for user-created playlists.
const String playlistKindCustom = 'custom';