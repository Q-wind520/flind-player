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

import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/sources/local/local_stream_resolver.dart';

/// Reads embedded metadata from a local audio file into a [Track].
class LocalMetadataReader {
  /// Parses [filePath], or returns `null` when the file is missing,
  /// unsupported, or otherwise unreadable. Never throws.
  Future<Track?> readTrack(String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        debugPrint('LocalMetadataReader: file not found: $filePath');
        return null;
      }

      // Fast path: skip embedded images (docs/local-library.md §2.3).
      final metadata = readMetadata(file, getImage: false);

      final title = metadata.title?.trim();
      return Track(
        source: 'local',
        sourceTrackId: LocalTrackId(filePath),
        uri: LocalStreamResolver.uriForPath(filePath),
        title: (title == null || title.isEmpty)
            ? p.basenameWithoutExtension(filePath)
            : title,
        artist: metadata.artist,
        album: metadata.album,
        albumArtist: metadata.albumArtist,
        trackNo: metadata.trackNumber,
        discNo: metadata.discNumber,
        year: _yearOf(metadata.year),
        duration: metadata.duration,
        bitrate: metadata.bitrate,
        sampleRate: metadata.sampleRate,
        genre: metadata.genres.isEmpty ? null : metadata.genres.first,
      );
    } catch (error) {
      debugPrint('LocalMetadataReader: failed to read $filePath: $error');
      return null;
    }
  }

  /// The MP3 parser reports `DateTime(0)` when no year tag is present; treat
  /// it (and other non-positive years) as unknown rather than storing `0`.
  int? _yearOf(DateTime? date) {
    if (date == null || date.year <= 0) {
      return null;
    }
    return date.year;
  }
}
