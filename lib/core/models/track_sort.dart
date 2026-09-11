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

/// Ordering options for the unified track list.
///
/// The repository maps each value to a deterministic `ORDER BY`; title, artist
/// and album are compared case-insensitively and use the row id as a stable
/// tiebreaker so pagination-free lists never reshuffle between reads.
enum TrackSort {
  /// Title, case-insensitive A -> Z. The default.
  title,

  /// Artist, case-insensitive A -> Z; tracks with no artist sort last.
  artist,

  /// Album, case-insensitive A -> Z; tracks with no album sort last.
  album,

  /// Most recently added first (`createdAt` descending).
  recentlyAdded,
}
