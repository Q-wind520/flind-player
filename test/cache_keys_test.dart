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
import 'package:flind_player/data/cache/cache_keys.dart';

void main() {
  test('cacheSourceTrackId returns the song id string for a netease track', () {
    const track = Track(
      source: 'netease',
      sourceTrackId: NeteaseTrackId(songId: 123),
      uri: 'netease:123',
      title: 'T',
    );

    expect(cacheSourceTrackId(track), '123');
  });

  test('cacheSourceTrackId keeps the local path and bvid:cid conventions', () {
    const local = Track(
      source: 'local',
      sourceTrackId: LocalTrackId('/m/a.mp3'),
      uri: 'local:/m/a.mp3',
      title: 'L',
    );
    const bili = Track(
      source: 'bilibili',
      sourceTrackId: BiliTrackId(bvid: 'BV1', cid: 2),
      uri: 'bilibili:BV1:2',
      title: 'B',
    );

    expect(cacheSourceTrackId(local), '/m/a.mp3');
    expect(cacheSourceTrackId(bili), 'BV1:2');
  });
}
