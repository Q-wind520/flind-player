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
  );
}
