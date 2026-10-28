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

import 'package:flind_player/core/models/lyric.dart';

/// One entry of `data.subtitle.subtitles[]` from Bilibili's player API.
class BiliSubtitleTrackDto {
  const BiliSubtitleTrackDto({
    required this.lan,
    required this.lanDoc,
    required this.url,
    this.isAi = false,
  });

  final String lan;
  final String lanDoc;

  /// Protocol-relative or absolute subtitle JSON URL; empty when locked.
  final String url;
  final bool isAi;

  factory BiliSubtitleTrackDto.fromJson(Map<String, dynamic> json) {
    final aiType = (json['ai_type'] as num?)?.toInt() ?? 0;
    final aiStatus = (json['ai_status'] as num?)?.toInt() ?? 0;
    final lan = json['lan'] as String? ?? '';
    final primary = json['subtitle_url'] as String? ?? '';
    final fallback = json['subtitle_url_v2'] as String? ?? '';
    return BiliSubtitleTrackDto(
      lan: lan,
      lanDoc: json['lan_doc'] as String? ?? '',
      url: primary.trim().isEmpty || primary.trim() == '/' ? fallback : primary,
      isAi: aiType > 0 || aiStatus > 0 || lan.startsWith('ai-'),
    );
  }
}

const List<String> _preferredLanguages = <String>[
  'zh-Hans',
  'zh-CN',
  'zh',
  'ai-zh',
];

/// Picks the best Chinese usable track, else the first usable one.
BiliSubtitleTrackDto? selectBiliSubtitleTrack(
  List<BiliSubtitleTrackDto> tracks,
) {
  final usable = tracks
      .where((track) {
        final url = track.url.trim();
        return url.isNotEmpty && url != '/';
      })
      .toList(growable: false);
  if (usable.isEmpty) return null;

  for (final language in _preferredLanguages) {
    for (final track in usable) {
      if (track.lan == language) return track;
    }
  }
  return usable.first;
}

/// Parses the JSON file behind a `subtitle_url`.
///
/// Bilibili's subtitle body is `[{from, to, content}, ...]` with timestamps in
/// seconds. Blank lines and entries without a numeric start are dropped; the
/// result is sorted so a malformed source order cannot break [Lyric.indexAt].
Lyric? parseBiliSubtitleBody(Map<String, dynamic> json) {
  final body = json['body'];
  if (body is! List) return null;

  final lines = <LyricLine>[];
  for (final entry in body) {
    if (entry is! Map) continue;
    final from = entry['from'];
    if (from is! num) continue;
    final content = (entry['content'] as String? ?? '').trim();
    if (content.isEmpty) continue;
    lines.add(
      LyricLine(
        timestamp: Duration(milliseconds: (from * 1000).round()),
        text: content,
      ),
    );
  }
  if (lines.isEmpty) return null;

  lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  return Lyric(lines);
}
