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

import 'package:flutter/foundation.dart';

import 'package:flind_player/core/models/track.dart';

/// A playlist that lives on a remote source and is browsed by identifier.
@immutable
class RemotePlaylist {
  /// Source-specific playlist identifier (for Bilibili, the folder media id).
  final String id;

  final String title;

  /// Remote cover image URL, or `null` when the source exposes none.
  final String? coverUrl;

  /// Number of entries the source reports, which may exceed what one page
  /// returns.
  final int trackCount;

  const RemotePlaylist({
    required this.id,
    required this.title,
    this.coverUrl,
    this.trackCount = 0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RemotePlaylist &&
          other.id == id &&
          other.title == title &&
          other.coverUrl == coverUrl &&
          other.trackCount == trackCount;

  @override
  int get hashCode => Object.hash(id, title, coverUrl, trackCount);

  @override
  String toString() =>
      'RemotePlaylist(id: $id, title: $title, trackCount: $trackCount)';
}

/// A source that exposes playlists owned by an online account.
///
/// Implementations are anonymous by design: only playlists the account has
/// published (e.g. Bilibili's public favourite folders) are reachable — no
/// login, credentials or secure storage are involved.
abstract interface class RemotePlaylistSource {
  /// Stable identifier, matching the underlying `MusicSource` id.
  String get id;

  /// Public favourite folders for [userId].
  Future<List<RemotePlaylist>> playlistsForUser(String userId);

  /// Tracks inside [playlistId], newest first.
  Future<List<Track>> playlistTracks(String playlistId, {int page = 1});
}
