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

import 'package:flind_player/data/sources/bilibili/bili_models.dart';

void main() {
  group('SearchItemDto.coverUrl', () {
    test('keeps a protocol-relative pic value verbatim', () {
      final dto = SearchItemDto.fromJson(<String, dynamic>{
        'bvid': 'BV1',
        'title': '<em class="keyword">t</em>',
        'author': 'a',
        'pic': '//i0.hdslb.com/bfs/archive/abc.jpg@480w_270h_1c.webp',
      });

      // The exact raw string, suffix included - no `//` handling here.
      expect(
        dto.coverUrl,
        '//i0.hdslb.com/bfs/archive/abc.jpg@480w_270h_1c.webp',
      );
    });

    test('keeps an https pic with a query string verbatim', () {
      final dto = SearchItemDto.fromJson(<String, dynamic>{
        'pic': 'https://i1.hdslb.com/bfs/archive/x.jpg?foo=1&bar=2',
      });

      expect(
        dto.coverUrl,
        'https://i1.hdslb.com/bfs/archive/x.jpg?foo=1&bar=2',
      );
    });

    test('maps an empty pic to null', () {
      expect(
        SearchItemDto.fromJson(<String, dynamic>{'pic': ''}).coverUrl,
        isNull,
      );
    });

    test('maps an absent pic to null', () {
      expect(SearchItemDto.fromJson(<String, dynamic>{}).coverUrl, isNull);
    });

    test('maps a null pic to null', () {
      expect(
        SearchItemDto.fromJson(<String, dynamic>{'pic': null}).coverUrl,
        isNull,
      );
    });

    test('maps a numeric pic to null without throwing', () {
      expect(
        SearchItemDto.fromJson(<String, dynamic>{'pic': 123}).coverUrl,
        isNull,
      );
    });

    test('maps a map pic to null without throwing', () {
      expect(
        SearchItemDto.fromJson(<String, dynamic>{
          'pic': <String, dynamic>{'url': 'https://x/y.jpg'},
        }).coverUrl,
        isNull,
      );
    });
  });

  group('VideoInfoDto.coverUrl', () {
    test('keeps a protocol-relative pic value verbatim', () {
      final dto = VideoInfoDto.fromJson(<String, dynamic>{
        'bvid': 'BV1uv411q7Mv',
        'title': 'Full Album',
        'owner': <String, dynamic>{'name': 'Some Artist'},
        'pic': '//i2.hdslb.com/bfs/archive/view.jpg@480w_270h_1c.webp',
      });

      expect(
        dto.coverUrl,
        '//i2.hdslb.com/bfs/archive/view.jpg@480w_270h_1c.webp',
      );
    });

    test('keeps an https pic with a query string verbatim', () {
      final dto = VideoInfoDto.fromJson(<String, dynamic>{
        'pic': 'https://i0.hdslb.com/bfs/archive/v.jpg?sign=abc&t=1',
      });

      expect(
        dto.coverUrl,
        'https://i0.hdslb.com/bfs/archive/v.jpg?sign=abc&t=1',
      );
    });

    test('maps an empty pic to null', () {
      expect(VideoInfoDto.fromJson(<String, dynamic>{'pic': ''}).coverUrl, isNull);
    });

    test('maps an absent pic to null', () {
      expect(VideoInfoDto.fromJson(<String, dynamic>{}).coverUrl, isNull);
    });

    test('maps a null pic to null', () {
      expect(
        VideoInfoDto.fromJson(<String, dynamic>{'pic': null}).coverUrl,
        isNull,
      );
    });

    test('maps a numeric pic to null without throwing', () {
      expect(
        VideoInfoDto.fromJson(<String, dynamic>{'pic': 42}).coverUrl,
        isNull,
      );
    });

    test('maps a map pic to null without throwing', () {
      expect(
        VideoInfoDto.fromJson(<String, dynamic>{
          'pic': <String, dynamic>{'url': 'https://x/y.jpg'},
        }).coverUrl,
        isNull,
      );
    });

    test('still parses the existing fields alongside the cover', () {
      final dto = VideoInfoDto.fromJson(<String, dynamic>{
        'bvid': 'BV1',
        'title': 'T',
        'owner': <String, dynamic>{'name': 'A'},
        'duration': 600,
        'pic': '//i0.hdslb.com/a.jpg',
        'pages': <dynamic>[
          <String, dynamic>{
            'cid': 1,
            'page': 1,
            'part': 'P1',
            'duration': 90,
          },
        ],
      });

      expect(dto.bvid, 'BV1');
      expect(dto.title, 'T');
      expect(dto.ownerName, 'A');
      expect(dto.durationSeconds, 600);
      expect(dto.pages, hasLength(1));
      expect(dto.coverUrl, '//i0.hdslb.com/a.jpg');
    });
  });

  group('normalizeCoverUrl', () {
    test('upgrades a protocol-relative URL to https', () {
      expect(
        normalizeCoverUrl('//i0.hdslb.com/bfs/a.jpg'),
        'https://i0.hdslb.com/bfs/a.jpg',
      );
    });

    test('upgrades an http URL to https', () {
      expect(
        normalizeCoverUrl('http://i0.hdslb.com/bfs/a.jpg'),
        'https://i0.hdslb.com/bfs/a.jpg',
      );
    });

    test('strips an existing CDN size suffix', () {
      expect(
        normalizeCoverUrl('https://i0.hdslb.com/bfs/a.jpg@672w_378h_1c.webp'),
        'https://i0.hdslb.com/bfs/a.jpg',
      );
    });

    test('returns null for absent or blank values', () {
      expect(normalizeCoverUrl(null), isNull);
      expect(normalizeCoverUrl(''), isNull);
      expect(normalizeCoverUrl('   '), isNull);
    });
  });
}
