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

import 'package:flind_player/core/models/lyric.dart';
import 'package:flind_player/core/models/track.dart';

/// Fetches lyrics for a track from one online source.
///
/// Implementations return `null` when the source has no lyrics for the track;
/// a missing lyric is not an error.
abstract interface class LyricsProvider {
  Future<Lyric?> lyricsFor(Track track);
}
