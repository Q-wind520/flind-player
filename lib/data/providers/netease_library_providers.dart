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
import 'package:flind_player/core/sources/remote_album.dart';
import 'package:flind_player/core/sources/remote_artist.dart';
import 'package:flind_player/core/sources/remote_playlist.dart';
import 'package:flind_player/data/providers/auth_providers.dart';
import 'package:flind_player/data/providers/netease_providers.dart';

/// The signed-in user's NetEase playlists; empty when signed out.
final neteaseMyPlaylistsProvider =
    FutureProvider.autoDispose<List<RemotePlaylist>>((ref) async {
      final account = ref.watch(authAccountProvider('netease'));
      if (account == null) return const <RemotePlaylist>[];
      return ref
          .watch(neteaseRemotePlaylistSourceProvider)
          .playlistsForUser(account.userId);
    });

/// Personalised/popular NetEase playlists.
final neteaseRecommendedPlaylistsProvider =
    FutureProvider.autoDispose<List<RemotePlaylist>>((ref) {
      return ref
          .watch(neteaseRecommendationSourceProvider)
          .recommendedPlaylists();
    });

/// Track ids the signed-in user has liked; empty when signed out.
final neteaseLikedIdsProvider = FutureProvider.autoDispose<Set<String>>((
  ref,
) async {
  final account = ref.watch(authAccountProvider('netease'));
  if (account == null) return <String>{};
  return ref.watch(neteaseLikeSourceProvider).likedTrackIds(account.userId);
});

/// Tracks in one NetEase playlist.
final neteasePlaylistTracksProvider = FutureProvider.autoDispose
    .family<List<Track>, String>((ref, id) async {
      final page = await ref
          .watch(neteaseRemotePlaylistSourceProvider)
          .playlistTracks(id);
      return page.tracks;
    });

/// Album search results.
final neteaseAlbumSearchProvider = FutureProvider.autoDispose
    .family<List<RemoteAlbum>, String>((ref, query) async {
      final trimmed = query.trim();
      if (trimmed.isEmpty) return const <RemoteAlbum>[];
      return ref.watch(neteaseRemoteSearchSourceProvider).searchAlbums(trimmed);
    });

/// Artist search results.
final neteaseArtistSearchProvider = FutureProvider.autoDispose
    .family<List<RemoteArtist>, String>((ref, query) async {
      final trimmed = query.trim();
      if (trimmed.isEmpty) return const <RemoteArtist>[];
      return ref
          .watch(neteaseRemoteSearchSourceProvider)
          .searchArtists(trimmed);
    });

/// Album metadata.
final neteaseAlbumProvider = FutureProvider.autoDispose
    .family<RemoteAlbum?, String>((ref, id) {
      return ref.watch(neteaseRemoteAlbumSourceProvider).album(id);
    });

/// Tracks in one album.
final neteaseAlbumTracksProvider = FutureProvider.autoDispose
    .family<List<Track>, String>((ref, id) async {
      final page = await ref
          .watch(neteaseRemoteAlbumSourceProvider)
          .albumTracks(id);
      return page.tracks;
    });

/// Artist metadata.
final neteaseArtistProvider = FutureProvider.autoDispose
    .family<RemoteArtist?, String>((ref, id) {
      return ref.watch(neteaseRemoteArtistSourceProvider).artist(id);
    });

/// Artist hot songs.
final neteaseArtistSongsProvider = FutureProvider.autoDispose
    .family<List<Track>, String>((ref, id) async {
      final page = await ref
          .watch(neteaseRemoteArtistSourceProvider)
          .artistSongs(id);
      return page.tracks;
    });

/// Artist albums.
final neteaseArtistAlbumsProvider = FutureProvider.autoDispose
    .family<List<RemoteAlbum>, String>((ref, id) {
      return ref.watch(neteaseRemoteArtistSourceProvider).artistAlbums(id);
    });
