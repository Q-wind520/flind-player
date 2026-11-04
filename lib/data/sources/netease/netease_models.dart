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

/// One song from `/weapi/search/get` (legacy shape: `artists`/`album`/
/// `duration`) or `/weapi/v3/song/detail` (canonical shape: `ar`/`al`/`dt`).
class NeteaseSongDto {
  final int id;
  final String name;
  final List<String> artists;
  final String album;
  final int durationMs;
  final String? coverUrl;

  const NeteaseSongDto({
    required this.id,
    required this.name,
    required this.artists,
    required this.album,
    required this.durationMs,
    this.coverUrl,
  });

  factory NeteaseSongDto.fromJson(Map<String, dynamic> json) {
    final rawArtists = json['ar'] ?? json['artists'];
    final artists = rawArtists is List
        ? rawArtists
              .whereType<Map>()
              .map((e) => e['name'] as String? ?? '')
              .where((name) => name.isNotEmpty)
              .toList(growable: false)
        : const <String>[];
    final album = json['al'] ?? json['album'];
    final cover = album is Map ? album['picUrl'] : null;
    return NeteaseSongDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      artists: artists,
      album: album is Map ? album['name'] as String? ?? '' : '',
      durationMs: ((json['dt'] ?? json['duration']) as num?)?.toInt() ?? 0,
      coverUrl: (cover is String && cover.isNotEmpty) ? cover : null,
    );
  }
}

/// One playlist row from the user/recommended playlist endpoints.
class NeteasePlaylistDto {
  final int id;
  final String name;
  final String? coverUrl;
  final int trackCount;
  final String? creator;
  final String? description;

  const NeteasePlaylistDto({
    required this.id,
    required this.name,
    this.coverUrl,
    this.trackCount = 0,
    this.creator,
    this.description,
  });

  factory NeteasePlaylistDto.fromJson(Map<String, dynamic> json) {
    final creatorNode = json['creator'];
    final cover = json['coverImgUrl'] ?? json['picUrl'];
    return NeteasePlaylistDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      coverUrl: (cover is String && cover.isNotEmpty) ? cover : null,
      trackCount:
          ((json['trackCount'] ?? json['songCount']) as num?)?.toInt() ?? 0,
      creator: creatorNode is Map
          ? creatorNode['nickname'] as String?
          : json['creator'] as String?,
      description: json['description'] as String?,
    );
  }
}

/// Playlist metadata plus its songs from `/weapi/v3/playlist/detail`.
class NeteasePlaylistDetailDto {
  final NeteasePlaylistDto playlist;
  final List<NeteaseSongDto> songs;

  const NeteasePlaylistDetailDto({required this.playlist, required this.songs});
}

/// One album row from artist/album endpoints.
class NeteaseAlbumDto {
  final int id;
  final String name;
  final String? coverUrl;
  final String? artist;
  final int trackCount;
  final int? publishTime;

  const NeteaseAlbumDto({
    required this.id,
    required this.name,
    this.coverUrl,
    this.artist,
    this.trackCount = 0,
    this.publishTime,
  });

  factory NeteaseAlbumDto.fromJson(Map<String, dynamic> json) {
    final artistNode = json['artist'];
    final cover = json['picUrl'] ?? json['blurPicUrl'];
    return NeteaseAlbumDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      coverUrl: (cover is String && cover.isNotEmpty) ? cover : null,
      artist: artistNode is Map
          ? artistNode['name'] as String?
          : json['artist'] as String?,
      trackCount: ((json['size'] ?? json['trackCount']) as num?)?.toInt() ?? 0,
      publishTime: (json['publishTime'] as num?)?.toInt(),
    );
  }
}

/// Album metadata plus its songs from `/api/v1/album/{id}`.
class NeteaseAlbumDetailDto {
  final NeteaseAlbumDto album;
  final List<NeteaseSongDto> songs;

  const NeteaseAlbumDetailDto({required this.album, required this.songs});
}

/// Artist header from `/api/artist/head/info/get`.
class NeteaseArtistDto {
  final int id;
  final String name;
  final String? avatarUrl;
  final int albumCount;
  final int songCount;

  const NeteaseArtistDto({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.albumCount = 0,
    this.songCount = 0,
  });

  factory NeteaseArtistDto.fromJson(Map<String, dynamic> json) {
    final avatar = json['avatar'] ?? json['picUrl'];
    return NeteaseArtistDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      avatarUrl: (avatar is String && avatar.isNotEmpty) ? avatar : null,
      albumCount: (json['albumSize'] as num?)?.toInt() ?? 0,
      songCount: (json['musicSize'] as num?)?.toInt() ?? 0,
    );
  }
}

/// One entry from `/eapi/song/enhance/player/url/v1`.
class NeteaseUrlDto {
  final String? url;
  final int? br;
  final String? level;
  final String? type;

  const NeteaseUrlDto({this.url, this.br, this.level, this.type});

  factory NeteaseUrlDto.fromJson(Map<String, dynamic> json) => NeteaseUrlDto(
    url: (json['url'] as String?)?.isEmpty ?? true
        ? null
        : json['url'] as String,
    br: (json['br'] as num?)?.toInt(),
    level: json['level'] as String?,
    type: json['type'] as String?,
  );
}

/// The `/weapi/song/lyric` payload.
class NeteaseLyricDto {
  final String? lrc;
  final String? translation;
  final String? roma;

  const NeteaseLyricDto({this.lrc, this.translation, this.roma});

  factory NeteaseLyricDto.fromJson(Map<String, dynamic> json) {
    String? text(Object? node) {
      if (node is! Map) return null;
      final value = node['lyric'];
      return (value is String && value.isNotEmpty) ? value : null;
    }

    return NeteaseLyricDto(
      lrc: text(json['lrc']),
      translation: text(json['tlyric']),
      roma: text(json['romalrc']),
    );
  }
}
