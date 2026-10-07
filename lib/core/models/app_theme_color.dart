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

import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';

/// The seed colour every Material 3 colour scheme is derived from.
///
/// Stored as a plain ARGB integer so it survives a `shared_preferences` round
/// trip without depending on a UI type. [recommended] are the built-in swatches
/// offered by the picker; [defaults] is the brand green and leads the list.
@immutable
class AppThemeColor {
  /// Wraps the ARGB [argb] value of the chosen seed.
  const AppThemeColor(this.argb);

  /// The packed 0xAARRGGBB value.
  final int argb;

  /// The brand teal green used until the user picks something else.
  static const AppThemeColor defaults = AppThemeColor(0xFF1BA784);

  /// The four swatches offered by the picker: brand green, blue, purple, amber.
  static const List<AppThemeColor> recommended = <AppThemeColor>[
    defaults,
    AppThemeColor(0xFF3B82F6),
    AppThemeColor(0xFF8B5CF6),
    AppThemeColor(0xFFF59E0B),
  ];

  /// The seed as a Flutter [Color], for `ColorScheme.fromSeed`.
  Color toColor() => Color(argb);

  /// The opaque colour as `#RRGGBB`, for display and the hex field.
  String toHex() =>
      '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  /// Parses `#RRGGBB` or `RRGGBB` case-insensitively into an opaque colour.
  ///
  /// Returns `null` for anything else, so a half-typed hex field can be
  /// rejected without throwing.
  static AppThemeColor? tryParseHex(String input) {
    final digits = input.startsWith('#') ? input.substring(1) : input;
    if (digits.length != 6) return null;
    final rgb = int.tryParse(digits, radix: 16);
    if (rgb == null) return null;
    return AppThemeColor(0xFF000000 | rgb);
  }

  @override
  bool operator ==(Object other) =>
      other is AppThemeColor && other.argb == argb;

  @override
  int get hashCode => argb.hashCode;

  @override
  String toString() => 'AppThemeColor(${toHex()})';
}
