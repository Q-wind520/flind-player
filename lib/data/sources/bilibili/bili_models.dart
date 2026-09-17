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

/// A single video item from `/x/web-interface/wbi/search/type`.
///
/// Only the fields the adapter maps are kept. [title] may contain HTML
/// `<em class="keyword">` highlighting; [bili_mappers] strips it.
class SearchItemDto {
  final String bvid;
  final String title;
  final String author;
  final Duration? duration;
  final String? coverUrl;

  const SearchItemDto({
    required this.bvid,
    required this.title,
    required this.author,
    this.duration,
    this.coverUrl,
  });

  factory SearchItemDto.fromJson(Map<String, dynamic> json) => SearchItemDto(
    bvid: json['bvid'] as String? ?? '',
    title: json['title'] as String? ?? '',
    author: json['author'] as String? ?? '',
    duration: _parseDuration(json['duration']),
    coverUrl: _parseCoverUrl(json['pic']),
  );
}

/// A part (chapter) of a Bilibili video.
class VideoPageDto {
  final int cid;
  final int page;
  final String part;
  final int durationSeconds;

  const VideoPageDto({
    required this.cid,
    required this.page,
    required this.part,
    required this.durationSeconds,
  });

  factory VideoPageDto.fromJson(Map<String, dynamic> json) => VideoPageDto(
    cid: (json['cid'] as num?)?.toInt() ?? 0,
    page: (json['page'] as num?)?.toInt() ?? 0,
    part: json['part'] as String? ?? '',
    durationSeconds: (json['duration'] as num?)?.toInt() ?? 0,
  );
}

/// The `/x/web-interface/view` payload.
class VideoInfoDto {
  final String bvid;
  final String title;
  final String ownerName;
  final int? durationSeconds;
  final List<VideoPageDto> pages;
  final String? coverUrl;

  const VideoInfoDto({
    required this.bvid,
    required this.title,
    required this.ownerName,
    this.durationSeconds,
    required this.pages,
    this.coverUrl,
  });

  factory VideoInfoDto.fromJson(Map<String, dynamic> json) {
    final owner = json['owner'];
    final rawPages = json['pages'];
    final pages = rawPages is List
        ? rawPages
              .whereType<Map>()
              .map((e) => VideoPageDto.fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false)
        : const <VideoPageDto>[];

    return VideoInfoDto(
      bvid: json['bvid'] as String? ?? '',
      title: json['title'] as String? ?? '',
      ownerName: owner is Map ? owner['name'] as String? ?? '' : '',
      durationSeconds: (json['duration'] as num?)?.toInt(),
      pages: pages,
      coverUrl: _parseCoverUrl(json['pic']),
    );
  }
}

/// One DASH audio representation from `/x/player/wbi/playurl`.
class DashAudioDto {
  final int id;
  final String baseUrl;
  final List<String> backupUrl;
  final int bandwidth;
  final String mimeType;
  final String codecs;
  final int size;

  const DashAudioDto({
    required this.id,
    required this.baseUrl,
    required this.backupUrl,
    required this.bandwidth,
    required this.mimeType,
    required this.codecs,
    required this.size,
  });

  factory DashAudioDto.fromJson(Map<String, dynamic> json) {
    // Older payloads used snake_case; accept both spellings.
    final base = json['baseUrl'] ?? json['base_url'];
    final backup = json['backupUrl'] ?? json['backup_url'];
    return DashAudioDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      baseUrl: base as String? ?? '',
      backupUrl: backup is List
          ? backup.whereType<String>().toList(growable: false)
          : const <String>[],
      bandwidth: (json['bandwidth'] as num?)?.toInt() ?? 0,
      mimeType:
          json['mimeType'] as String? ?? json['mime_type'] as String? ?? '',
      codecs: json['codecs'] as String? ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
    );
  }
}

/// One favourite folder from
/// `/x/v3/fav/folder/created/list-all`.
///
/// The endpoint nests folders under `data.list[]` and returns `data: null` when
/// the account exposes no public folder. [id] is the folder's media id, which is
/// what `/x/v3/fav/resource/list` expects.
class FavFolderDto {
  final String id;
  final String title;
  final String coverUrl;
  final int mediaCount;

  const FavFolderDto({
    required this.id,
    required this.title,
    this.coverUrl = '',
    this.mediaCount = 0,
  });

