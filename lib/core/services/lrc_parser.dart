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
final RegExp _offsetTag = RegExp(
  r'\[offset:([+-]?\d+)\]',
  caseSensitive: false,
);
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

final RegExp _yrcLine = RegExp(r'\[(\d+),\s*(\d+)\](.*)$');
final RegExp _yrcWord = RegExp(r'\((\d+),\s*(\d+),\s*[-\d]+\)([^()\r\n]*)');

/// Parses a NetEase YRC document with optional translated lines.
///
/// Format: `[startMs,durationMs](wordStartMs,wordDurationMs,?)text...`.
/// Relative word timestamps (the common case for NetEase) are promoted to
/// absolute by adding the line start; a 250 ms tolerance matches the Android /
/// NeriPlayer normalisation.
Lyric? parseYrc(String? original, {String? translation}) {
  if (original == null || original.trim().isEmpty) return null;

  final translations = <int, String>{};
  if (translation != null) {
    for (final entry in _parseTimed(translation)) {
      if (entry.value.isNotEmpty) translations[entry.key] = entry.value;
    }
  }

  final lines = <LyricLine>[];
  for (final rawLine in original.split('\n')) {
    final match = _yrcLine.firstMatch(rawLine.trim());
    if (match == null) continue;
    final lineStart = int.tryParse(match.group(1)!) ?? 0;
    final rest = match.group(3) ?? '';

    final words = <LyricWord>[];
    for (final wordMatch in _yrcWord.allMatches(rest)) {
      final start = int.tryParse(wordMatch.group(1)!) ?? 0;
      final duration = int.tryParse(wordMatch.group(2)!) ?? 0;
      final text = wordMatch.group(3) ?? '';
      if (text.isEmpty) continue;
      words.add(
        LyricWord(
          start: Duration(milliseconds: start),
          end: Duration(milliseconds: start + duration),
          text: text,
        ),
      );
    }

    _normaliseYrcSpacing(words);
    var text = words.isEmpty
        ? rest.trim()
        : words.map((word) => word.text).join();
    if (text.trim().isEmpty) continue;

    final firstStart = words.isEmpty ? null : words.first.start.inMilliseconds;
    final relative = firstStart != null && firstStart < lineStart - 250;
    if (relative) {
      for (var i = 0; i < words.length; i++) {
        final word = words[i];
        words[i] = LyricWord(
          start: Duration(milliseconds: lineStart + word.start.inMilliseconds),
          end: Duration(milliseconds: lineStart + word.end.inMilliseconds),
          text: word.text,
        );
      }
    }

    lines.add(
      LyricLine(
        timestamp: Duration(milliseconds: lineStart),
        text: text,
        translation: translations[lineStart],
        words: List<LyricWord>.unmodifiable(words),
      ),
    );
  }

  if (lines.isEmpty) return null;
  final order = List<int>.generate(lines.length, (i) => i);
  order.sort((a, b) {
    final byTime = lines[a].timestamp.compareTo(lines[b].timestamp);
    return byTime != 0 ? byTime : a.compareTo(b);
  });
  return Lyric(<LyricLine>[for (final i in order) lines[i]]);
}

void _normaliseYrcSpacing(List<LyricWord> words) {
  if (words.length < 2) return;
  for (var i = 0; i < words.length - 1; i++) {
    final prevText = words[i].text;
    final nextText = words[i + 1].text;
    if (prevText.isEmpty || nextText.isEmpty) continue;
    final prev = prevText.codeUnitAt(prevText.length - 1);
    final next = nextText.codeUnitAt(0);
    if (_isAsciiWordChar(prev) && _isAsciiWordChar(next)) {
      words[i] = LyricWord(
        start: words[i].start,
        end: words[i].end,
        text: '$prevText ',
      );
    }
  }
}

bool _isAsciiWordChar(int code) {
  return (code >= 0x30 && code <= 0x39) ||
      (code >= 0x41 && code <= 0x5a) ||
      (code >= 0x61 && code <= 0x7a);
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
  // Ascending by full millisecond timestamp, as Lyric's contract requires
  // (indexAt binary-searches). Dart's List.sort is unstable, so break ties
  // between exactly-equal timestamps by input position.
  final order = List<int>.generate(entries.length, (i) => i);
  order.sort((i, j) {
    final byTime = entries[i].key.compareTo(entries[j].key);
    return byTime != 0 ? byTime : i.compareTo(j);
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
