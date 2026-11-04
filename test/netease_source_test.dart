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
import 'package:flind_player/data/auth/auth_cookie_jar.dart';
import 'package:flind_player/data/sources/netease/netease_api.dart';
import 'package:flind_player/data/sources/netease/netease_models.dart';
import 'package:flind_player/data/sources/netease/netease_source.dart';

class _FakeApi implements NeteaseApi {
  _FakeApi({this.songs = const <NeteaseSongDto>[], this.url, this.lyric});

  final List<NeteaseSongDto> songs;
  final NeteaseUrlDto? url;
  final NeteaseLyricDto? lyric;
  String? requestedLevel;
  String? failingLevel;

  List<NeteasePlaylistDto> playlists = const <NeteasePlaylistDto>[];
  NeteasePlaylistDetailDto? playlist;
  List<NeteaseSongDto> recommended = const <NeteaseSongDto>[];
  Set<int> likedIds = <int>{};
  int? likedSongId;
  bool? likedValue;
  NeteaseArtistDto? artistData;
  List<NeteaseAlbumDto> albums = const <NeteaseAlbumDto>[];
  NeteaseAlbumDetailDto? albumData;

  @override
  Future<List<NeteaseSongDto>> searchSongs(
    String query, {
    int page = 1,
  }) async => songs;

  @override
  Future<NeteaseSongDto?> songDetail(int songId) async =>
      songs.isEmpty ? null : songs.first;

  @override
  Future<NeteaseUrlDto?> songUrl(
    int songId, {
    String level = 'standard',
  }) async {
    requestedLevel = level;
    if (level == failingLevel) throw StateError('tier unavailable');
    return url;
  }

  @override
  Future<NeteaseLyricDto> songLyric(int songId) async =>
      lyric ?? const NeteaseLyricDto();

  @override
  Future<List<NeteaseAlbumDto>> searchAlbums(
    String query, {
    int page = 1,
  }) async => albums;

  @override
  Future<List<NeteaseArtistDto>> searchArtists(
    String query, {
    int page = 1,
  }) async => artistData == null
      ? const <NeteaseArtistDto>[]
      : <NeteaseArtistDto>[artistData!];

  @override
  Future<List<NeteasePlaylistDto>> highQualityPlaylists({
    String cat = '全部',
    int limit = 30,
  }) async => playlists;

  @override
  Future<List<NeteasePlaylistDto>> userPlaylists(
    int userId, {
    int limit = 1000,
    int offset = 0,
  }) async => playlists;

  @override
  Future<List<NeteasePlaylistDto>> recommendedPlaylists({
    int limit = 30,
  }) async => playlists;

  @override
  Future<List<NeteaseSongDto>> recommendedSongs() async => recommended;

  @override
  Future<NeteasePlaylistDetailDto?> playlistDetail(int playlistId) async =>
      playlist;

  @override
  Future<Set<int>> likedSongIds(int userId) async => likedIds;

  @override
  Future<void> setLiked(int songId, bool liked) async {
    likedSongId = songId;
    likedValue = liked;
  }

  @override
  Future<NeteaseArtistDto?> artistDetail(int artistId) async => artistData;

  @override
  Future<List<NeteaseAlbumDto>> artistAlbums(
    int artistId, {
    int limit = 50,
    int offset = 0,
  }) async => albums;

  @override
  Future<List<NeteaseSongDto>> artistSongs(
    int artistId, {
    int limit = 100,
    int offset = 0,
  }) async => songs;

  @override
  Future<NeteaseAlbumDetailDto?> albumDetail(int albumId) async => albumData;
}

const _song = NeteaseSongDto(
  id: 42,
  name: 'T',
  artists: <String>['A'],
  album: 'Al',
  durationMs: 1000,
);

