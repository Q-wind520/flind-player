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
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/sources/netease/netease_models.dart';

/// Source id stamped onto every NetEase [Track].
const String neteaseSourceId = 'netease';

/// Maps a song DTO to a playable [Track].
Track neteaseSongToTrack(NeteaseSongDto song) => Track(
  source: neteaseSourceId,
  sourceTrackId: NeteaseTrackId(songId: song.id),
  uri: '$neteaseSourceId:${song.id}',
  title: song.name,
  artist: song.artists.isEmpty ? null : song.artists.join(' / '),
  album: song.album.isEmpty ? null : song.album,
  duration: song.durationMs > 0
      ? Duration(milliseconds: song.durationMs)
      : null,
  coverUrl: normalizeNeteaseCoverUrl(song.coverUrl),
);

/// Upgrades protocol-relative/`http://` cover URLs and drops the `?param=`
/// size suffix so the same image hashes to one cache entry.
String? normalizeNeteaseCoverUrl(String? raw) {
  if (raw == null) return null;
  var value = raw.trim();
  if (value.isEmpty) return null;
  if (value.startsWith('//')) {
    value = 'https:$value';
  } else if (value.startsWith('http://')) {
    value = 'https://${value.substring('http://'.length)}';
  }
  if (!value.startsWith('https://')) return null;
  final query = value.indexOf('?');
  return query >= 0 ? value.substring(0, query) : value;
}
