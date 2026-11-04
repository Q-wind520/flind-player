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

import 'dart:convert';

import 'package:flind_player/data/sources/bilibili/rate_limiter.dart';
import 'package:flind_player/data/sources/netease/netease_client.dart';
import 'package:flind_player/data/sources/netease/netease_models.dart';

/// Typed access to the NetEase endpoints the adapter needs.
class NeteaseApi {
  static const String _searchPath = '/weapi/search/get?csrf_token=';
  static const String _detailPath = '/weapi/v3/song/detail?csrf_token=';
  static const String _urlPath = '/song/enhance/player/url/v1';
  static const String _lyricPath = '/weapi/song/lyric?csrf_token=';
  static const String _playlistDetailPath =
      '/weapi/v3/playlist/detail?csrf_token=';
  static const String _userPlaylistsPath = '/weapi/user/playlist?csrf_token=';
  static const String _recommendedPlaylistsPath =
      '/weapi/personalized/playlist?csrf_token=';
  static const String _recommendedSongsPath =
      '/weapi/v3/discovery/recommend/songs?csrf_token=';
  static const String _likedIdsPath = '/weapi/song/like/get?csrf_token=';
  static const String _likePath = '/weapi/song/like?csrf_token=';

  /// Page size used by the search client.
  static const int searchPageSize = 30;

  final NeteaseClient _client;
  final RateLimiter _rateLimiter;

  NeteaseApi({required NeteaseClient client, required RateLimiter rateLimiter})
    : _client = client, // ignore: prefer_initializing_formals
      _rateLimiter = rateLimiter; // ignore: prefer_initializing_formals

  /// Searches songs and returns canonical metadata (with cover art).
  ///
  /// `/weapi/cloudsearch/get/web` is rejected by the server with code
  /// `50000005`, so search uses `/weapi/search/get` and then enriches the
  /// results through `/weapi/v3/song/detail` (which carries `al.picUrl`).
  /// `search/get` alone has no cover URL; if the enrichment is empty the raw
  /// search rows are returned so search still works without artwork.
  Future<List<NeteaseSongDto>> searchSongs(String query, {int page = 1}) async {
    final json = await _rateLimiter.run(
      () => _client.postWeapi(_searchPath, <String, dynamic>{
        's': query,
        'type': 1,
        'limit': searchPageSize,
        'offset': (page - 1) * searchPageSize,
        'total': true,
        'csrf_token': '',
      }),
    );
    final result = json['result'];
    final songs = result is Map ? result['songs'] : null;
    if (songs is! List) return const <NeteaseSongDto>[];

    final raw = songs
        .whereType<Map>()
        .map((e) => NeteaseSongDto.fromJson(Map<String, dynamic>.from(e)))
        .where((song) => song.id > 0)
        .toList(growable: false);
    if (raw.isEmpty) return const <NeteaseSongDto>[];

    final enriched = await _songDetails(
      raw.map((song) => song.id).toList(growable: false),
    );
    return enriched.isNotEmpty ? enriched : raw;
  }

