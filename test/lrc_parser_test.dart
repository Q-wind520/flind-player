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

import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/services/lrc_parser.dart';

void main() {
  test('parses multiple timestamps on one line and sorts them', () {
    final lyric = parseLrc('[00:01.00][00:05.00]Hello\n[00:03.5]World')!;
    expect(lyric.lines.map((l) => l.text), <String>['Hello', 'World', 'Hello']);
    expect(lyric.lines.map((l) => l.timestamp), <Duration>[
      const Duration(seconds: 1),
      const Duration(milliseconds: 3500),
      const Duration(seconds: 5),
    ]);
  });

  test('parses hundredths and thousandths fractions', () {
    final lyric = parseLrc('[00:00.05]A\n[00:00.005]B')!;
    expect(lyric.lines[0].timestamp, const Duration(milliseconds: 50));
    expect(lyric.lines[1].timestamp, const Duration(milliseconds: 5));
  });

  test('applies [offset:±ms] and ignores metadata tags', () {
    final lyric = parseLrc('[ti:T]\n[ar:A]\n[offset:500]\n[00:01.00]Hi')!;
    expect(lyric.lines, hasLength(1));
    expect(lyric.lines.single.timestamp, const Duration(milliseconds: 1500));
  });

  test('merges translation by exact timestamp', () {
    final lyric = parseLrc(
      '[00:01.00]原文\n[00:02.00]Second',
      translation: '[00:01.00]translated',
    )!;
    expect(lyric.lines[0].translation, 'translated');
    expect(lyric.lines[1].translation, isNull);
  });

  test('returns null for the pure-music placeholder', () {
    expect(parseLrc('[99:00.00]纯音乐，请欣赏\n'), isNull);
  });

  test('returns null for null or blank input', () {
    expect(parseLrc(null), isNull);
    expect(parseLrc(''), isNull);
    expect(parseLrc('[00:01.00]\n'), isNull);
  });

  group('Lyric.indexAt', () {
    final lyric = Lyric(const <LyricLine>[
      LyricLine(timestamp: Duration(seconds: 1), text: 'a'),
      LyricLine(timestamp: Duration(seconds: 3), text: 'b'),
    ]);

    test('returns 0 before the first line', () {
      expect(lyric.indexAt(Duration.zero), 0);
    });

    test('returns the last line at or before the position', () {
      expect(lyric.indexAt(const Duration(seconds: 2)), 0);
      expect(lyric.indexAt(const Duration(seconds: 3)), 1);
      expect(lyric.indexAt(const Duration(seconds: 9)), 1);
    });

    test('returns null for an empty lyric', () {
      expect(const Lyric(<LyricLine>[]).indexAt(Duration.zero), isNull);
    });
  });
}
