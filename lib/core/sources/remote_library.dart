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
import 'package:flind_player/core/sources/remote_album.dart';
import 'package:flind_player/core/sources/remote_artist.dart';
import 'package:flind_player/core/sources/remote_playlist.dart';

/// A source that can recommend playlists and songs.
abstract interface class RecommendationSource {
  /// Playlists recommended for the current account, or a popular fallback for
  /// anonymous users when the source supports one.
  Future<List<RemotePlaylist>> recommendedPlaylists({int limit = 30});

  /// Daily recommended songs. Sources that require login return an empty list
  /// or throw a login-required error; the UI treats both as "not available".
  Future<List<Track>> recommendedSongs();
}

/// A source that exposes album pages.
abstract interface class RemoteAlbumSource {
  Future<RemoteAlbum?> album(String albumId);
  Future<RemoteTrackPage> albumTracks(String albumId, {int page = 1});
}

/// A source that exposes artist pages.
abstract interface class RemoteArtistSource {
  Future<RemoteArtist?> artist(String artistId);
  Future<RemoteTrackPage> artistSongs(String artistId, {int page = 1});
  Future<List<RemoteAlbum>> artistAlbums(String artistId, {int page = 1});
}

/// A source with account-scoped like state.
abstract interface class LikeSource {
  Future<Set<String>> likedTrackIds(String userId);
  Future<void> setLiked(String trackId, bool liked);
}