  /// Fetches canonical songs for [ids], preserving the requested order.
  Future<List<NeteaseSongDto>> _songDetails(List<int> ids) async {
    if (ids.isEmpty) return const <NeteaseSongDto>[];
    final json = await _rateLimiter.run(
      () => _client.postWeapi(_detailPath, <String, dynamic>{
        'c': jsonEncode(<dynamic>[
          for (final id in ids) <String, dynamic>{'id': id},
        ]),
      }),
    );
    final songs = json['songs'];
    if (songs is! List) return const <NeteaseSongDto>[];
    final byId = <int, NeteaseSongDto>{};
    for (final entry in songs.whereType<Map>()) {
      final dto = NeteaseSongDto.fromJson(Map<String, dynamic>.from(entry));
      if (dto.id > 0) byId[dto.id] = dto;
    }
    return <NeteaseSongDto>[
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  Future<NeteaseSongDto?> songDetail(int songId) async {
    final songs = await _songDetails(<int>[songId]);
    return songs.isEmpty ? null : songs.first;
  }

  Future<NeteaseUrlDto?> songUrl(
    int songId, {
    String level = 'standard',
  }) async {
    final json = await _rateLimiter.run(
      () => _client.postEapi(_urlPath, <String, dynamic>{
        'ids': '[$songId]',
        'level': level,
        'encodeType': 'flac',
      }),
    );
    final data = json['data'];
    if (data is! List || data.isEmpty) return null;
    final first = data.first;
    if (first is! Map) return null;
    return NeteaseUrlDto.fromJson(Map<String, dynamic>.from(first));
  }

  Future<NeteaseLyricDto> songLyric(int songId) async {
    final json = await _rateLimiter.run(
      () => _client.postWeapi(_lyricPath, <String, dynamic>{
        'id': songId,
        'lv': -1,
        'tv': -1,
        'rv': -1,
        'kv': -1,
        'csrf_token': '',
      }),
    );
    return NeteaseLyricDto.fromJson(json);
  }

  /// Album search (`type: 10`).
  Future<List<NeteaseAlbumDto>> searchAlbums(
    String query, {
    int page = 1,
  }) async {
    final json = await _rateLimiter.run(
      () => _client.postWeapi(_searchPath, <String, dynamic>{
        's': query,
        'type': 10,
        'limit': searchPageSize,
        'offset': (page - 1) * searchPageSize,
        'total': true,
        'csrf_token': '',
      }),
    );
    final result = json['result'];
    final albums = result is Map ? result['albums'] : null;
    if (albums is! List) return const <NeteaseAlbumDto>[];
    return albums
        .whereType<Map>()
        .map((e) => NeteaseAlbumDto.fromJson(Map<String, dynamic>.from(e)))
        .where((album) => album.id > 0)
        .toList(growable: false);
  }

  /// Artist search (`type: 100`).
  Future<List<NeteaseArtistDto>> searchArtists(
    String query, {
    int page = 1,
  }) async {
    final json = await _rateLimiter.run(
      () => _client.postWeapi(_searchPath, <String, dynamic>{
        's': query,
        'type': 100,
        'limit': searchPageSize,
        'offset': (page - 1) * searchPageSize,
        'total': true,
        'csrf_token': '',
      }),
    );
    final result = json['result'];
    final artists = result is Map ? result['artists'] : null;
    if (artists is! List) return const <NeteaseArtistDto>[];
    return artists
        .whereType<Map>()
        .map((e) => NeteaseArtistDto.fromJson(Map<String, dynamic>.from(e)))
        .where((artist) => artist.id > 0)
        .toList(growable: false);
  }

  /// The signed-in user's playlists (including subscribed ones).
  Future<List<NeteasePlaylistDto>> userPlaylists(
    int userId, {
    int limit = 1000,
    int offset = 0,
  }) async {
    final json = await _rateLimiter.run(
      () => _client.postWeapi(_userPlaylistsPath, <String, dynamic>{
        'uid': '$userId',
        'offset': '$offset',
        'limit': '$limit',
        'includeVideo': 'true',
        'csrf_token': '',
      }),
    );
    final playlists = json['playlist'];
    if (playlists is! List) return const <NeteasePlaylistDto>[];
    return playlists
        .whereType<Map>()
        .map((e) => NeteasePlaylistDto.fromJson(Map<String, dynamic>.from(e)))
        .where((playlist) => playlist.id > 0)
        .toList(growable: false);
  }

  /// Personalised playlists. NetEase serves a useful anonymous list too.
  Future<List<NeteasePlaylistDto>> recommendedPlaylists({
    int limit = 30,
  }) async {
    final json = await _rateLimiter.run(
      () => _client.postWeapi(_recommendedPlaylistsPath, <String, dynamic>{
        'limit': '$limit',
        'csrf_token': '',
      }),
    );
    final result = json['result'];
    if (result is! List) return const <NeteasePlaylistDto>[];
    return result
        .whereType<Map>()
        .map((e) => NeteasePlaylistDto.fromJson(Map<String, dynamic>.from(e)))
        .where((playlist) => playlist.id > 0)
        .toList(growable: false);
  }

  /// Daily recommended songs (requires a signed-in account).
  Future<List<NeteaseSongDto>> recommendedSongs() async {
    final json = await _rateLimiter.run(
      () => _client.postWeapi(_recommendedSongsPath, <String, dynamic>{
        'csrf_token': '',
      }),
    );
    final data = json['data'];
    final songs = data is Map ? data['dailySongs'] : json['recommend'];
    if (songs is! List) return const <NeteaseSongDto>[];
    return songs
        .whereType<Map>()
        .map((e) => NeteaseSongDto.fromJson(Map<String, dynamic>.from(e)))
        .where((song) => song.id > 0)
        .toList(growable: false);
  }

  /// Playlist metadata plus its tracks.
  Future<NeteasePlaylistDetailDto?> playlistDetail(int playlistId) async {
    final json = await _rateLimiter.run(
      () => _client.postWeapi(_playlistDetailPath, <String, dynamic>{
        'id': '$playlistId',
        'n': '100000',
        's': 8,
        'csrf_token': '',
      }),
    );
    final playlist = json['playlist'];
    if (playlist is! Map) return null;
    final playlistMap = Map<String, dynamic>.from(playlist);
    final rawTracks = playlistMap['tracks'];
    final songs = rawTracks is List
        ? rawTracks
              .whereType<Map>()
              .map((e) => NeteaseSongDto.fromJson(Map<String, dynamic>.from(e)))
              .where((song) => song.id > 0)
              .toList(growable: false)
        : const <NeteaseSongDto>[];
    return NeteasePlaylistDetailDto(
      playlist: NeteasePlaylistDto.fromJson(playlistMap),
      songs: songs,
    );
  }

  /// Song ids the signed-in user has liked.
  Future<Set<int>> likedSongIds(int userId) async {
    final json = await _rateLimiter.run(
      () => _client.postWeapi(_likedIdsPath, <String, dynamic>{
        'uid': '$userId',
        'csrf_token': '',
      }),
    );
    final ids = json['ids'];
    if (ids is! List) return <int>{};
    return ids.whereType<num>().map((id) => id.toInt()).toSet();
  }

  /// Likes or unlikes a song. Requires a signed-in account.
  Future<void> setLiked(int songId, bool liked) async {
    await _rateLimiter.run(
      () => _client.postWeapi(_likePath, <String, dynamic>{
        'trackId': '$songId',
        'like': '$liked',
        'alg': 'itembased',
        'time': '3',
        'csrf_token': '',
      }),
    );
  }

  /// Artist header (name, avatar, counts).
  Future<NeteaseArtistDto?> artistDetail(int artistId) async {
    final json = await _rateLimiter.run(
      () => _client.getJson(
        '/api/artist/head/info/get',
        query: <String, dynamic>{'id': '$artistId'},
      ),
    );
    final data = json['data'];
    final artist = data is Map ? data['artist'] : null;
    if (artist is! Map) return null;
    return NeteaseArtistDto.fromJson(Map<String, dynamic>.from(artist));
  }

  /// Artist albums, newest first.
  Future<List<NeteaseAlbumDto>> artistAlbums(
    int artistId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final json = await _rateLimiter.run(
      () => _client.getJson(
        '/api/artist/albums/$artistId',
        query: <String, dynamic>{
          'limit': '$limit',
          'offset': '$offset',
          'total': 'true',
        },
      ),
    );
    final albums = json['hotAlbums'];
    if (albums is! List) return const <NeteaseAlbumDto>[];
    return albums
        .whereType<Map>()
        .map((e) => NeteaseAlbumDto.fromJson(Map<String, dynamic>.from(e)))
        .where((album) => album.id > 0)
        .toList(growable: false);
  }

  /// Artist hot songs.
  Future<List<NeteaseSongDto>> artistSongs(
    int artistId, {
    int limit = 100,
    int offset = 0,
  }) async {
    final json = await _rateLimiter.run(
      () => _client.getJson(
        '/api/v1/artist/songs',
        query: <String, dynamic>{
          'id': '$artistId',
          'private_cloud': 'true',
          'work_type': '1',
          'order': 'hot',
          'offset': '$offset',
          'limit': '$limit',
        },
      ),
    );
    final songs = json['songs'];
    if (songs is! List) return const <NeteaseSongDto>[];
    return songs
        .whereType<Map>()
        .map((e) => NeteaseSongDto.fromJson(Map<String, dynamic>.from(e)))
        .where((song) => song.id > 0)
        .toList(growable: false);
  }

  /// Album metadata plus its songs.
  Future<NeteaseAlbumDetailDto?> albumDetail(int albumId) async {
    final json = await _rateLimiter.run(
      () => _client.getJson('/api/v1/album/$albumId'),
    );
    final album = json['album'];
    if (album is! Map) return null;
    final songs = json['songs'];
    return NeteaseAlbumDetailDto(
      album: NeteaseAlbumDto.fromJson(Map<String, dynamic>.from(album)),
      songs: songs is List
          ? songs
                .whereType<Map>()
                .map(
                  (e) => NeteaseSongDto.fromJson(Map<String, dynamic>.from(e)),
                )
                .where((song) => song.id > 0)
                .toList(growable: false)
          : const <NeteaseSongDto>[],
    );
  }
}
