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

/// One timed lyric line, optionally carrying its translation.
@immutable
class LyricLine {
  final Duration timestamp;
  final String text;
  final String? translation;

  const LyricLine({
    required this.timestamp,
    required this.text,
    this.translation,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LyricLine &&
          other.timestamp == timestamp &&
          other.text == text &&
          other.translation == translation;

  @override
  int get hashCode => Object.hash(timestamp, text, translation);
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
