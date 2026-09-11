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
///
/// Tracks are soft-deleted: a row whose `missingAt` is set has disappeared from
/// its source but is retained for playlists/stats. [allTracks], [watchTracks]
/// and [searchTracks] must exclude such rows.
abstract interface class MusicLibraryRepository {
  /// All tracks currently known to the library, excluding soft-deleted rows.
  Future<List<Track>> allTracks();

  /// Emits the full track list whenever it changes, excluding soft-deleted
  /// rows.
  Stream<List<Track>> watchTracks();

  /// Full-text search across title/artist/album, excluding soft-deleted rows.
  ///
  /// A blank/empty [query] returns an empty list. The query is treated as a
  /// set of whitespace-separated terms; the last term is prefix-matched.
  Future<List<Track>> searchTracks(String query, {int limit = 100});

  /// Inserts or updates [track], returning its row id.
  Future<int> upsertTrack(Track track);

  /// Inserts or updates every track in [tracks] within a single transaction.
  ///
  /// Intended for library scanning; conflicts are resolved on `uri` with the
  /// same `createdAt`/`updatedAt` semantics as [upsertTrack].
  Future<void> upsertTracks(List<Track> tracks);

  /// Deletes the track with [id].
  Future<void> deleteTrack(int id);

  /// Finds a track by its canonical [uri], if present.
  Future<Track?> findByUri(String uri);

  /// Every known `uri` for [source], including soft-deleted rows.
  ///
  /// This is the diff input for a scan: it must keep reporting rows that were
  /// marked missing so a returning file is restored rather than re-inserted.
  Future<Set<String>> trackUrisForSource(String source);

  /// Marks tracks of [source] that are not in [seenUris] as missing and clears
  /// the missing marker for those that are present.
  ///
  /// Returns the number of rows newly marked missing. An empty [seenUris] is a
  /// deliberate no-op: a failed or empty scan must never mark the whole
  /// library missing.
  Future<int> markMissingExcept(String source, Set<String> seenUris);

  /// The configured local scan roots.
  Future<List<String>> scanRoots();

  /// Registers [path] as a scan root.
  Future<void> addScanRoot(String path);

  /// Removes [path] from the scan roots.
  Future<void> removeScanRoot(String path);
}
