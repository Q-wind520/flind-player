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

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/data/sources/bilibili/rate_limiter.dart';
import 'package:flind_player/data/sources/netease/netease_api.dart';
import 'package:flind_player/data/sources/netease/netease_client.dart';
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

  test('NeteaseSongDto reads the legacy search/get shape', () {
    final dto = NeteaseSongDto.fromJson(<String, dynamic>{
      'id': 9,
      'name': 'Legacy',
      'artists': <dynamic>[
        <String, dynamic>{'name': 'Z'},
      ],
      'album': <String, dynamic>{'name': 'Alb'},
      'duration': 456,
    });

    expect(dto.id, 9);
    expect(dto.name, 'Legacy');
    expect(dto.artists, <String>['Z']);
    expect(dto.album, 'Alb');
    expect(dto.durationMs, 456);
    expect(dto.coverUrl, isNull);
  });

  group('NeteaseApi.searchSongs', () {
    test('uses search/get then enriches via song detail (with covers)', () async {
      final client = _RecordingClient(<String, Map<String, dynamic>>{
        '/weapi/search/get': <String, dynamic>{
          'code': 200,
          'result': <String, dynamic>{
            'songs': <dynamic>[
              <String, dynamic>{'id': 1},
              <String, dynamic>{'id': 2},
            ],
          },
        },
        '/weapi/v3/song/detail': <String, dynamic>{
          'code': 200,
          'songs': <dynamic>[
            <String, dynamic>{
              'id': 1,
              'name': 'A',
              'ar': <dynamic>[
                <String, dynamic>{'name': 'X'},
              ],
              'al': <String, dynamic>{
                'name': 'Al',
                'picUrl': 'https://p1.music.126.net/a.jpg?param=1y1',
              },
              'dt': 1000,
            },
            <String, dynamic>{
              'id': 2,
              'name': 'B',
              'ar': <dynamic>[
                <String, dynamic>{'name': 'Y'},
              ],
              'al': <String, dynamic>{'name': 'Al2', 'picUrl': 'https://p1.music.126.net/b.jpg'},
              'dt': 2000,
            },
          ],
        },
      });
      final api = NeteaseApi(client: client, rateLimiter: _noDelayLimiter());

      final songs = await api.searchSongs('q');

      expect(client.paths, <String>[
        '/weapi/search/get?csrf_token=',
        '/weapi/v3/song/detail?csrf_token=',
      ]);
      expect((client.bodies.last['c'] as String), contains('"id":1'));
      expect(songs.map((s) => s.name), <String>['A', 'B']);
      expect(songs.first.coverUrl, 'https://p1.music.126.net/a.jpg?param=1y1');
    });

    test('falls back to the raw search shape when detail is empty', () async {
      final client = _RecordingClient(<String, Map<String, dynamic>>{
        '/weapi/search/get': <String, dynamic>{
          'code': 200,
          'result': <String, dynamic>{
            'songs': <dynamic>[
              <String, dynamic>{
                'id': 7,
                'name': 'Raw',
                'artists': <dynamic>[
                  <String, dynamic>{'name': 'Z'},
                ],
                'album': <String, dynamic>{'name': 'Alb'},
                'duration': 1234,
              },
            ],
          },
        },
        '/weapi/v3/song/detail': <String, dynamic>{
          'code': 200,
          'songs': <dynamic>[],
        },
      });
      final api = NeteaseApi(client: client, rateLimiter: _noDelayLimiter());

      final songs = await api.searchSongs('q');

      expect(songs.single.name, 'Raw');
      expect(songs.single.artists, <String>['Z']);
      expect(songs.single.durationMs, 1234);
      expect(songs.single.coverUrl, isNull);
    });
  });
}

RateLimiter _noDelayLimiter() =>
    RateLimiter(minInterval: Duration.zero, maxInterval: Duration.zero);

/// Records `postWeapi` calls and answers from a canned path→json map.
class _RecordingClient extends NeteaseClient {
  _RecordingClient(this.responses) : super(dio: Dio());

  final Map<String, Map<String, dynamic>> responses;
  final List<String> paths = <String>[];
  final List<Map<String, dynamic>> bodies = <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>> postWeapi(
    String path,
    Map<String, dynamic> body,
  ) async {
    paths.add(path);
    bodies.add(body);
    for (final entry in responses.entries) {
      if (path.startsWith(entry.key)) return entry.value;
    }
    throw StateError('no canned response for $path');
  }
}
