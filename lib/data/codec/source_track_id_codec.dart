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

import 'package:flind_player/core/sources/source_track_id.dart';

/// Canonical persistence mapping for [SourceTrackId].
///
/// Single source of truth shared by the drift repositories and the JSON track
/// codec. Add a new source here once; the drift `if`-chains can no longer
/// silently degrade an unknown source to `LocalTrackId`.
String encodeSourceTrackId(SourceTrackId id) => switch (id) {
  LocalTrackId(:final path) => path,
  BiliTrackId(:final bvid, :final cid) => '$bvid:$cid',
  NeteaseTrackId(:final songId) => '$songId',
};

/// Rebuilds the id from the persisted `source` + `source_track_id` columns.
///
/// An unknown source or a malformed value falls back to a local identity keyed
/// by the canonical [uri] so the row stays usable.
SourceTrackId decodeSourceTrackId(String source, String raw, String uri) {
  if (source == 'local') return LocalTrackId(raw);
  if (source == 'bilibili') {
    final separator = raw.lastIndexOf(':');
    if (separator > 0) {
      final cid = int.tryParse(raw.substring(separator + 1));
      if (cid != null) {
        return BiliTrackId(bvid: raw.substring(0, separator), cid: cid);
      }
    }
  }
  if (source == 'netease') {
    final songId = int.tryParse(raw);
    if (songId != null) return NeteaseTrackId(songId: songId);
  }
  return LocalTrackId(uri);
}

Map<String, dynamic> encodeSourceTrackIdJson(SourceTrackId id) => switch (id) {
  LocalTrackId(:final path) => <String, dynamic>{'kind': 'local', 'path': path},
  BiliTrackId(:final bvid, :final cid) => <String, dynamic>{
    'kind': 'bili',
    'bvid': bvid,
    'cid': cid,
  },
  NeteaseTrackId(:final songId) => <String, dynamic>{
    'kind': 'netease',
    'songId': songId,
  },
};

SourceTrackId decodeSourceTrackIdJson(Object? value) {
  if (value is! Map) {
    throw FormatException('Track.sourceTrackId must be an object, got: $value');
  }
  switch (value['kind']) {
    case 'local':
      final path = value['path'];
      if (path is! String) {
        throw FormatException(
          'Local SourceTrackId.path must be a string, got: $path',
        );
      }
      return LocalTrackId(path);
    case 'bili':
      final bvid = value['bvid'];
      final cid = value['cid'];
      if (bvid is! String || cid is! int) {
        throw FormatException(
          'Bili SourceTrackId requires a string bvid and int cid, '
          'got: bvid=$bvid, cid=$cid',
        );
      }
      return BiliTrackId(bvid: bvid, cid: cid);
    case 'netease':
      final songId = value['songId'];
      if (songId is! int) {
        throw FormatException(
          'Netease SourceTrackId requires an int songId, got: $songId',
        );
      }
      return NeteaseTrackId(songId: songId);
    default:
      throw FormatException('Unknown SourceTrackId kind: ${value['kind']}');
  }
}
