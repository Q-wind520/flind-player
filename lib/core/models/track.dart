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

import 'package:flind_player/core/sources/source_track_id.dart';

/// A single track in the unified library.
///
/// [uri] is the canonical, source-namespaced key
/// (`local:/abs/path` or `bilibili:BV...:cid`).
@immutable
class Track {
  /// Database row id, `null` before the track is inserted.
  final int? id;

  /// Source identifier, `local` or `bilibili`.
  final String source;

  /// Source-specific identity.
  final SourceTrackId sourceTrackId;

  /// Canonical source-namespaced uri.
  final String uri;

  final String title;
  final String? artist;
  final String? album;
  final String? albumArtist;
  final int? trackNo;
  final int? discNo;
  final int? year;
  final Duration? duration;

  /// Bitrate in bits per second.
  final int? bitrate;

  /// Sample rate in Hz.
  final int? sampleRate;
  final String? genre;

  /// Path to the locally cached cover file, if any.
  final String? coverPath;

  /// Remote cover URL for display (e.g. a Bilibili `pic` link), if any.
  ///
  /// Volatile display metadata: deliberately **excluded** from [==] and
  /// [hashCode], exactly like [coverPath]. Playback persistence detects queue
  /// changes with `listEquals` over `List<Track>`, so a track whose cover URL
  /// merely became known must not mark the queue as changed and trigger a
  /// rewrite of the persisted snapshot.
  final String? coverUrl;

  const Track({
    this.id,
    required this.source,
    required this.sourceTrackId,
    required this.uri,
    required this.title,
    this.artist,
    this.album,
    this.albumArtist,
    this.trackNo,
    this.discNo,
    this.year,
    this.duration,
    this.bitrate,
    this.sampleRate,
    this.genre,
    this.coverPath,
    this.coverUrl,
  });

  /// Returns a copy with the given fields replaced.
  ///
  /// Nullable fields keep their current value when omitted.
  Track copyWith({
    int? id,
    String? source,
    SourceTrackId? sourceTrackId,
    String? uri,
    String? title,
    String? artist,
    String? album,
    String? albumArtist,
    int? trackNo,
    int? discNo,
    int? year,
    Duration? duration,
    int? bitrate,
    int? sampleRate,
    String? genre,
    String? coverPath,
    String? coverUrl,
  }) {
    return Track(
      id: id ?? this.id,
      source: source ?? this.source,
      sourceTrackId: sourceTrackId ?? this.sourceTrackId,
      uri: uri ?? this.uri,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumArtist: albumArtist ?? this.albumArtist,
      trackNo: trackNo ?? this.trackNo,
      discNo: discNo ?? this.discNo,
      year: year ?? this.year,
      duration: duration ?? this.duration,
      bitrate: bitrate ?? this.bitrate,
      sampleRate: sampleRate ?? this.sampleRate,
      genre: genre ?? this.genre,
      coverPath: coverPath ?? this.coverPath,
      coverUrl: coverUrl ?? this.coverUrl,
    );
  }

  // Display-only metadata (coverPath, coverUrl) is intentionally absent: the
  // playback persistence service compares queues with `listEquals`, and a
  // newly resolved cover must never look like a queue change. The player UI
  // still refreshes on a cover change because `PlaybackState ==` compares
  // `currentTrack.coverPath` explicitly.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Track &&
          other.id == id &&
          other.source == source &&
          other.sourceTrackId == sourceTrackId &&
          other.uri == uri &&
          other.title == title &&
          other.artist == artist &&
          other.album == album &&
          other.albumArtist == albumArtist &&
          other.trackNo == trackNo &&
          other.discNo == discNo &&
          other.year == year &&
          other.duration == duration &&
          other.bitrate == bitrate &&
          other.sampleRate == sampleRate &&
          other.genre == genre;

  @override
  int get hashCode => Object.hash(
    id,
    source,
    sourceTrackId,
    uri,
    title,
    artist,
    album,
    albumArtist,
    trackNo,
    discNo,
    year,
    duration,
    bitrate,
    sampleRate,
    genre,
  );

  @override
  String toString() =>
      'Track(id: $id, source: $source, uri: $uri, title: $title)';
}
