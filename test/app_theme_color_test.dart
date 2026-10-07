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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/app_theme_color.dart';

void main() {
  test('the default theme colour is the brand green', () {
    expect(AppThemeColor.defaults.argb, 0xFF1BA784);
  });

  test('four distinct recommended colours are offered, led by the default', () {
    expect(AppThemeColor.recommended, hasLength(4));
    expect(AppThemeColor.recommended.first, AppThemeColor.defaults);
    expect(AppThemeColor.recommended.toSet(), hasLength(4));
  });

  test('equality is by the stored ARGB value', () {
    expect(const AppThemeColor(0xFF3B82F6), const AppThemeColor(0xFF3B82F6));
    expect(
      const AppThemeColor(0xFF3B82F6),
      isNot(const AppThemeColor(0xFF8B5CF6)),
    );
  });

  test('toHex renders an opaque colour as #RRGGBB', () {
    expect(const AppThemeColor(0xFF3B82F6).toHex(), '#3B82F6');
    expect(const AppThemeColor(0xFF1BA784).toHex(), '#1BA784');
  });

  test('tryParseHex accepts with and without a leading hash, any case', () {
    expect(
      AppThemeColor.tryParseHex('#3b82f6'),
      const AppThemeColor(0xFF3B82F6),
    );
    expect(
      AppThemeColor.tryParseHex('3B82F6'),
      const AppThemeColor(0xFF3B82F6),
    );
  });

  test('tryParseHex rejects malformed input', () {
    expect(AppThemeColor.tryParseHex('#12345'), isNull);
    expect(AppThemeColor.tryParseHex('#GGGGGG'), isNull);
    expect(AppThemeColor.tryParseHex(''), isNull);
  });

  test('a parsed hex round-trips back to the same colour', () {
    for (final colour in AppThemeColor.recommended) {
      expect(AppThemeColor.tryParseHex(colour.toHex()), colour);
    }
  });

  test('toColor exposes the ARGB value as a Flutter Color', () {
    expect(const AppThemeColor(0xFF3B82F6).toColor(), const Color(0xFF3B82F6));
  });
}
