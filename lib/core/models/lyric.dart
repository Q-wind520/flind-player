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

import 'package:flutter/foundation.dart';

/// One timed word inside a lyric line.
@immutable
class LyricWord {
  final Duration start;
  final Duration end;
  final String text;

  const LyricWord({required this.start, required this.end, required this.text});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LyricWord &&
          other.start == start &&
          other.end == end &&
          other.text == text;

  @override
  int get hashCode => Object.hash(start, end, text);
}

/// One timed lyric line, optionally carrying its translation and word timings.
@immutable
class LyricLine {
  final Duration timestamp;
  final String text;
  final String? translation;

  /// Word-level timings for YRC/enhanced lyrics; empty for plain LRC.
  final List<LyricWord> words;

  const LyricLine({
    required this.timestamp,
    required this.text,
    this.translation,
    this.words = const <LyricWord>[],
  });

  /// Index of the word covering [position], or `null` before the line starts.
  int? wordIndexAt(Duration position) {
    if (words.isEmpty) return null;
    var low = 0;
    var high = words.length - 1;
    var result = 0;
    while (low <= high) {
      final mid = (low + high) >> 1;
      if (words[mid].start <= position) {
        result = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return result;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LyricLine &&
          other.timestamp == timestamp &&
          other.text == text &&
          other.translation == translation &&
          listEquals(other.words, words);

  @override
  int get hashCode =>
      Object.hash(timestamp, text, translation, Object.hashAll(words));
}

/// A track's lyrics as an ascending time line.
@immutable
class Lyric {
  /// Lines sorted by [LyricLine.timestamp].
  final List<LyricLine> lines;

  const Lyric(this.lines);

  /// Index of the last line whose timestamp is `<= position`.
  ///
  /// Returns `0` when [position] precedes the first line and `null` when
  /// [lines] is empty. Binary search.
  int? indexAt(Duration position) {
    if (lines.isEmpty) return null;
    var low = 0;
    var high = lines.length - 1;
    var result = 0;
    while (low <= high) {
      final mid = (low + high) >> 1;
      if (lines[mid].timestamp <= position) {
        result = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return result;
  }
}
