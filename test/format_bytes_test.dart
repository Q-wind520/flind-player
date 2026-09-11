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

import 'package:flind_player/shared/format_bytes.dart';

void main() {
  group('formatBytes', () {
    test('formats zero and negative values as 0 B', () {
      expect(formatBytes(0), '0 B');
      expect(formatBytes(-1), '0 B');
    });

    test('formats bytes below 1 KiB with no decimals', () {
      expect(formatBytes(1), '1 B');
      expect(formatBytes(512), '512 B');
      expect(formatBytes(1023), '1023 B');
    });

    test('formats KiB as whole numbers with no trailing .0', () {
      expect(formatBytes(1024), '1 KB');
      expect(formatBytes(512 * 1024), '512 KB');
      expect(formatBytes(1024 * 1024 - 1), '1023 KB');
    });

    test('formats MiB with one decimal', () {
      expect(formatBytes(1024 * 1024), '1 MB');
      expect(formatBytes(1024 * 1024 + 512 * 1024), '1.5 MB');
      expect(formatBytes(256 * 1024 * 1024), '256 MB');
    });

    test('formats GiB with one decimal', () {
      expect(formatBytes(1024 * 1024 * 1024), '1 GB');
      expect(formatBytes(2 * 1024 * 1024 * 1024), '2 GB');
      expect(formatBytes(5 * 1024 * 1024 * 1024), '5 GB');
      expect(formatBytes(1536 * 1024 * 1024), '1.5 GB');
    });

    test('never emits a trailing .0', () {
      for (final bytes in <int>[
        1024,
        1024 * 1024,
        1024 * 1024 * 1024,
        512 * 1024 * 1024,
        2 * 1024 * 1024 * 1024,
      ]) {
        expect(formatBytes(bytes), isNot(endsWith('.0')));
      }
    });
  });
}
