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
import 'package:flind_player/data/auth/auth_cookie_jar.dart';
import 'package:flind_player/data/sources/bilibili/bili_api.dart';
import 'package:flind_player/data/sources/bilibili/bili_client.dart';
import 'package:flind_player/data/sources/bilibili/bili_source.dart';
import 'package:flind_player/data/sources/bilibili/bili_subtitles.dart';
import 'package:flind_player/data/sources/bilibili/rate_limiter.dart';
import 'package:flind_player/data/sources/bilibili/risk_control.dart';
import 'package:flind_player/data/sources/bilibili/wbi_signer.dart';

class _FakeBiliApi extends BiliApi {
  _FakeBiliApi()
    : super(
        client: BiliClient(),
        signer: WbiSigner(
          fetchKeys: () async => (imgKey: 'img', subKey: 'sub'),
        ),
        rateLimiter: RateLimiter(
          minInterval: Duration.zero,
          maxInterval: Duration.zero,
        ),
        riskControl: RiskControl(client: BiliClient()),
      );

  int subtitleCalls = 0;
  int bodyCalls = 0;
  List<BiliSubtitleTrackDto> tracks = const <BiliSubtitleTrackDto>[];
  Map<String, dynamic> body = const <String, dynamic>{};

  @override
  Future<List<BiliSubtitleTrackDto>> playerSubtitles({
    required String bvid,
    required int cid,
  }) async {
    subtitleCalls++;
    return tracks;
  }

  @override
  Future<Map<String, dynamic>> subtitleBody(String rawUrl) async {
    bodyCalls++;
    return body;
  }
}

const _track = Track(
  source: 'bilibili',
  sourceTrackId: BiliTrackId(bvid: 'BV1', cid: 10),
  uri: 'bilibili:BV1:10',
  title: 'T',
);

void main() {
  test('lyricsFor parses the selected CC track and caches it', () async {
    final api = _FakeBiliApi()
      ..tracks = const <BiliSubtitleTrackDto>[
        BiliSubtitleTrackDto(
          lan: 'zh-Hans',
          lanDoc: 'Chinese',
          url: '//aisubtitle.hdslb.com/zh.json',
        ),
      ]
      ..body = <String, dynamic>{
        'body': <Map<String, dynamic>>[
          <String, dynamic>{'from': 1.0, 'to': 2.0, 'content': 'line'},
        ],
      };
    final source = BiliSource(api: api);

    final first = await source.lyricsFor(_track);
    final second = await source.lyricsFor(_track);

    expect(first?.lines.single.text, 'line');
    expect(second, same(first));
    expect(api.subtitleCalls, 1);
    expect(api.bodyCalls, 1);
  });

  test('an anonymous source skips the subtitle request', () async {
    final api = _FakeBiliApi();
    final source = BiliSource(api: api, cookieJar: AuthCookieJar());

    expect(await source.lyricsFor(_track), isNull);
    expect(api.subtitleCalls, 0);
  });

  test('lyricsFor returns null when the video has no subtitle track', () async {
    final api = _FakeBiliApi();
    final source = BiliSource(api: api);

    expect(await source.lyricsFor(_track), isNull);
    expect(api.subtitleCalls, 1);
    expect(api.bodyCalls, 0);
  });
}
