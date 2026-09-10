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
import 'package:flind_player/data/sources/bilibili/bili_mappers.dart';
import 'package:flind_player/data/sources/bilibili/bili_models.dart';

void main() {
  group('stripHtml', () {
    test('removes tags', () {
      expect(stripHtml('<em class="keyword">Hello</em> World'), 'Hello World');
    });

    test('decodes named entities', () {
      expect(stripHtml('Rock &amp; Roll &lt;3'), 'Rock & Roll <3');
    });

    test('decodes numeric entities', () {
      expect(stripHtml('A&#39;B&#x4E2D;'), "A'B中");
    });

    test('trims surrounding whitespace', () {
      expect(stripHtml('  spaced  '), 'spaced');
    });
  });

  group('searchItemToTrack', () {
    test('maps bvid/title/author and a placeholder cid', () {
      const item = SearchItemDto(
        bvid: 'BV1GJ411x7h7',
        title: '<em class="keyword">Never</em> Gonna Give You Up',
        author: 'Rick Astley',
        duration: Duration(minutes: 3, seconds: 33),
      );

      final track = searchItemToTrack(item);

      expect(track.source, 'bilibili');
      expect(track.title, 'Never Gonna Give You Up');
      expect(track.artist, 'Rick Astley');
      expect(track.duration, const Duration(minutes: 3, seconds: 33));
      expect(track.coverPath, isNull);
      expect(track.uri, 'bilibili:BV1GJ411x7h7:-1');
      expect(
        track.sourceTrackId,
        const BiliTrackId(bvid: 'BV1GJ411x7h7', cid: -1),
      );
    });

    test('leaves artist null when the search author is empty', () {
      const item = SearchItemDto(bvid: 'BV1', title: 'Solo', author: '');

      expect(searchItemToTrack(item).artist, isNull);
    });
  });

  group('videoPageToTrack', () {
    const video = VideoInfoDto(
      bvid: 'BV1uv411q7Mv',
      title: 'Full Album',
      ownerName: 'Some Artist',
      durationSeconds: 600,
      pages: <VideoPageDto>[
        VideoPageDto(cid: 111, page: 1, part: 'Intro', durationSeconds: 90),
        VideoPageDto(
          cid: 222,
          page: 2,
          part: '<em>Track</em> Two',
          durationSeconds: 210,
        ),
      ],
    );

    test('uses the part title for a multi-part video', () {
      final track = videoPageToTrack(video, video.pages[1]);

      expect(track.title, 'Track Two');
      expect(track.album, 'Full Album');
      expect(track.artist, 'Some Artist');
      expect(track.duration, const Duration(seconds: 210));
      expect(track.uri, 'bilibili:BV1uv411q7Mv:222');
      expect(
        track.sourceTrackId,
        const BiliTrackId(bvid: 'BV1uv411q7Mv', cid: 222),
      );
    });

    test('uses the video title for a single-part video', () {
      const single = VideoInfoDto(
        bvid: 'BV1single',
        title: 'A Song',
        ownerName: 'Artist',
        pages: <VideoPageDto>[
          VideoPageDto(cid: 999, page: 1, part: 'P1', durationSeconds: 180),
        ],
      );

      final track = videoPageToTrack(single, single.pages.first);

      expect(track.title, 'A Song');
      expect(track.album, 'A Song');
      expect(track.uri, 'bilibili:BV1single:999');
    });

    test('falls back to the video duration when the page duration is zero', () {
      const single = VideoInfoDto(
        bvid: 'BV1x',
        title: 'A Song',
        ownerName: 'Artist',
        durationSeconds: 240,
        pages: <VideoPageDto>[
          VideoPageDto(cid: 1, page: 1, part: '', durationSeconds: 0),
        ],
      );

      expect(
        videoPageToTrack(single, single.pages.first).duration,
        const Duration(seconds: 240),
      );
    });
  });

  group('DTO parsing', () {
    test('parses a search duration string', () {
      final item = SearchItemDto.fromJson(<String, dynamic>{
        'bvid': 'BV1',
        'title': 'x',
        'author': 'y',
        'duration': '4:32',
      });

      expect(item.duration, const Duration(minutes: 4, seconds: 32));
    });

    test('parses an hh:mm:ss search duration', () {
      final item = SearchItemDto.fromJson(<String, dynamic>{
        'bvid': 'BV1',
        'title': 'x',
        'author': 'y',
        'duration': '1:02:03',
      });

      expect(item.duration, const Duration(hours: 1, minutes: 2, seconds: 3));
    });

    test('parses camelCase DASH audio fields', () {
      final audio = DashAudioDto.fromJson(<String, dynamic>{
        'id': 30280,
        'baseUrl': 'https://cdn/audio.m4s',
        'backupUrl': <String>['https://backup/audio.m4s'],
        'bandwidth': 203786,
        'mimeType': 'audio/mp4',
        'codecs': 'mp4a.40.2',
        'size': 1234,
      });

      expect(audio.id, 30280);
      expect(audio.baseUrl, 'https://cdn/audio.m4s');
      expect(audio.backupUrl, <String>['https://backup/audio.m4s']);
      expect(audio.bandwidth, 203786);
      expect(audio.mimeType, 'audio/mp4');
      expect(audio.codecs, 'mp4a.40.2');
      expect(audio.size, 1234);
    });

    test('parses video pages and owner', () {
      final video = VideoInfoDto.fromJson(<String, dynamic>{
        'bvid': 'BV1',
        'title': 'Title',
        'owner': <String, dynamic>{'name': 'Owner'},
        'duration': 300,
        'pages': <dynamic>[
          <String, dynamic>{
            'cid': 7,
            'page': 1,
            'part': 'Part',
            'duration': 300,
          },
        ],
      });

      expect(video.bvid, 'BV1');
      expect(video.ownerName, 'Owner');
      expect(video.durationSeconds, 300);
      expect(video.pages, hasLength(1));
      expect(video.pages.first.cid, 7);
      expect(video.pages.first.part, 'Part');
    });
  });
}
