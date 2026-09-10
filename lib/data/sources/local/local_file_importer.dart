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

import 'package:file_picker/file_picker.dart';

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/data/sources/local/local_metadata_reader.dart';

/// Lets the user pick local audio files and parses their metadata.
class LocalFileImporter {
  LocalFileImporter(this._metadataReader);

  final LocalMetadataReader _metadataReader;

  /// Opens the platform audio picker and returns one [Track] per readable
  /// file. Returns an empty list when the user cancels or selects nothing.
  Future<List<Track>> pickAndImport() async {
    // file_picker 12 exposes `pickFiles` as a static returning the selected
    // files directly (empty list on cancel); multi-select is the default.
    final files = await FilePicker.pickFiles(type: FileType.audio);
    if (files.isEmpty) {
      return const [];
    }

    final tracks = <Track>[];
    for (final file in files) {
      final path = file.path;
      if (path == null) {
        continue;
      }
      final track = await _metadataReader.readTrack(path);
      if (track != null) {
        tracks.add(track);
      }
    }
    return tracks;
  }
}