void main() {
  test('search maps songs to tracks', () async {
    final source = NeteaseSource(
      api: _FakeApi(songs: const <NeteaseSongDto>[_song]),
    );
    final tracks = await source.search('q');
    expect(tracks, hasLength(1));
    expect(tracks.single.uri, 'netease:42');
  });

  test('resolveStream returns the URL and quality', () async {
    final source = NeteaseSource(
      api: _FakeApi(
        url: const NeteaseUrlDto(
          url: 'https://m8.music.126.net/x.mp3',
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

  test('a signed-in source asks for the exhigh tier', () async {
    final jar = AuthCookieJar()
      ..replace('netease', const <String, String>{'MUSIC_U': 'token'});
    final api = _FakeApi(
      url: const NeteaseUrlDto(
        url: 'https://m8.music.126.net/x.mp3',
        level: 'exhigh',
      ),
    );
    final source = NeteaseSource(api: api, cookieJar: jar);

    final info = await source.resolveStream(
      const Track(
        source: 'netease',
        sourceTrackId: NeteaseTrackId(songId: 42),
        uri: 'netease:42',
        title: 'T',
      ),
    );

    expect(api.requestedLevel, 'exhigh');
    expect(info.qualityId, 'exhigh');
  });

  test('a signed-in source falls back to standard when exhigh fails', () async {
    final jar = AuthCookieJar()
      ..replace('netease', const <String, String>{'MUSIC_U': 'token'});
    final api = _FakeApi(
      url: const NeteaseUrlDto(
        url: 'https://m8.music.126.net/x.mp3',
        level: 'standard',
      ),
    )..failingLevel = 'exhigh';
    final source = NeteaseSource(api: api, cookieJar: jar);

    final info = await source.resolveStream(
      const Track(
        source: 'netease',
        sourceTrackId: NeteaseTrackId(songId: 42),
        uri: 'netease:42',
        title: 'T',
      ),
    );

    expect(api.requestedLevel, 'standard');
    expect(info.qualityId, 'standard');
  });

  test(
    'resolveStream throws when the song has no stream (VIP/region)',
    () async {
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
    },
  );

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

  test('capabilities advertise search, streamDirect and login', () {
    final source = NeteaseSource(api: _FakeApi());
    expect(source.capabilities.supports(SourceCapability.search), isTrue);
    expect(source.capabilities.supports(SourceCapability.streamDirect), isTrue);
    expect(source.capabilities.supports(SourceCapability.login), isTrue);
  });

  test(
    'fetchTrack rejects a foreign SourceTrackId with ArgumentError',
    () async {
      final source = NeteaseSource(
        api: _FakeApi(songs: const <NeteaseSongDto>[_song]),
      );
      await expectLater(
        source.fetchTrack(const BiliTrackId(bvid: 'BV1', cid: 1)),
        throwsA(isA<ArgumentError>()),
      );
    },
  );

  test('fetchTrack throws StateError when the API returns no song', () async {
    final source = NeteaseSource(api: _FakeApi());
    await expectLater(
      source.fetchTrack(const NeteaseTrackId(songId: 42)),
      throwsA(isA<StateError>()),
    );
  });

  test('resolveStream rejects a foreign id with UnsupportedError', () async {
    final source = NeteaseSource(
      api: _FakeApi(url: const NeteaseUrlDto(url: 'https://x')),
    );
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
    final source = NeteaseSource(
      api: _FakeApi(url: const NeteaseUrlDto(url: '')),
    );
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

  test('playlists and playlist tracks map to generic remote models', () async {
    final api = _FakeApi()
      ..playlists = const <NeteasePlaylistDto>[
        NeteasePlaylistDto(
          id: 7,
          name: 'Mix',
          coverUrl: 'https://x/c.jpg',
          trackCount: 2,
        ),
      ]
      ..playlist = const NeteasePlaylistDetailDto(
        playlist: NeteasePlaylistDto(id: 7, name: 'Mix'),
        songs: <NeteaseSongDto>[_song],
      );
    final source = NeteaseSource(api: api);

    final playlists = await source.playlistsForUser('42');
    expect(playlists.single.id, '7');
    expect(playlists.single.title, 'Mix');
    expect(playlists.single.trackCount, 2);

    final page = await source.playlistTracks('7');
    expect(page.tracks.single.uri, 'netease:42');
    expect(page.hasMore, isFalse);
  });

  test('recommendations map playlists and songs', () async {
    final api = _FakeApi()
      ..playlists = const <NeteasePlaylistDto>[
        NeteasePlaylistDto(id: 9, name: 'Daily'),
      ]
      ..recommended = const <NeteaseSongDto>[_song];
    final source = NeteaseSource(api: api);

    expect((await source.recommendedPlaylists()).single.id, '9');
    expect((await source.popularPlaylists()).single.id, '9');
    expect((await source.recommendedSongs()).single.uri, 'netease:42');
  });

  test('artist and album pages map metadata and tracks', () async {
    final api = _FakeApi(songs: const <NeteaseSongDto>[_song])
      ..artistData = const NeteaseArtistDto(
        id: 5,
        name: 'Artist',
        avatarUrl: 'https://x/a.jpg',
        albumCount: 3,
      )
      ..albums = const <NeteaseAlbumDto>[
        NeteaseAlbumDto(
          id: 11,
          name: 'Album',
          artist: 'Artist',
          trackCount: 1,
          publishTime: 1700000000000,
        ),
      ]
      ..albumData = const NeteaseAlbumDetailDto(
        album: NeteaseAlbumDto(id: 11, name: 'Album'),
        songs: <NeteaseSongDto>[_song],
      );
    final source = NeteaseSource(api: api);

    final artist = await source.artist('5');
    expect(artist?.name, 'Artist');
    expect(artist?.albumCount, 3);

    final albums = await source.artistAlbums('5');
    expect(albums.single.id, '11');
    expect(albums.single.artist, 'Artist');

    expect((await source.artistSongs('5')).tracks.single.uri, 'netease:42');
    expect((await source.albumTracks('11')).tracks.single.uri, 'netease:42');
    expect((await source.album('11'))?.title, 'Album');
  });

  test('album and artist search map to remote models', () async {
    final api = _FakeApi()
      ..albums = const <NeteaseAlbumDto>[NeteaseAlbumDto(id: 11, name: 'Album')]
      ..artistData = const NeteaseArtistDto(id: 5, name: 'Artist');
    final source = NeteaseSource(api: api);

    expect((await source.searchAlbums('x')).single.id, '11');
    expect((await source.searchArtists('x')).single.name, 'Artist');
  });

  test('like state maps ids and forwards setLiked', () async {
    final api = _FakeApi()..likedIds = <int>{42, 43};
    final source = NeteaseSource(api: api);

    expect(await source.likedTrackIds('7'), {'42', '43'});
    await source.setLiked('42', true);
    expect(api.likedSongId, 42);
    expect(api.likedValue, isTrue);
  });
}
