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

/// Material 3 theme for Flind Player.
class AppTheme {
  const AppTheme._();

  /// Seed used to derive the Material 3 colour scheme (teal green).
  static const Color seedColor = Color(0xFF1BA784);

  /// Light theme.
  static final ThemeData light = _build(Brightness.light);

  /// Dark theme.
  static final ThemeData dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      // Every SnackBar renders as a rounded floating bubble clear of the
      // screen edges instead of a full-width bottom bar.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
