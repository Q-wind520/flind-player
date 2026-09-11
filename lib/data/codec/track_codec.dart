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

/// JSON codec for the domain [Track].
///
/// The domain model stays serialization-free; this data-layer codec is the
/// single place that knows the persisted shape. The sealed [SourceTrackId] is
/// encoded as a tagged object so a corrupt or future row fails loudly instead
/// of silently degrading to a wrong identity.
///
/// Example encodings:
/// ```json
/// {"kind": "local", "path": "/music/song.flac"}
/// {"kind": "bili", "bvid": "BV1GJ411x7h7", "cid": 137649199}
/// ```
Map<String, dynamic> encodeTrack(Track track) {
  return <String, dynamic>{
    'id': track.id,
    'source': track.source,
    'sourceTrackId': _encodeSourceTrackId(track.sourceTrackId),
    'uri': track.uri,
    'title': track.title,
    'artist': track.artist,
    'album': track.album,
    'albumArtist': track.albumArtist,
    'trackNo': track.trackNo,
    'discNo': track.discNo,
    'year': track.year,
    'durationMs': track.duration?.inMilliseconds,
    'bitrate': track.bitrate,
    'sampleRate': track.sampleRate,
    'genre': track.genre,
    'coverPath': track.coverPath,
  };
}

/// Rebuilds a [Track] from its JSON form produced by [encodeTrack].
///
/// Throws [FormatException] for a missing/mistyped required field or an unknown
/// [SourceTrackId] discriminator.
Track decodeTrack(Map<String, dynamic> json) {
  return Track(
    id: _asIntOrNull(json['id']),
    source: _asString(json['source'], 'source'),
    sourceTrackId: _decodeSourceTrackId(json['sourceTrackId']),
    uri: _asString(json['uri'], 'uri'),
    title: _asString(json['title'], 'title'),
    artist: _asStringOrNull(json['artist'], 'artist'),
    album: _asStringOrNull(json['album'], 'album'),
    albumArtist: _asStringOrNull(json['albumArtist'], 'albumArtist'),
    trackNo: _asIntOrNull(json['trackNo']),
    discNo: _asIntOrNull(json['discNo']),
    year: _asIntOrNull(json['year']),
    duration: _asDurationOrNull(json['durationMs']),
    bitrate: _asIntOrNull(json['bitrate']),
    sampleRate: _asIntOrNull(json['sampleRate']),
    genre: _asStringOrNull(json['genre'], 'genre'),
    coverPath: _asStringOrNull(json['coverPath'], 'coverPath'),
  );
}

/// Encodes a list of tracks, preserving order.
List<Map<String, dynamic>> encodeTracks(List<Track> tracks) {
  return tracks.map(encodeTrack).toList(growable: false);
}

/// Decodes a JSON list produced by [encodeTracks], preserving order.
List<Track> decodeTracks(List<dynamic> json) {
  return json
      .map((entry) {
        if (entry is! Map) {
          throw FormatException('Track entry must be an object, got: $entry');
        }
        return decodeTrack(Map<String, dynamic>.from(entry));
      })
      .toList(growable: false);
}

Map<String, dynamic> _encodeSourceTrackId(SourceTrackId id) {
  return switch (id) {
    LocalTrackId(:final path) => <String, dynamic>{
      'kind': 'local',
      'path': path,
    },
    BiliTrackId(:final bvid, :final cid) => <String, dynamic>{
      'kind': 'bili',
      'bvid': bvid,
      'cid': cid,
    },
  };
}

SourceTrackId _decodeSourceTrackId(Object? value) {
  if (value is! Map) {
    throw FormatException('Track.sourceTrackId must be an object, got: $value');
  }

  final kind = value['kind'];
  switch (kind) {
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
    default:
      throw FormatException('Unknown SourceTrackId kind: $kind');
  }
}

String _asString(Object? value, String field) {
  if (value is String) return value;
  throw FormatException('Track.$field must be a string, got: $value');
}

String? _asStringOrNull(Object? value, String field) {
  if (value == null) return null;
  if (value is String) return value;
  throw FormatException('Track.$field must be a string or null, got: $value');
}

int? _asIntOrNull(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  throw FormatException('Expected an integer or null, got: $value');
}

Duration? _asDurationOrNull(Object? value) {
  final millis = _asIntOrNull(value);
  return millis == null ? null : Duration(milliseconds: millis);
}
