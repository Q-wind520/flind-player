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

/// Sorts [tracks] client-side using the same comparators as the server-side
/// library sort.
///
/// Used for the favourites list, which is too small to warrant a DB
/// round-trip. Returns a new list; [tracks] is left untouched.
List<Track> sortFavouriteTracks(List<Track> tracks, TrackSort sort) {
  final sorted = List<Track>.from(tracks);
  sorted.sort((a, b) {
    return switch (sort) {
      TrackSort.title => a.title.toLowerCase().compareTo(
        b.title.toLowerCase(),
      ),
      TrackSort.artist => _compareNullable(
        a.artist?.toLowerCase(),
        b.artist?.toLowerCase(),
      ),
      TrackSort.album => _compareNullable(
        a.album?.toLowerCase(),
        b.album?.toLowerCase(),
      ),
      // The repository already orders members by `added_at DESC`; `Track.id` is
      // the pool row id and does NOT track when the song was favourited, so
      // leave the incoming order untouched.
      TrackSort.recentlyAdded => 0,
    };
  });
  return sorted;
}

int _compareNullable(String? a, String? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1; // nulls last
  if (b == null) return -1;
  return a.compareTo(b);
}
