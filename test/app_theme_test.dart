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
        BorderRadius.circular(AppRadius.md),
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
        BorderRadius.circular(AppRadius.md),
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

  test('the playing row uses the primary tint and a rounded shape', () {
    for (final theme in [AppTheme.light(seed), AppTheme.dark(seed)]) {
      expect(
        theme.listTileTheme.selectedTileColor,
        AppTheme.playingRowTint(theme.colorScheme),
      );
      final shape = theme.listTileTheme.shape;
      expect(shape, isA<RoundedRectangleBorder>());
      expect(
        (shape! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(AppRadius.sm),
      );
    }
  });

  test('the bottom navigation bar is transparent so glass can show through', () {
    for (final theme in [AppTheme.light(seed), AppTheme.dark(seed)]) {
      expect(theme.navigationBarTheme.backgroundColor, Colors.transparent);
    }
  });

  test('the light canvas is white, not warm, and raised surfaces step away', () {
    final light = AppTheme.light(seed).colorScheme;
    // The page canvas is a clean white instead of the old paper cream.
    expect(light.surface, const Color(0xFFFFFFFF));
    int chroma(Color colour) {
      final r = (colour.r * 255).round();
      final g = (colour.g * 255).round();
      final b = (colour.b * 255).round();
      final max = r > g ? (r > b ? r : b) : (g > b ? g : b);
      final min = r < g ? (r < b ? r : b) : (g < b ? g : b);
      return max - min;
    }

    // Neither the page nor the panels carry a warm (yellow) cast.
    expect(chroma(light.surface), 0);
    expect(chroma(light.surfaceContainerLow), lessThanOrEqualTo(3));

    // Because the page is already white, panels must be slightly darker or
    // fields and cards would disappear into it.
    expect(
      light.surfaceContainerLow.computeLuminance(),
      lessThan(light.surface.computeLuminance()),
    );

    // The dark canvas keeps its near-black page.
    expect(AppTheme.dark(seed).colorScheme.surface, const Color(0xFF0D0D0F));
  });

  test('surfaces stay neutral when only the accent seed changes', () {
    const purple = Color(0xFF8B5CF6);
    final lightTeal = AppTheme.light(seed);
    final lightPurple = AppTheme.light(purple);
    final darkTeal = AppTheme.dark(seed);
    final darkPurple = AppTheme.dark(purple);

    expect(lightTeal.colorScheme.surface, lightPurple.colorScheme.surface);
    expect(
      lightTeal.colorScheme.surfaceContainerLow,
      lightPurple.colorScheme.surfaceContainerLow,
    );
    expect(darkTeal.colorScheme.surface, darkPurple.colorScheme.surface);
    expect(
      darkTeal.colorScheme.surfaceContainerLow,
      darkPurple.colorScheme.surfaceContainerLow,
    );
    expect(
      lightTeal.colorScheme.primary,
      isNot(equals(lightPurple.colorScheme.primary)),
    );
  });

  test('the shared type scale carries line height and tabular numerals', () {
    final theme = AppTheme.light(seed);
    expect(theme.textTheme.headlineLarge?.fontSize, 30);
    expect(theme.textTheme.bodyMedium?.height, 1.65);
    expect(theme.textTheme.labelMedium?.fontFeatures, isNotEmpty);
    expect(theme.textTheme.labelSmall?.fontFeatures, isNotEmpty);
  });
}
