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

import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/codec/track_codec.dart';

void main() {
  group('encodeTrack / decodeTrack', () {
    test('round-trips every field of a local track', () {
      const track = Track(
        id: 42,
        source: 'local',
        sourceTrackId: LocalTrackId('/music/song.flac'),
        uri: 'local:/music/song.flac',
        title: 'Song',
        artist: 'Artist',
        album: 'Album',
        albumArtist: 'Album Artist',
        trackNo: 3,
        discNo: 1,
        year: 2024,
        duration: Duration(milliseconds: 215000),
        bitrate: 320000,
        sampleRate: 44100,
        genre: 'Rock',
        coverPath: '/covers/abc.webp',
      );

      final decoded = decodeTrack(encodeTrack(track));

      expect(decoded, track);
      expect(decoded.id, 42);
      expect(decoded.sourceTrackId, const LocalTrackId('/music/song.flac'));
      expect(decoded.duration, const Duration(milliseconds: 215000));
    });

    test('round-trips every field of a bilibili track', () {
      const track = Track(
        id: 7,
        source: 'bilibili',
        sourceTrackId: BiliTrackId(bvid: 'BV1GJ411x7h7', cid: 137649199),
        uri: 'bilibili:BV1GJ411x7h7:137649199',
        title: 'Online Track',
        artist: 'Uploader',
        album: 'Video',
        duration: Duration(seconds: 180),
        coverPath: '/covers/online.webp',
      );

      final decoded = decodeTrack(encodeTrack(track));

      expect(decoded, track);
      expect(
        decoded.sourceTrackId,
        const BiliTrackId(bvid: 'BV1GJ411x7h7', cid: 137649199),
      );
    });

    test('encodes the sourceTrackId as a tagged discriminator', () {
      const track = Track(
        source: 'bilibili',
        sourceTrackId: BiliTrackId(bvid: 'BV1', cid: 2),
        uri: 'bilibili:BV1:2',
        title: 'T',
      );

      final json = encodeTrack(track);

      expect(json['sourceTrackId'], {'kind': 'bili', 'bvid': 'BV1', 'cid': 2});
    });

    test('round-trips a track whose optional fields are null', () {
      const track = Track(
        source: 'local',
        sourceTrackId: LocalTrackId('/music/min.mp3'),
        uri: 'local:/music/min.mp3',
        title: 'Minimal',
      );

      final decoded = decodeTrack(encodeTrack(track));

      expect(decoded, track);
      expect(decoded.artist, isNull);
      expect(decoded.duration, isNull);
    });

    test('throws FormatException for an unknown sourceTrackId kind', () {
      final json = encodeTrack(
        const Track(
          source: 'local',
          sourceTrackId: LocalTrackId('/music/song.flac'),
          uri: 'local:/music/song.flac',
          title: 'Song',
        ),
      );
      (json['sourceTrackId']! as Map<String, dynamic>)['kind'] = 'mystery';

      expect(() => decodeTrack(json), throwsFormatException);
    });

    test('throws FormatException for a missing sourceTrackId', () {
      final json = encodeTrack(
        const Track(
          source: 'local',
          sourceTrackId: LocalTrackId('/music/song.flac'),
          uri: 'local:/music/song.flac',
          title: 'Song',
        ),
      );
      json.remove('sourceTrackId');

      expect(() => decodeTrack(json), throwsFormatException);
    });
  });

  group('encodeTracks / decodeTracks', () {
    test('round-trips a list, preserving order', () {
      final tracks = <Track>[
        const Track(
          source: 'local',
          sourceTrackId: LocalTrackId('/m/a.flac'),
          uri: 'local:/m/a.flac',
          title: 'A',
        ),
        const Track(
          source: 'bilibili',
          sourceTrackId: BiliTrackId(bvid: 'BV1', cid: 2),
          uri: 'bilibili:BV1:2',
          title: 'B',
        ),
      ];

      final decoded = decodeTracks(encodeTracks(tracks));

      expect(decoded, tracks);
    });

    test('round-trips an empty list', () {
      expect(decodeTracks(encodeTracks(const [])), isEmpty);
    });
  });
}
