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

/// The app's neutral canvas. The user's theme colour only drives the accent
/// roles; surfaces stay paper-warm (light) or near-black (dark), so switching
/// the accent cannot repaint the whole app.
class AppPalette {
  const AppPalette._();

  static const Color _lightPage = Color(0xFFF7F3EA);
  static const Color _lightInk = Color(0xFF171411);
  static const Color _lightMuted = Color(0xFF6E675E);
  static const Color _lightOutline = Color(0xFF9A9185);
  static const Color _lightHairline = Color(0xFFDED6C8);

  static const Color _darkPage = Color(0xFF0D0D0F);
  static const Color _darkInk = Color(0xFFF2EEE6);
  static const Color _darkMuted = Color(0xFFA29B91);
  static const Color _darkOutline = Color(0xFF777066);
  static const Color _darkHairline = Color(0xFF2A292D);

  static ColorScheme light(Color seed) => _build(Brightness.light, seed);

  static ColorScheme dark(Color seed) => _build(Brightness.dark, seed);

  static ColorScheme _build(Brightness brightness, Color seed) {
    final base = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    final light = brightness == Brightness.light;
    return base.copyWith(
      surface: light ? _lightPage : _darkPage,
      surfaceTint: Colors.transparent,
      onSurface: light ? _lightInk : _darkInk,
      onSurfaceVariant: light ? _lightMuted : _darkMuted,
      outline: light ? _lightOutline : _darkOutline,
      outlineVariant: light ? _lightHairline : _darkHairline,
      // Raised surfaces get lighter in both modes. The light theme used to
      // place cards below the page, which inverted the depth metaphor between
      // light and dark.
      surfaceContainerLowest: light
          ? const Color(0xFFFFFDF8)
          : const Color(0xFF08080A),
      surfaceContainerLow: light
          ? const Color(0xFFFDFAF4)
          : const Color(0xFF141416),
      surfaceContainer: light
          ? const Color(0xFFF2ECE2)
          : const Color(0xFF19191C),
      surfaceContainerHigh: light
          ? const Color(0xFFEDE6DA)
          : const Color(0xFF1F1F23),
      surfaceContainerHighest: light
          ? const Color(0xFFE6DDD0)
          : const Color(0xFF27272C),
      surfaceDim: light ? const Color(0xFFE9E2D6) : const Color(0xFF050506),
      surfaceBright: light ? const Color(0xFFFFFCF6) : const Color(0xFF2E2E33),
      inverseSurface: light ? const Color(0xFF24211D) : _lightPage,
      onInverseSurface: light ? _lightPage : _lightInk,
      inversePrimary: base.primaryContainer,
      scrim: Colors.black,
    );
  }
}
