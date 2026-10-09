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
import 'package:gal/gal.dart';

import 'package:flind_player/data/services/cover_original_resolver.dart';

/// The outcome of saving a cover image.
enum CoverSaveResult { saved, cancelled, failed }

/// Persists a resolved cover to the platform's destination.
abstract class CoverSaver {
  /// Saves [original]; never throws — failures become [CoverSaveResult.failed].
  Future<CoverSaveResult> save(CoverOriginal original);
}

/// Saves into the system photo album (Android / iOS).
class AlbumCoverSaver implements CoverSaver {
  const AlbumCoverSaver();

  @override
  Future<CoverSaveResult> save(CoverOriginal original) async {
    try {
      if (!await Gal.hasAccess()) {
        if (!await Gal.requestAccess()) return CoverSaveResult.failed;
      }
      await Gal.putImageBytes(original.bytes, name: original.suggestedName);
      return CoverSaveResult.saved;
    } catch (_) {
      return CoverSaveResult.failed;
    }
  }
}

/// Saves through the native file-save dialog (desktop).
///
/// [FilePicker.saveFile] writes [CoverOriginal.bytes] to the chosen path and
/// returns its URI, or null when the user cancels.
class FileCoverSaver implements CoverSaver {
  const FileCoverSaver();

  @override
  Future<CoverSaveResult> save(CoverOriginal original) async {
    try {
      final uri = await FilePicker.saveFile(
        fileName: original.suggestedName,
        bytes: original.bytes,
        mimeType: original.mimeType,
      );
      return uri == null ? CoverSaveResult.cancelled : CoverSaveResult.saved;
    } catch (_) {
      return CoverSaveResult.failed;
    }
  }
}
