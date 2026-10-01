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

// DESIGN REQUIREMENT: the NetEase source must remain remotely disableable. It
// is reachable only through `MusicSource`/`StreamResolver`/`LyricsProvider`
// interfaces so a feature flag can drop it without touching the rest of the app.

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/services/lrc_parser.dart';
import 'package:flind_player/core/services/lyrics_provider.dart';
import 'package:flind_player/core/sources/music_source.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/core/sources/stream_resolver.dart';
import 'package:flind_player/data/sources/netease/netease_api.dart';
import 'package:flind_player/data/sources/netease/netease_client.dart';
import 'package:flind_player/data/sources/netease/netease_mappers.dart';

/// NetEase Cloud Music as a [MusicSource], [StreamResolver] and [LyricsProvider].
class NeteaseSource implements MusicSource, StreamResolver, LyricsProvider {
  final NeteaseApi _api;

  NeteaseSource({required NeteaseApi api})
    : _api = api; // ignore: prefer_initializing_formals

  @override
  String get id => neteaseSourceId;

  @override
  SourceCapabilities get capabilities => const SourceCapabilities(
    <SourceCapability>{SourceCapability.search, SourceCapability.streamDirect},
  );

  @override
  Future<List<Track>> search(String query, {int page = 1}) async {
    final songs = await _api.searchSongs(query, page: page);
    return songs.map(neteaseSongToTrack).toList(growable: false);
  }

  @override
  Future<Track> fetchTrack(SourceTrackId id) async {
    if (id is! NeteaseTrackId) {
      throw ArgumentError.value(id, 'id', 'NeteaseSource only accepts NeteaseTrackId');
    }
    final song = await _api.songDetail(id.songId);
    if (song == null) {
      throw StateError('No NetEase song ${id.songId}');
    }
    return neteaseSongToTrack(song);
  }

  /// Alias so [NeteaseSource] can be registered in a `StreamResolver` map.
  @override
  Future<StreamInfo> resolve(Track track) => resolveStream(track);

  @override
  Future<StreamInfo> resolveStream(Track track) async {
    final id = track.sourceTrackId;
    if (id is! NeteaseTrackId) {
      throw UnsupportedError(
        'NeteaseSource cannot resolve a ${id.runtimeType} track',
      );
    }
    final dto = await _api.songUrl(id.songId);
    final url = dto?.url;
    if (url == null || url.isEmpty) {
      throw StateError('No stream available for ${track.uri}');
    }
    return StreamInfo(
      url: Uri.parse(url),
      headers: const <String, String>{
        'Referer': kNeteaseReferer,
      },
      qualityId: dto?.level ?? 'standard',
    );
  }

  @override
  Future<Lyric?> lyricsFor(Track track) async {
    final id = track.sourceTrackId;
    if (id is! NeteaseTrackId) return null;
    final dto = await _api.songLyric(id.songId);
    return parseLrc(dto.lrc, translation: dto.translation);
  }
}
