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

/// Spacing scale in logical pixels, on a 4pt base.
@immutable
class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Corner-radius scale in logical pixels.
///
/// Four values only: `sm` for covers and compact controls, `md` for cards and
/// fields, `lg` for sheets, the player artwork and floating chrome, and `pill`
/// for fully rounded buttons and chips.
@immutable
class AppRadius {
  const AppRadius._();

  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;

  /// Fully rounded (chips, pills).
  static const double pill = 999;
}

/// Motion durations and curves, shared by every animated transition.
@immutable
class AppMotion {
  const AppMotion._();

  /// Short feedback: presses and colour transitions.
  static const Duration fast = Duration(milliseconds: 150);

  /// The default duration for most state changes.
  static const Duration standard = Duration(milliseconds: 250);

  /// Large transitions, such as the mini player growing into the player.
  static const Duration emphasized = Duration(milliseconds: 400);

  /// The default easing for state changes.
  static const Curve standardCurve = Curves.easeInOutCubic;

  /// The easing for large entrance transitions.
  static const Curve emphasizedCurve = Curves.easeOutCubic;
}

/// Frosted-glass tokens for the bottom chrome.
@immutable
class AppGlass {
  const AppGlass._();

  /// Backdrop blur strength (Gaussian sigma).
  static const double blurSigma = 14;

  /// The translucent tint laid over the blur. Heavier in light mode so text
  /// stays legible; lighter in dark mode so the glass reads as glass.
  static Color tintOn(ColorScheme scheme) => scheme.surface.withValues(
    alpha: scheme.brightness == Brightness.light ? 0.72 : 0.62,
  );

  /// A more opaque tint for the full-width bottom navigation bar, whose larger
  /// area would otherwise read as too see-through over busy content.
  static Color navBarTintOn(ColorScheme scheme) => scheme.surface.withValues(
    alpha: scheme.brightness == Brightness.light ? 0.90 : 0.85,
  );

  /// A 1px highlight along the top edge of a glass sheet.
  static Border topEdgeOn(ColorScheme scheme) => Border(
    top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
  );

  /// The soft shadow shared by glass sheets and the floating mini capsule.
  static const List<BoxShadow> shadow = [
    BoxShadow(
      color: Color(0x1F000000), // ~12% black
      blurRadius: 18,
      offset: Offset(0, 6),
    ),
  ];
}
