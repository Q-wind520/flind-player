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

// DESIGN REQUIREMENT: the Bilibili source must remain remotely disableable.
// It is reachable only through `MusicSource`/`StreamResolver` interfaces so a
// feature flag can drop it (and its provider) without touching the rest of the
// app. Never let UI or playback code depend on this class directly.

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/music_source.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/core/sources/stream_resolver.dart';
import 'package:flind_player/data/sources/bilibili/bili_api.dart';
import 'package:flind_player/data/sources/bilibili/bili_client.dart';
import 'package:flind_player/data/sources/bilibili/bili_mappers.dart';
import 'package:flind_player/data/sources/bilibili/bili_models.dart';

/// Bilibili as a [MusicSource] and [StreamResolver].
///
/// Search results carry a `bvid` but no `cid`, so [search] returns tracks with
/// the [biliUnknownCid] placeholder; [resolveStream] lazily fetches the first
/// part's real `cid` from `videoInfo` before asking for the audio URL.
class BiliSource implements MusicSource, StreamResolver {
  /// Stream URLs are treated as valid for this long, matching Bilibili's
  /// documented ≈120-minute CDN expiry.
  static const Duration streamTtl = Duration(minutes: 120);

  final BiliApi _api;

  /// User agent reused for the CDN stream request.
  final String _userAgent;

  BiliSource({required BiliApi api, String userAgent = kDesktopUserAgent})
    : _api = api, // ignore: prefer_initializing_formals
      _userAgent = userAgent; // ignore: prefer_initializing_formals

  @override
  String get id => biliSourceId;

  @override
  SourceCapabilities get capabilities => const SourceCapabilities(
    <SourceCapability>{SourceCapability.search, SourceCapability.streamDirect},
  );

  @override
  Future<List<Track>> search(String query, {int page = 1}) async {
    final items = await _api.searchVideos(query, page: page);
    return items.map(searchItemToTrack).toList(growable: false);
  }

  @override
  Future<Track> fetchTrack(SourceTrackId id) async {
    if (id is! BiliTrackId) {
      throw ArgumentError.value(
        id,
        'id',
        'BiliSource only accepts BiliTrackId',
      );
    }
    final video = await _api.videoInfo(id.bvid);
    if (video.pages.isEmpty) {
      throw StateError('Video ${id.bvid} has no parts');
    }
    final page = _pageFor(video, id.cid);
    return videoPageToTrack(video, page);
  }

  /// Alias so [BiliSource] can be registered in a `StreamResolver` map.
  @override
  Future<StreamInfo> resolve(Track track) => resolveStream(track);

  @override
  Future<StreamInfo> resolveStream(Track track) async {
    final id = track.sourceTrackId;
    if (id is! BiliTrackId) {
      throw UnsupportedError(
        'BiliSource cannot resolve a ${track.sourceTrackId.runtimeType} track',
      );
    }

    var cid = id.cid;
    if (cid < 0) {
      final video = await _api.videoInfo(id.bvid);
      if (video.pages.isEmpty) {
        throw StateError('Video ${id.bvid} has no parts to resolve audio from');
      }
      cid = video.pages.first.cid;
    }

    final audio = await _api.playUrlAudio(id.bvid, cid);
    if (audio == null) {
      throw StateError('No audio stream available for ${id.bvid} (cid: $cid)');
    }

    return StreamInfo(
      url: Uri.parse(audio.baseUrl),
      backupUrls: audio.backupUrl.map(Uri.parse).toList(growable: false),
      headers: <String, String>{
        'Referer': kDesktopReferer,
        'User-Agent': _userAgent,
      },
      expiresAt: DateTime.now().add(streamTtl),
      qualityId: audio.id.toString(),
    );
  }

  VideoPageDto _pageFor(VideoInfoDto video, int cid) {
    if (cid >= 0) {
      for (final page in video.pages) {
        if (page.cid == cid) return page;
      }
      throw StateError('Video ${video.bvid} has no part with cid $cid');
    }
    return video.pages.first;
  }
}
