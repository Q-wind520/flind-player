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
import 'package:flind_player/core/sources/music_source.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/sources/netease/netease_api.dart';
import 'package:flind_player/data/sources/netease/netease_models.dart';
import 'package:flind_player/data/sources/netease/netease_source.dart';

class _FakeApi implements NeteaseApi {
  _FakeApi({this.songs = const <NeteaseSongDto>[], this.url, this.lyric});

  final List<NeteaseSongDto> songs;
  final NeteaseUrlDto? url;
  final NeteaseLyricDto? lyric;

  @override
  Future<List<NeteaseSongDto>> searchSongs(String query, {int page = 1}) async => songs;

  @override
  Future<NeteaseSongDto?> songDetail(int songId) async => songs.isEmpty ? null : songs.first;

  @override
  Future<NeteaseUrlDto?> songUrl(int songId) async => url;

  @override
  Future<NeteaseLyricDto> songLyric(int songId) async =>
      lyric ?? const NeteaseLyricDto();
}

const _song = NeteaseSongDto(id: 42, name: 'T', artists: <String>['A'], album: 'Al', durationMs: 1000);

void main() {
  test('search maps songs to tracks', () async {
    final source = NeteaseSource(api: _FakeApi(songs: const <NeteaseSongDto>[_song]));
    final tracks = await source.search('q');
    expect(tracks, hasLength(1));
    expect(tracks.single.uri, 'netease:42');
  });

  test('resolveStream returns the URL and quality', () async {
    final source = NeteaseSource(
      api: _FakeApi(
        url: const NeteaseUrlDto(url: 'https://m8.music.126.net/x.mp3', level: 'standard'),
      ),
    );
    final info = await source.resolveStream(
      const Track(
        source: 'netease',
        sourceTrackId: NeteaseTrackId(songId: 42),
        uri: 'netease:42',
        title: 'T',
      ),
    );
    expect(info.url, Uri.parse('https://m8.music.126.net/x.mp3'));
    expect(info.qualityId, 'standard');
    expect(info.headers['Referer'], 'https://music.163.com');
  });

  test('resolveStream upgrades a NetEase CDN http stream to https', () async {
    final source = NeteaseSource(
      api: _FakeApi(
        url: const NeteaseUrlDto(
          url: 'http://m801.music.126.net/x.mp3?auth=1',
          level: 'standard',
        ),
      ),
    );
    final info = await source.resolveStream(
      const Track(
        source: 'netease',
        sourceTrackId: NeteaseTrackId(songId: 42),
        uri: 'netease:42',
        title: 'T',
      ),
    );
    // Android blocks cleartext http by default; the CDN serves https too.
    expect(info.url.scheme, 'https');
    expect(info.url.host, 'm801.music.126.net');
    expect(info.url.query, 'auth=1');
  });

  test('resolveStream throws when the song has no stream (VIP/region)', () async {
    final source = NeteaseSource(api: _FakeApi(url: const NeteaseUrlDto()));
    expect(
      () => source.resolveStream(
        const Track(
          source: 'netease',
          sourceTrackId: NeteaseTrackId(songId: 42),
          uri: 'netease:42',
          title: 'T',
        ),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('lyricsFor parses original and translation', () async {
    final source = NeteaseSource(
      api: _FakeApi(
        lyric: const NeteaseLyricDto(
          lrc: '[00:01.00]原文',
          translation: '[00:01.00]translated',
        ),
      ),
    );
    final lyric = await source.lyricsFor(
      const Track(
        source: 'netease',
        sourceTrackId: NeteaseTrackId(songId: 42),
        uri: 'netease:42',
        title: 'T',
      ),
    );
    expect(lyric!.lines.single.text, '原文');
    expect(lyric.lines.single.translation, 'translated');
  });

  test('lyricsFor returns null for pure music', () async {
    final source = NeteaseSource(
      api: _FakeApi(lyric: const NeteaseLyricDto(lrc: '[99:00.00]纯音乐，请欣赏')),
    );
    expect(
      await source.lyricsFor(
        const Track(
          source: 'netease',
          sourceTrackId: NeteaseTrackId(songId: 42),
          uri: 'netease:42',
          title: 'T',
        ),
      ),
      isNull,
    );
  });

  test('capabilities advertise search and streamDirect only', () {
    final source = NeteaseSource(api: _FakeApi());
    expect(source.capabilities.supports(SourceCapability.search), isTrue);
    expect(source.capabilities.supports(SourceCapability.streamDirect), isTrue);
    expect(source.capabilities.supports(SourceCapability.login), isFalse);
  });

  test('fetchTrack rejects a foreign SourceTrackId with ArgumentError', () async {
    final source = NeteaseSource(api: _FakeApi(songs: const <NeteaseSongDto>[_song]));
    await expectLater(
      source.fetchTrack(const BiliTrackId(bvid: 'BV1', cid: 1)),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('fetchTrack throws StateError when the API returns no song', () async {
    final source = NeteaseSource(api: _FakeApi());
    await expectLater(
      source.fetchTrack(const NeteaseTrackId(songId: 42)),
      throwsA(isA<StateError>()),
    );
  });

  test('resolveStream rejects a foreign id with UnsupportedError', () async {
    final source = NeteaseSource(api: _FakeApi(url: const NeteaseUrlDto(url: 'https://x')));
    await expectLater(
      source.resolveStream(
        const Track(
          source: 'bilibili',
          sourceTrackId: BiliTrackId(bvid: 'BV1', cid: 1),
          uri: 'bilibili:BV1:1',
          title: 'T',
        ),
      ),
      throwsA(isA<UnsupportedError>()),
    );
  });

  test('resolveStream throws StateError when the DTO url is empty', () async {
    final source = NeteaseSource(api: _FakeApi(url: const NeteaseUrlDto(url: '')));
    await expectLater(
      source.resolveStream(
        const Track(
          source: 'netease',
          sourceTrackId: NeteaseTrackId(songId: 42),
          uri: 'netease:42',
          title: 'T',
        ),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('lyricsFor returns null for a foreign id', () async {
    final source = NeteaseSource(
      api: _FakeApi(lyric: const NeteaseLyricDto(lrc: '[00:01.00]原文')),
    );
    expect(
      await source.lyricsFor(
        const Track(
          source: 'bilibili',
          sourceTrackId: BiliTrackId(bvid: 'BV1', cid: 1),
          uri: 'bilibili:BV1:1',
          title: 'T',
        ),
      ),
      isNull,
    );
  });
}
