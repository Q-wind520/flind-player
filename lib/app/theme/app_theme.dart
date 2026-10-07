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

import 'package:flind_player/app/theme/app_tokens.dart';

/// Material 3 theme for Flind Player.
class AppTheme {
  const AppTheme._();

  /// Light theme derived from the given [seed] colour.
  static ThemeData light(Color seed) => _build(Brightness.light, seed);

  /// Dark theme derived from the given [seed] colour.
  static ThemeData dark(Color seed) => _build(Brightness.dark, seed);

  /// Opacity of the primary colour painted behind the currently-playing row.
  static const double playingRowTintAlpha = 0.12;

  /// The tint painted behind the currently-playing list row (and any other
  /// `selected` list tile), at [opacity] of the scheme's primary colour.
  static Color playingRowTint(
    ColorScheme scheme, [
    double opacity = playingRowTintAlpha,
  ]) => scheme.primary.withValues(alpha: opacity);

  static ThemeData _build(Brightness brightness, Color seed) {
    // TODO(theme): derive the scheme from the platform wallpaper (Material You)
    // where the OS exposes it; no cross-platform solution yet.
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final labelMedium = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
    ).textTheme.labelMedium;
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        selectedTileColor: playingRowTint(colorScheme),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return labelMedium?.copyWith(
            color: selected
                ? colorScheme.onSurface
                : colorScheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        indicatorShape: const StadiumBorder(),
        selectedLabelTextStyle: labelMedium?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: labelMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        linearTrackColor: colorScheme.outlineVariant,
        linearMinHeight: 2,
      ),
      // Every SnackBar renders as a rounded floating bubble clear of the
      // screen edges instead of a full-width bottom bar.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }
}

/// Adaptive layout breakpoints, in logical pixels.
class AppBreakpoints {
  const AppBreakpoints._();

  /// Below this width the layout is compact (phone-like).
  static const double compact = 600;

  /// Below this width the layout is medium (tablet-like); above it expanded.
  static const double medium = 1000;

  /// Whether the window [size] should use the compact (phone/portrait)
  /// layout.
  ///
  /// A window is compact when it is narrower than [compact] logical px
  /// **or** at least as tall as it is wide.  This catches the common
  /// desktop case where the window is wide enough in px but squeezed into
  /// a portrait ratio (e.g. 700 × 1000) — that window must still get the
  /// single-column mobile layout.
  static bool isCompact(Size size) =>
      size.width < compact || size.height >= size.width;

  /// Whether the window [size] should use the expanded (two-pane)
  /// layout.  The inverse of [isCompact].
  static bool isExpanded(Size size) => !isCompact(size);
}
