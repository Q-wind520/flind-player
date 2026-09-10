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

  /// Seed used to derive the Material 3 colour scheme (deep violet).
  static const Color seedColor = Color(0xFF5E35B1);

  /// Light theme.
  static final ThemeData light = _build(Brightness.light);

  /// Dark theme.
  static final ThemeData dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    return ThemeData(useMaterial3: true, colorScheme: colorScheme);
  }
}

/// Adaptive layout breakpoints, in logical pixels.
class AppBreakpoints {
  const AppBreakpoints._();

  /// Below this width the layout is compact (phone-like).
  static const double compact = 600;

  /// Below this width the layout is medium (tablet-like); above it expanded.
  static const double medium = 1000;
}
