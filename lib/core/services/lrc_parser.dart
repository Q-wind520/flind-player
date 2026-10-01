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

export 'package:flind_player/core/models/lyric.dart';

final RegExp _timeTag = RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');
final RegExp _offsetTag = RegExp(r'\[offset:([+-]?\d+)\]', caseSensitive: false);
const String _pureMusicMarker = '纯音乐，请欣赏';

/// Parses an LRC document into a [Lyric], merging an optional translation.
///
/// Returns `null` when [original] is absent/blank, contains no timed line, or
/// is only the pure-music placeholder. Supports `[mm:ss]`, `[mm:ss.xx]`,
/// `[mm:ss.xxx]`, several tags per line, and `[offset:±ms]`.
Lyric? parseLrc(String? original, {String? translation}) {
  if (original == null) return null;
  final entries = _parseTimed(original);
  if (entries.isEmpty) return null;
  if (entries.every((e) => e.value == _pureMusicMarker)) return null;

  final translations = <int, String>{};
  if (translation != null) {
    for (final entry in _parseTimed(translation)) {
      final text = entry.value;
      if (text.isNotEmpty) translations[entry.key] = text;
    }
  }

  final lines = entries
      .map(
        (e) => LyricLine(
          timestamp: Duration(milliseconds: e.key),
          text: e.value,
          translation: translations[e.key],
        ),
      )
      .toList(growable: false);
  return Lyric(lines);
}

List<MapEntry<int, String>> _parseTimed(String raw) {
  final offsetMs = _offsetOf(raw);
  final entries = <MapEntry<int, String>>[];
  for (final line in raw.split('\n')) {
    final matches = _timeTag.allMatches(line).toList(growable: false);
    if (matches.isEmpty) continue;
    final text = line.substring(matches.last.end).trim();
    if (text.isEmpty) continue;
    for (final match in matches) {
      final minutes = int.parse(match.group(1)!);
      final seconds = int.parse(match.group(2)!);
      final millis = _fractionToMs(match.group(3));
      final total = minutes * 60000 + seconds * 1000 + millis + offsetMs;
      entries.add(MapEntry(total < 0 ? 0 : total, text));
    }
  }
  // Order by whole seconds only; lines sharing a second keep document order
  // (Dart's List.sort is not stable, so break ties by input position).
  final order = List<int>.generate(entries.length, (i) => i);
  order.sort((i, j) {
    final si = entries[i].key ~/ 1000;
    final sj = entries[j].key ~/ 1000;
    return si == sj ? i.compareTo(j) : si.compareTo(sj);
  });
  return [for (final i in order) entries[i]];
}

int _offsetOf(String raw) {
  final match = _offsetTag.firstMatch(raw);
  return match == null ? 0 : int.tryParse(match.group(1)!) ?? 0;
}

int _fractionToMs(String? fraction) {
  if (fraction == null) return 0;
  final value = int.parse(fraction);
  return switch (fraction.length) {
    1 => value * 100,
    2 => value * 10,
    _ => value,
  };
}
