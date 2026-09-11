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

/// One page of tracks fetched from a [RemotePlaylistSource].
///
/// Carries enough metadata for the UI to paginate: [hasMore] tells it whether a
/// follow-up request is worthwhile, and [totalCount] is the source's reported
/// entry count when known.
@immutable
class RemoteTrackPage {
  final List<Track> tracks;

  /// 1-based page number this instance was fetched from.
  final int page;

  /// Whether the source reports another page after this one.
  final bool hasMore;

  /// The source's total entry count (`info.media_count` for Bilibili), falling
  /// back to [tracks]`.length` when the source does not report one.
  final int totalCount;

  const RemoteTrackPage({
    required this.tracks,
    required this.page,
    required this.hasMore,
    required this.totalCount,
  });
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
  ///
  /// [page] is 1-based; the returned [RemoteTrackPage.hasMore] tells callers
  /// whether requesting `page + 1` is worthwhile.
  Future<RemoteTrackPage> playlistTracks(String playlistId, {int page = 1});
}
