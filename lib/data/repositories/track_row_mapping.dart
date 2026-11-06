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
import 'package:flind_player/data/codec/source_track_id_codec.dart';
import 'package:flind_player/data/database/app_database.dart';

/// Maps a `tracks` row to the domain [Track].
///
/// Shared by every repository that joins the pool (library, playlists,
/// playback stats) so the field mapping cannot drift between call sites.
Track trackFromRow(TrackRow row) {
  return Track(
    id: row.id,
    source: row.source,
    sourceTrackId: decodeSourceTrackId(row.source, row.sourceTrackId, row.uri),
    uri: row.uri,
    title: row.title,
    artist: row.artist,
    album: row.album,
    albumArtist: row.albumArtist,
    trackNo: row.trackNo,
    discNo: row.discNo,
    year: row.year,
    duration: row.durationMs == null
        ? null
        : Duration(milliseconds: row.durationMs!),
    bitrate: row.bitrate,
    sampleRate: row.sampleRate,
    genre: row.genre,
    coverPath: row.coverPath,
    coverUrl: row.coverUrl,
  );
}
