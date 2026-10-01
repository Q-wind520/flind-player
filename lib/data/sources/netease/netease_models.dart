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

/// One song from cloudsearch or `/weapi/v3/song/detail`.
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
    final rawArtists = json['ar'];
    final artists = rawArtists is List
        ? rawArtists
              .whereType<Map>()
              .map((e) => e['name'] as String? ?? '')
              .where((name) => name.isNotEmpty)
              .toList(growable: false)
        : const <String>[];
    final album = json['al'];
    final cover = album is Map ? album['picUrl'] : null;
    return NeteaseSongDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      artists: artists,
      album: album is Map ? album['name'] as String? ?? '' : '',
      durationMs: (json['dt'] as num?)?.toInt() ?? 0,
      coverUrl: (cover is String && cover.isNotEmpty) ? cover : null,
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
    url: (json['url'] as String?)?.isEmpty ?? true ? null : json['url'] as String,
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
