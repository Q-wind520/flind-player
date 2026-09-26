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

/// The kind of a [Playlist].
enum PlaylistKind {
  /// The built-in favourites playlist (row id pinned to 1). It cannot be
  /// deleted, renamed or re-covered.
  favorites,

  /// A user-created playlist.
  custom,
}

/// A persisted playlist.
class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    required this.kind,
    this.description,
    this.coverPath,
    this.coverUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final PlaylistKind kind;
  final String? description;

  /// Explicit cover (overrides the derived fallback chain).
  final String? coverPath;

  /// Remote cover URL, mirroring [Track.coverUrl].
  final String? coverUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Returns a copy with the given fields replaced.
  ///
  /// Nullable fields keep their current value when omitted.
  Playlist copyWith({
    String? name,
    PlaylistKind? kind,
    String? description,
    String? coverPath,
    String? coverUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Playlist(
      id: id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      description: description ?? this.description,
      coverPath: coverPath ?? this.coverPath,
      coverUrl: coverUrl ?? this.coverUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// A playlist's derived cover.
///
/// Never materialised: it is computed on read from the explicit playlist cover
/// or the newest member's pool cover, so it can never go stale. `null` means
/// "no cover available" (the UI shows a default placeholder).
class PlaylistCover {
  const PlaylistCover({this.coverPath, this.coverUrl});

  final String? coverPath;
  final String? coverUrl;
}

/// Persistence for playlists and their members.
///
/// Members are pure references into the `tracks` pool, keyed by
/// `(playlistId, Track.uri)`. Adding a member promotes the track into the pool
/// first; reads `JOIN` the pool, so pool metadata is always current and the
/// pool is the single source of truth. Soft-deleted pool rows are retained, so
/// a member survives its track leaving the library.
abstract interface class PlaylistRepository {
  /// Emits every playlist, favourites first, whenever the set changes.
  Stream<List<Playlist>> watchPlaylists();

  /// The playlist with [id], or `null` when absent.
  Future<Playlist?> playlistById(int id);

  /// Creates a custom playlist with [name] (required, non-blank), an optional
  /// [description] and an optional explicit cover ([coverPath]/[coverUrl]).
  /// An empty playlist is allowed.
  ///
  /// Throws an [ArgumentError] when [name] is blank.
  Future<Playlist> createPlaylist({
    required String name,
    String? description,
    String? coverPath,
    String? coverUrl,
  });

  /// Updates a custom playlist's [name], [description] or cover.
  ///
  /// A `null` [name], [description], [coverPath] or [coverUrl] leaves that field
  /// unchanged. Pass `clearCover: true` to explicitly clear both cover columns.
  ///
  /// Throws a [StateError] for the built-in favourites playlist, and an
  /// [ArgumentError] when [name] is provided but blank.
  Future<void> updatePlaylist(
    int id, {
    String? name,
    String? description,
    String? coverPath,
    String? coverUrl,
    bool clearCover = false,
  });

  /// Deletes the playlist with [id] and all of its members.
  ///
  /// Throws a [StateError] for the built-in favourites playlist.
  Future<void> deletePlaylist(int id);

  /// Emits every member of the playlist with [id], newest first, whenever the
  /// set changes.
  Stream<List<Track>> watchPlaylistTracks(int id);

  /// Every member of the playlist with [id], newest first.
  Future<List<Track>> playlistTracks(int id);

  /// Adds [track] to the playlist, promoting it into the pool first; a no-op
  /// when the `(playlistId, uri)` pair already exists.
  Future<void> addTrack(int playlistId, Track track);

  /// Removes the member with [uri] from the playlist; a no-op when absent.
  Future<void> removeTrack(int playlistId, String uri);

  /// Whether the playlist with [playlistId] contains [uri].
  Future<bool> containsTrack(int playlistId, String uri);

  /// Emits the playlist's derived cover whenever it could change.
  ///
  /// Fallback chain: explicit playlist cover, then the newest member's pool
  /// cover, then `null` (default placeholder).
  Stream<PlaylistCover?> watchPlaylistCover(int id);
}