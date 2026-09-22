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
import 'package:flind_player/core/repositories/playlist_repository.dart';
import 'package:flind_player/data/providers/database_providers.dart';
import 'package:flind_player/data/repositories/drift_playlist_repository.dart';

/// Playlist persistence.
final playlistRepositoryProvider = Provider<PlaylistRepository>(
  (ref) => DriftPlaylistRepository(ref.watch(appDatabaseProvider)),
);

/// Reactive view of every playlist, favourites first.
final playlistsProvider = StreamProvider<List<Playlist>>(
  (ref) => ref.watch(playlistRepositoryProvider).watchPlaylists(),
);

/// The user-created playlists (the built-in favourites playlist excluded).
final customPlaylistsProvider = Provider<List<Playlist>>((ref) {
  final playlists = ref.watch(playlistsProvider).value ?? const <Playlist>[];
  return playlists
      .where((playlist) => playlist.kind == PlaylistKind.custom)
      .toList(growable: false);
});

/// Reactive view of one playlist's members, newest first.
final playlistTracksProvider = StreamProvider.family<List<Track>, int>((
  ref,
  id,
) => ref.watch(playlistRepositoryProvider).watchPlaylistTracks(id));

/// Reactive view of one playlist's derived cover.
final playlistCoverProvider = StreamProvider.family<PlaylistCover?, int>((
  ref,
  id,
) => ref.watch(playlistRepositoryProvider).watchPlaylistCover(id));