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
import 'package:flind_player/app/theme/app_tokens.dart';

void main() {
  const seed = Color(0xFF1BA784);

  test('SnackBars render as floating rounded bubbles in both themes', () {
    for (final theme in [AppTheme.light(seed), AppTheme.dark(seed)]) {
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

  test('the colour scheme is derived from the given seed', () {
    const teal = Color(0xFF1BA784);
    const purple = Color(0xFF8B5CF6);

    final tealLight = AppTheme.light(teal);
    final purpleLight = AppTheme.light(purple);

    // Changing the seed must change the derived scheme...
    expect(
      tealLight.colorScheme.primary,
      isNot(equals(purpleLight.colorScheme.primary)),
    );
    // ...and each builder must pin the requested brightness.
    expect(tealLight.brightness, Brightness.light);
    expect(AppTheme.dark(teal).brightness, Brightness.dark);
  });

  test('component themes derive from the tokens and the colour scheme', () {
    for (final theme in [AppTheme.light(seed), AppTheme.dark(seed)]) {
      expect(theme.cardTheme.elevation, 0);
      final shape = theme.cardTheme.shape;
      expect(shape, isA<RoundedRectangleBorder>());
      expect(
        (shape! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(AppRadius.sm),
      );
      expect(theme.dividerTheme.color, theme.colorScheme.outlineVariant);
      expect(
        theme.progressIndicatorTheme.linearTrackColor,
        theme.colorScheme.outlineVariant,
      );
      final border = theme.inputDecorationTheme.border;
      expect(border, isA<OutlineInputBorder>());
      expect(
        (border! as OutlineInputBorder).borderRadius,
        BorderRadius.circular(AppRadius.md),
      );
      expect(
        theme.listTileTheme.contentPadding,
        const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      );
    }
  });

  test('the navigation label roles differ by weight', () {
    final theme = AppTheme.light(seed);
    final bar = theme.navigationBarTheme.labelTextStyle;
    expect(bar, isNotNull);
    expect(bar!.resolve(<WidgetState>{})!.fontWeight, FontWeight.w500);
    expect(
      bar.resolve(<WidgetState>{WidgetState.selected})!.fontWeight,
      FontWeight.w600,
    );
    expect(
      theme.navigationRailTheme.selectedLabelTextStyle?.fontWeight,
      FontWeight.w600,
    );
    expect(
      theme.navigationRailTheme.unselectedLabelTextStyle?.fontWeight,
      FontWeight.w500,
    );
  });
}
