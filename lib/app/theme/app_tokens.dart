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

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

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
@immutable
class AppRadius {
  const AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;

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
