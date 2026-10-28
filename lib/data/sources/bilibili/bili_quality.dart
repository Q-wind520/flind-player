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

import 'package:flind_player/data/sources/bilibili/bili_models.dart';

/// Picks the highest-bandwidth compatible stream.
///
/// Anonymous playback prefers AAC, which every backend decodes. A signed-in
/// caller may also use FLAC (Bilibili Hi-Res); Dolby/EC-3 stays out because it
/// is not uniformly decodable. If none of those codecs exist, the highest
/// bandwidth entry is returned as a last resort.
DashAudioDto? selectBiliAudio(
  List<DashAudioDto> entries, {
  bool includeFlac = false,
}) {
  final usable = entries
      .where((entry) => entry.baseUrl.isNotEmpty)
      .toList(growable: false);
  if (usable.isEmpty) return null;

  final compatible = usable
      .where((entry) => _isAac(entry) || (includeFlac && _isFlac(entry)))
      .toList(growable: false);
  final candidates = compatible.isEmpty ? usable : compatible;
  final sorted = List<DashAudioDto>.from(candidates)
    ..sort((a, b) => b.bandwidth.compareTo(a.bandwidth));
  return sorted.first;
}

bool _isAac(DashAudioDto entry) {
  final mime = entry.mimeType.toLowerCase();
  final codecs = entry.codecs.toLowerCase();
  return mime == 'audio/mp4' && (codecs.isEmpty || codecs.startsWith('mp4a'));
}

bool _isFlac(DashAudioDto entry) {
  final mime = entry.mimeType.toLowerCase();
  final codecs = entry.codecs.toLowerCase();
  return mime == 'audio/flac' || codecs.contains('flac');
}
