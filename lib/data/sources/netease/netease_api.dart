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
  static const String _searchPath = '/weapi/cloudsearch/get/web?csrf_token=';
  static const String _detailPath = '/weapi/v3/song/detail?csrf_token=';
  static const String _urlPath = '/song/enhance/player/url/v1';
  static const String _lyricPath = '/weapi/song/lyric?csrf_token=';

  /// Page size used by the web cloud-search client.
  static const int searchPageSize = 30;

  final NeteaseClient _client;
  final RateLimiter _rateLimiter;

  NeteaseApi({required NeteaseClient client, required RateLimiter rateLimiter})
    : _client = client, // ignore: prefer_initializing_formals
      _rateLimiter = rateLimiter; // ignore: prefer_initializing_formals

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
    return songs
        .whereType<Map>()
        .map((e) => NeteaseSongDto.fromJson(Map<String, dynamic>.from(e)))
        .where((song) => song.id > 0)
        .toList(growable: false);
  }

  Future<NeteaseSongDto?> songDetail(int songId) async {
    final json = await _rateLimiter.run(
      () => _client.postWeapi(_detailPath, <String, dynamic>{
        'c': jsonEncode(<dynamic>[
          <String, dynamic>{'id': songId},
        ]),
      }),
    );
    final songs = json['songs'];
    if (songs is! List || songs.isEmpty) return null;
    final first = songs.first;
    if (first is! Map) return null;
    return NeteaseSongDto.fromJson(Map<String, dynamic>.from(first));
  }

  Future<NeteaseUrlDto?> songUrl(int songId) async {
    final json = await _rateLimiter.run(
      () => _client.postEapi(_urlPath, <String, dynamic>{
        'ids': '[$songId]',
        'level': 'standard',
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
}
