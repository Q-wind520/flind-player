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

import 'package:flind_player/data/sources/bilibili/bili_subtitles.dart';

void main() {
  test('parseBiliSubtitleBody converts timed lines', () {
    final lyric = parseBiliSubtitleBody(<String, dynamic>{
      'body': <Map<String, dynamic>>[
        <String, dynamic>{'from': 1.25, 'to': 3.0, 'content': 'first'},
        <String, dynamic>{'from': 3.0, 'to': 5.5, 'content': 'second'},
      ],
    });

    expect(lyric, isNotNull);
    expect(lyric!.lines, hasLength(2));
    expect(lyric.lines.first.timestamp, const Duration(milliseconds: 1250));
    expect(lyric.lines.first.text, 'first');
    expect(lyric.lines.last.timestamp, const Duration(milliseconds: 3000));
  });

  test('parseBiliSubtitleBody skips blank and non-object entries', () {
    final lyric = parseBiliSubtitleBody(<String, dynamic>{
      'body': <dynamic>[
        <String, dynamic>{'from': 0, 'to': 1, 'content': '  '},
        <String, dynamic>{'from': 'bad', 'to': 1, 'content': 'bad time'},
        <String, dynamic>{'from': 2, 'to': 3, 'content': 'kept'},
        'not a map',
      ],
    });

    expect(lyric?.lines, hasLength(1));
    expect(lyric?.lines.single.text, 'kept');
  });

  test('parseBiliSubtitleBody returns null for an empty body', () {
    expect(parseBiliSubtitleBody(<String, dynamic>{}), isNull);
    expect(
      parseBiliSubtitleBody(<String, dynamic>{'body': <dynamic>[]}),
      isNull,
    );
  });

  test('BiliSubtitleTrackDto falls back to subtitle_url_v2', () {
    final track = BiliSubtitleTrackDto.fromJson(<String, dynamic>{
      'lan': 'zh-Hans',
      'lan_doc': 'Chinese',
      'subtitle_url': '/',
      'subtitle_url_v2': 'https://aisubtitle.hdslb.com/v2.json',
    });

    expect(track.url, 'https://aisubtitle.hdslb.com/v2.json');
  });

  test(
    'selectBiliSubtitleTrack prefers Simplified Chinese and skips empty urls',
    () {
      final selected = selectBiliSubtitleTrack(const <BiliSubtitleTrackDto>[
        BiliSubtitleTrackDto(lan: 'en-US', lanDoc: 'English', url: '//en'),
        BiliSubtitleTrackDto(lan: 'ai-zh', lanDoc: 'AI Chinese', url: ''),
        BiliSubtitleTrackDto(lan: 'zh-Hans', lanDoc: 'Chinese', url: '//zh'),
      ]);

      expect(selected?.lan, 'zh-Hans');
    },
  );

  test('selectBiliSubtitleTrack falls back to the first usable track', () {
    final selected = selectBiliSubtitleTrack(const <BiliSubtitleTrackDto>[
      BiliSubtitleTrackDto(lan: 'en-US', lanDoc: 'English', url: '//en'),
      BiliSubtitleTrackDto(lan: 'zh-CN', lanDoc: 'Chinese', url: ''),
    ]);

    expect(selected?.lan, 'en-US');
  });
}
