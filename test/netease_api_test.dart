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

import 'package:flind_player/data/sources/netease/netease_models.dart';

void main() {
  test('NeteaseSongDto reads cloudsearch fields', () {
    final dto = NeteaseSongDto.fromJson(<String, dynamic>{
      'id': 123,
      'name': 'Song',
      'ar': <dynamic>[
        <String, dynamic>{'name': 'A'},
        <String, dynamic>{'name': 'B'},
      ],
      'al': <String, dynamic>{'name': 'Album', 'picUrl': 'https://p1.music.126.net/a.jpg?param=300y300'},
      'dt': 215000,
    });

    expect(dto.id, 123);
    expect(dto.name, 'Song');
    expect(dto.artists, <String>['A', 'B']);
    expect(dto.album, 'Album');
    expect(dto.durationMs, 215000);
    expect(dto.coverUrl, 'https://p1.music.126.net/a.jpg?param=300y300');
  });

  test('NeteaseSongDto tolerates missing optional fields', () {
    final dto = NeteaseSongDto.fromJson(<String, dynamic>{'id': 1, 'name': 'N'});
    expect(dto.artists, isEmpty);
    expect(dto.album, '');
    expect(dto.durationMs, 0);
    expect(dto.coverUrl, isNull);
  });

  test('NeteaseUrlDto reads url/level', () {
    final dto = NeteaseUrlDto.fromJson(<String, dynamic>{
      'url': 'https://m8.music.126.net/x.mp3',
      'br': 128000,
      'level': 'standard',
      'type': 'mp3',
    });
    expect(dto.url, 'https://m8.music.126.net/x.mp3');
    expect(dto.level, 'standard');
  });

  test('NeteaseLyricDto reads lrc/tlyric/romalrc', () {
    final dto = NeteaseLyricDto.fromJson(<String, dynamic>{
      'lrc': <String, dynamic>{'lyric': '[00:01.00]a'},
      'tlyric': <String, dynamic>{'lyric': '[00:01.00]A'},
      'romalrc': <String, dynamic>{'lyric': '[00:01.00]a'},
    });
    expect(dto.lrc, '[00:01.00]a');
    expect(dto.translation, '[00:01.00]A');
    expect(dto.roma, '[00:01.00]a');
  });
}
