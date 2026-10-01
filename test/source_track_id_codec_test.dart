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

import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/codec/source_track_id_codec.dart';

void main() {
  group('encodeSourceTrackId / decodeSourceTrackId', () {
    test('round-trips a netease id through the source column', () {
      expect(encodeSourceTrackId(const NeteaseTrackId(songId: 123)), '123');
      expect(
        decodeSourceTrackId('netease', '123', 'netease:123'),
        const NeteaseTrackId(songId: 123),
      );
    });

    test('round-trips bilibili and local ids', () {
      expect(
        encodeSourceTrackId(const BiliTrackId(bvid: 'BV1', cid: 2)),
        'BV1:2',
      );
      expect(
        decodeSourceTrackId('bilibili', 'BV1:2', 'bilibili:BV1:2'),
        const BiliTrackId(bvid: 'BV1', cid: 2),
      );
      expect(encodeSourceTrackId(const LocalTrackId('/m/a.mp3')), '/m/a.mp3');
      expect(
        decodeSourceTrackId('local', '/m/a.mp3', 'local:/m/a.mp3'),
        const LocalTrackId('/m/a.mp3'),
      );
    });

    test('falls back to a uri-keyed local id for an unknown source', () {
      expect(
        decodeSourceTrackId('spotify', 'x', 'spotify:1'),
        const LocalTrackId('spotify:1'),
      );
      expect(
        decodeSourceTrackId('netease', 'not-a-number', 'netease:x'),
        const LocalTrackId('netease:x'),
      );
    });
  });

  group('JSON codec', () {
    test('encodes netease as a tagged object and round-trips', () {
      final json = encodeSourceTrackIdJson(const NeteaseTrackId(songId: 7));
      expect(json, <String, dynamic>{'kind': 'netease', 'songId': 7});
      expect(decodeSourceTrackIdJson(json), const NeteaseTrackId(songId: 7));
    });

    test('throws for an unknown kind', () {
      expect(
        () => decodeSourceTrackIdJson(<String, dynamic>{'kind': 'mystery'}),
        throwsFormatException,
      );
    });
  });
}
