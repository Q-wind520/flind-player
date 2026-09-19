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
import 'package:flind_player/core/models/track_sort.dart';
import 'package:flind_player/data/sources/local/local_library_scanner.dart';

/// Persistent music library (unified local + online catalogue).
///
/// Tracks are soft-deleted: a row whose `missingAt` is set has disappeared from
/// its source but is retained for playlists/stats. [allTracks], [watchTracks]
/// and [searchTracks] must exclude such rows.
abstract interface class MusicLibraryRepository {
  /// All tracks currently known to the library, excluding soft-deleted rows,
  /// ordered by [sort].
  Future<List<Track>> allTracks({TrackSort sort = TrackSort.title});

  /// Emits the full track list whenever it changes, excluding soft-deleted
  /// rows, ordered by [sort].
  Stream<List<Track>> watchTracks({TrackSort sort = TrackSort.title});

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

  /// Inserts or updates every scanned [tracks] entry in a single transaction,
  /// persisting each track's `(sizeBytes, mtimeMs, scanRoot)` fingerprint in
  /// addition to the metadata written by [upsertTracks].
  Future<void> upsertScannedTracks(List<ScannedTrack> tracks);

  /// Deletes the track with [id].
  Future<void> deleteTrack(int id);

  /// Finds a track by its canonical [uri], if present.
  Future<Track?> findByUri(String uri);

  /// Updates the cached cover pointer of an existing track, identified by its
  /// canonical [uri].
  ///
  /// A no-op when no row carries [uri]: cover resolution must never create a
  /// library entry for a track the user did not save. Only the cover columns
  /// are touched, so `updatedAt` is refreshed but nothing else changes.
  Future<void> updateTrackCover(
    String uri, {
    String? coverPath,
    String? coverUrl,
  });

  /// Every known `uri` for [source], including soft-deleted rows.
  ///
  /// This is the diff input for a scan: it must keep reporting rows that were
  /// marked missing so a returning file is restored rather than re-inserted.
  Future<Set<String>> trackUrisForSource(String source);

  /// The stored file fingerprints for [source], keyed by `uri`, including
  /// soft-deleted rows.
  ///
  /// This is the incremental-scan diff input: the scanner skips a discovered
  /// file only when its `sizeBytes` and `mtimeMs` both match. Fields are
  /// nullable for rows written before schema v5, which forces one re-parse.
  Future<Map<String, FileFingerprint>> trackFingerprints(String source);

  /// Marks tracks of [source] that are not in [seenUris] as missing and clears
  /// the missing marker for those that are present.
  ///
  /// Returns the number of rows newly marked missing.
  ///
  /// Two guards keep a partial scan from wiping a good library:
  ///
  /// 1. An empty [seenUris] is a deliberate no-op: a failed or empty scan must
  ///    never mark the whole library missing.
  /// 2. When [roots] is provided, a track attributed to a scan root *outside*
  ///    [roots] is left untouched, so an unmounted drive keeps its tracks.
  ///    Tracks with no recorded `scanRoot` (individually imported files, or
  ///    rows written before schema v5) stay eligible, since they are not tied
  ///    to any root that could be offline.
  Future<int> markMissingExcept(
    String source,
    Set<String> seenUris, {
    Set<String>? roots,
  });

  /// The configured local scan roots.
  Future<List<String>> scanRoots();

  /// Registers [path] as a scan root.
  Future<void> addScanRoot(String path);

  /// Removes [path] from the scan roots.
  Future<void> removeScanRoot(String path);
}
