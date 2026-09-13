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

import 'package:flind_player/app/theme/app_theme.dart';

void main() {
  test('SnackBars render as floating rounded bubbles in both themes', () {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      final snackBarTheme = theme.snackBarTheme;
      expect(snackBarTheme.behavior, SnackBarBehavior.floating);
      expect(snackBarTheme.insetPadding, isNotNull);
      final shape = snackBarTheme.shape;
      expect(shape, isA<RoundedRectangleBorder>());
      expect(
        (shape as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(12),
      );
    }
  });
}