  factory FavFolderDto.fromJson(Map<String, dynamic> json) => FavFolderDto(
    id: _idToString(json['media_id'] ?? json['id']),
    title: json['title'] as String? ?? '',
    coverUrl: json['cover'] as String? ?? '',
    mediaCount: (json['media_count'] as num?)?.toInt() ?? 0,
  );
}

/// One entry from `/x/v3/fav/resource/list` (`data.medias[]`).
///
/// [type] is the Bilibili content type: `2` video, `12` audio (`au`), `21`
/// collection/season. [attr] is `0` for a valid entry; a non-zero value marks a
/// deleted or otherwise unplayable one. The resource list exposes `bvid` but
/// **no `cid`**, so callers must resolve the first part lazily.
class FavResourceDto {
  final int type;
  final String bvid;
  final String title;
  final String coverUrl;
  final String upperName;
  final int durationSeconds;
  final int attr;
  final int page;

  const FavResourceDto({
    required this.type,
    required this.bvid,
    required this.title,
    this.coverUrl = '',
    this.upperName = '',
    this.durationSeconds = 0,
    this.attr = 0,
    this.page = 0,
  });

  factory FavResourceDto.fromJson(Map<String, dynamic> json) {
    final upper = json['upper'];
    return FavResourceDto(
      type: (json['type'] as num?)?.toInt() ?? 0,
      bvid: json['bvid'] as String? ?? '',
      title: json['title'] as String? ?? '',
      coverUrl: json['cover'] as String? ?? '',
      upperName: upper is Map ? upper['name'] as String? ?? '' : '',
      durationSeconds: (json['duration'] as num?)?.toInt() ?? 0,
      attr: (json['attr'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 0,
    );
  }
}

/// One page from `/x/v3/fav/resource/list`.
///
/// Entries live under `data.medias[]`; `data.has_more` reports whether another
/// page exists and `data.info.media_count` is the folder's total entry count.
/// A missing folder yields `data: null`, which callers treat as an empty
/// terminal page.
class FavResourcePageDto {
  final List<FavResourceDto> medias;
  final bool hasMore;
  final int mediaCount;

  const FavResourcePageDto({
    this.medias = const <FavResourceDto>[],
    this.hasMore = false,
    this.mediaCount = 0,
  });

  factory FavResourcePageDto.fromJson(Map<String, dynamic> json) {
    final rawMedias = json['medias'];
    final medias = rawMedias is List
        ? rawMedias
              .whereType<Map>()
              .map((e) => FavResourceDto.fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false)
        : const <FavResourceDto>[];
    final info = json['info'];
    // `has_more` is a boolean, but tolerate the `0`/`1` spelling some payloads
    // use at this untyped network boundary.
    final rawHasMore = json['has_more'];
    return FavResourcePageDto(
      medias: medias,
      hasMore: rawHasMore is bool
          ? rawHasMore
          : rawHasMore is num && rawHasMore != 0,
      mediaCount: info is Map ? (info['media_count'] as num?)?.toInt() ?? 0 : 0,
    );
  }
}

/// Normalizes a JSON id that may arrive as a number or a string.
String _idToString(Object? raw) {
  if (raw is num) return raw.toInt().toString();
  if (raw is String) return raw;
  return '';
}

/// Parses the raw `pic` cover URL on the search/view payloads.
///
/// Absent, `null`, `''` and non-string values all yield `null`. The value is
/// kept verbatim: `//`-prefixed and `http://` URLs are intentionally left
/// untouched for `normalizeCoverUrl` to normalise later.
String? _parseCoverUrl(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  return raw;
}

/// Parses the search `duration` field, which is `mm:ss` (or `hh:mm:ss`) text.
Duration? _parseDuration(Object? raw) {
  if (raw is num) {
    return Duration(seconds: raw.toInt());
  }
  if (raw is! String || raw.isEmpty) return null;
  final parts = raw.split(':');
  if (parts.length < 2 || parts.length > 3) return null;
  final numbers = <int>[];
  for (final part in parts) {
    final value = int.tryParse(part);
    if (value == null) return null;
    numbers.add(value);
  }
  if (numbers.length == 2) {
    return Duration(minutes: numbers[0], seconds: numbers[1]);
  }
  return Duration(hours: numbers[0], minutes: numbers[1], seconds: numbers[2]);
}
