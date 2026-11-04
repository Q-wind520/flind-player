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

/// Tracks in one NetEase playlist.
final neteasePlaylistTracksProvider = FutureProvider.autoDispose
    .family<List<Track>, String>((ref, id) async {
      final page = await ref
          .watch(neteaseRemotePlaylistSourceProvider)
          .playlistTracks(id);
      return page.tracks;
    });
