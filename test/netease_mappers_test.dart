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
import 'package:flind_player/data/sources/netease/netease_mappers.dart';
import 'package:flind_player/data/sources/netease/netease_models.dart';

void main() {
  test('maps a song DTO to a Track', () {
    final track = neteaseSongToTrack(
      const NeteaseSongDto(
        id: 123,
        name: 'Song',
        artists: <String>['A', 'B'],
        album: 'Album',
        durationMs: 215000,
        coverUrl: 'https://p1.music.126.net/a.jpg?param=300y300',
      ),
    );

    expect(track.source, 'netease');
    expect(track.uri, 'netease:123');
    expect(track.sourceTrackId, const NeteaseTrackId(songId: 123));
    expect(track.title, 'Song');
    expect(track.artist, 'A / B');
    expect(track.album, 'Album');
    expect(track.duration, const Duration(milliseconds: 215000));
    expect(track.coverUrl, 'https://p1.music.126.net/a.jpg');
  });

  test('empty artist/album/cover become null/absent', () {
    final track = neteaseSongToTrack(
      const NeteaseSongDto(id: 1, name: 'N', artists: <String>[], album: '', durationMs: 0),
    );
    expect(track.artist, isNull);
    expect(track.album, isNull);
    expect(track.duration, isNull);
    expect(track.coverUrl, isNull);
  });

  test('normalizeNeteaseCoverUrl upgrades and strips the size suffix', () {
    expect(normalizeNeteaseCoverUrl('//p1.music.126.net/a.jpg?param=1y1'), 'https://p1.music.126.net/a.jpg');
    expect(normalizeNeteaseCoverUrl('http://p1.music.126.net/a.jpg'), 'https://p1.music.126.net/a.jpg');
    expect(normalizeNeteaseCoverUrl(''), isNull);
    expect(normalizeNeteaseCoverUrl('/relative.jpg'), isNull);
  });
}
