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

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/remote_playlist.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/sources/bilibili/bili_models.dart';

/// Source id stamped onto every Bilibili [Track].
const String biliSourceId = 'bilibili';

/// Placeholder cid used by search results.
///
/// Search returns a `bvid` but no `cid`; the real first-page cid is resolved
/// lazily by [BiliSource.resolveStream]. Never persist this value.
const int biliUnknownCid = -1;

final RegExp _htmlTag = RegExp(r'<[^>]*>');
final RegExp _htmlEntity = RegExp(r'&(#x?[0-9a-fA-F]+|[a-zA-Z]+);');

const Map<String, String> _namedEntities = <String, String>{
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': ' ',
};

/// Removes HTML tags (e.g. search's `<em class="keyword">`) and decodes the
/// handful of entities Bilibili titles use.
String stripHtml(String input) {
  final withoutTags = input.replaceAll(_htmlTag, '');
  final decoded = withoutTags.replaceAllMapped(_htmlEntity, (match) {
    final entity = match.group(1)!;
    if (entity.startsWith('#')) {
      final isHex = entity.length > 1 && (entity[1] == 'x' || entity[1] == 'X');
      final digits = isHex ? entity.substring(2) : entity.substring(1);
      final value = int.tryParse(digits, radix: isHex ? 16 : 10);
      if (value == null || value < 0 || value > 0x10FFFF) {
        return match.group(0)!;
      }
      return String.fromCharCode(value);
    }
    return _namedEntities[entity] ?? match.group(0)!;
  });
  return decoded.trim();
}

/// Bilibili content type for a regular video.
const int biliTypeVideo = 2;

/// Maps a favourite folder to a [RemotePlaylist].
RemotePlaylist favoriteFolderToRemotePlaylist(FavFolderDto folder) =>
    RemotePlaylist(
      id: folder.id,
      title: stripHtml(folder.title),
      coverUrl: folder.coverUrl.isEmpty ? null : folder.coverUrl,
      trackCount: folder.mediaCount,
    );

/// Maps one favourite resource to a [Track].
///
/// The resource list carries a `bvid` but no `cid`, so [biliUnknownCid] is used
/// as a placeholder exactly like [searchItemToTrack]; [BiliSource.resolveStream]
/// resolves the first part lazily. Note this means a favourite saved from a
/// multi-part video always plays its first part.
Track favoriteResourceToTrack(FavResourceDto resource) => Track(
  source: biliSourceId,
  sourceTrackId: BiliTrackId(bvid: resource.bvid, cid: biliUnknownCid),
  uri: '$biliSourceId:${resource.bvid}:$biliUnknownCid',
  title: stripHtml(resource.title),
  artist: resource.upperName.isEmpty ? null : stripHtml(resource.upperName),
  duration: resource.durationSeconds > 0
      ? Duration(seconds: resource.durationSeconds)
      : null,
  coverUrl: normalizeCoverUrl(resource.coverUrl),
);

/// Maps favourite resources to playable [Track]s, skipping entries that the
/// video `playurl` endpoint cannot stream:
///
/// * `type == 12` — Bilibili audio (`au`) needs
///   `/audio/music-service-c/web/url`;
/// * `type == 21` — collections/seasons need the season archive endpoints;
/// * `attr != 0` — deleted or otherwise invalid entries;
/// * a blank `bvid` — nothing to resolve.
///
/// Returns the playable tracks and the number of skipped entries so callers can
/// report how much of a folder was dropped.
({List<Track> tracks, int skipped}) favoriteResourcesToTracks(
  Iterable<FavResourceDto> resources,
) {
  final tracks = <Track>[];
  var skipped = 0;
  for (final resource in resources) {
    if (resource.type != biliTypeVideo ||
        resource.attr != 0 ||
        resource.bvid.isEmpty) {
      skipped++;
      continue;
    }
    tracks.add(favoriteResourceToTrack(resource));
  }
  return (tracks: List.unmodifiable(tracks), skipped: skipped);
}

/// Maps one parsed favourite-resource page to a [RemoteTrackPage].
///
/// [FavResourcePageDto.hasMore] carries through unchanged so callers know
/// whether to request another page. [RemoteTrackPage.totalCount] prefers the
/// folder's `info.media_count` and falls back to the number of playable tracks
/// when the server omits it. The number of dropped entries is returned alongside
/// so callers can report it.
({RemoteTrackPage page, int skipped}) favoriteResourcePageToRemoteTrackPage(
  FavResourcePageDto response, {
  required int pageNumber,
}) {
  final result = favoriteResourcesToTracks(response.medias);
  return (
    page: RemoteTrackPage(
      tracks: result.tracks,
      page: pageNumber,
      hasMore: response.hasMore,
      totalCount: response.mediaCount > 0
          ? response.mediaCount
          : result.tracks.length,
    ),
    skipped: result.skipped,
  );
}

/// Maps a search result item to a [Track].
///
/// The cid is unknown at search time, so [biliUnknownCid] is used as a
/// placeholder.
Track searchItemToTrack(SearchItemDto item) => Track(
  source: biliSourceId,
  sourceTrackId: BiliTrackId(bvid: item.bvid, cid: biliUnknownCid),
  uri: '$biliSourceId:${item.bvid}:$biliUnknownCid',
  title: stripHtml(item.title),
  artist: item.author.isEmpty ? null : stripHtml(item.author),
  duration: item.duration,
  coverUrl: normalizeCoverUrl(item.coverUrl),
);

/// Maps one part of a video to a [Track].
///
/// For a multi-part video the part title wins when present; a single-part video
/// keeps the video title. The video title becomes the album.
Track videoPageToTrack(VideoInfoDto video, VideoPageDto page) {
  final videoTitle = stripHtml(video.title);
  final partTitle = stripHtml(page.part);
  final title = video.pages.length > 1 && partTitle.isNotEmpty
      ? partTitle
      : videoTitle;

  final duration = page.durationSeconds > 0
      ? Duration(seconds: page.durationSeconds)
      : video.durationSeconds != null
      ? Duration(seconds: video.durationSeconds!)
      : null;

  return Track(
    source: biliSourceId,
    sourceTrackId: BiliTrackId(bvid: video.bvid, cid: page.cid),
    uri: '$biliSourceId:${video.bvid}:${page.cid}',
    title: title,
    artist: video.ownerName.isEmpty ? null : stripHtml(video.ownerName),
    album: videoTitle.isEmpty ? null : videoTitle,
    duration: duration,
    coverUrl: normalizeCoverUrl(video.coverUrl),
  );
}
