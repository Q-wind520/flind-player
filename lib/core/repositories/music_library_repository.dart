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

/// Persistent music library (unified local + online catalogue).
abstract interface class MusicLibraryRepository {
  /// All tracks currently known to the library.
  Future<List<Track>> allTracks();

  /// Emits the full track list whenever it changes.
  Stream<List<Track>> watchTracks();

  /// Inserts or updates [track], returning its row id.
  Future<int> upsertTrack(Track track);

  /// Deletes the track with [id].
  Future<void> deleteTrack(int id);

  /// Finds a track by its canonical [uri], if present.
  Future<Track?> findByUri(String uri);

  /// The configured local scan roots.
  Future<List<String>> scanRoots();

  /// Registers [path] as a scan root.
  Future<void> addScanRoot(String path);

  /// Removes [path] from the scan roots.
  Future<void> removeScanRoot(String path);
}
