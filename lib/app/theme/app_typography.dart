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

/// One type scale for every screen.
///
/// The CJK fallback is left to the platform, but size, weight, line height and
/// tracking are fixed here so Chinese and Latin text share the same rhythm.
/// Durations and counters use tabular figures so they do not jitter.
class AppTypography {
  const AppTypography._();

  static const List<FontFeature> _tabular = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  static TextTheme textTheme(ColorScheme scheme) {
    final base = ThemeData(
      brightness: scheme.brightness,
      useMaterial3: true,
    ).textTheme;

    TextStyle? build(
      TextStyle? style, {
      required double size,
      required double height,
      required FontWeight weight,
      double spacing = 0,
      Color? color,
      List<FontFeature>? features,
    }) {
      return style?.copyWith(
        fontSize: size,
        height: height,
        fontWeight: weight,
        letterSpacing: spacing,
        color: color,
        fontFeatures: features,
      );
    }

    return base.copyWith(
      displayLarge: build(
        base.displayLarge,
        size: 48,
        height: 1.02,
        weight: FontWeight.w800,
        spacing: -1.4,
        color: scheme.onSurface,
      ),
      displayMedium: build(
        base.displayMedium,
        size: 40,
        height: 1.06,
        weight: FontWeight.w800,
        spacing: -1,
        color: scheme.onSurface,
      ),
      displaySmall: build(
        base.displaySmall,
        size: 34,
        height: 1.1,
        weight: FontWeight.w700,
        spacing: -0.8,
        color: scheme.onSurface,
      ),
      headlineLarge: build(
        base.headlineLarge,
        size: 30,
        height: 1.18,
        weight: FontWeight.w700,
        spacing: -0.6,
        color: scheme.onSurface,
      ),
      headlineMedium: build(
        base.headlineMedium,
        size: 26,
        height: 1.22,
        weight: FontWeight.w700,
        spacing: -0.4,
        color: scheme.onSurface,
      ),
      headlineSmall: build(
        base.headlineSmall,
        size: 22,
        height: 1.3,
        weight: FontWeight.w700,
        spacing: -0.2,
        color: scheme.onSurface,
      ),
      titleLarge: build(
        base.titleLarge,
        size: 18,
        height: 1.4,
        weight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      titleMedium: build(
        base.titleMedium,
        size: 15,
        height: 1.5,
        weight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      titleSmall: build(
        base.titleSmall,
        size: 12,
        height: 1.3,
        weight: FontWeight.w600,
        spacing: 0.8,
        color: scheme.onSurfaceVariant,
      ),
      bodyLarge: build(
        base.bodyLarge,
        size: 15,
        height: 1.65,
        weight: FontWeight.w400,
        color: scheme.onSurface,
      ),
      bodyMedium: build(
        base.bodyMedium,
        size: 14,
        height: 1.65,
        weight: FontWeight.w400,
        color: scheme.onSurface,
      ),
      bodySmall: build(
        base.bodySmall,
        size: 12,
        height: 1.5,
        weight: FontWeight.w400,
        color: scheme.onSurface,
      ),
      labelLarge: build(
        base.labelLarge,
        size: 14,
        height: 1.3,
        weight: FontWeight.w600,
        spacing: 0.2,
        color: scheme.onSurface,
      ),
      labelMedium: build(
        base.labelMedium,
        size: 12,
        height: 1.3,
        weight: FontWeight.w500,
        spacing: 0.2,
        color: scheme.onSurfaceVariant,
        features: _tabular,
      ),
      labelSmall: build(
        base.labelSmall,
        size: 11,
        height: 1.3,
        weight: FontWeight.w500,
        spacing: 0.3,
        color: scheme.onSurfaceVariant,
        features: _tabular,
      ),
    );
  }
}
