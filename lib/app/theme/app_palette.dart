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
/// roles; surfaces stay neutral — white (light) or near-black (dark) — so
/// switching the accent cannot repaint the whole app.
class AppPalette {
  const AppPalette._();

  static const Color _lightPage = Color(0xFFFFFFFF);
  static const Color _lightInk = Color(0xFF16171A);
  static const Color _lightMuted = Color(0xFF64676E);
  static const Color _lightOutline = Color(0xFF8F929A);
  static const Color _lightHairline = Color(0xFFE2E3E8);

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
      // In the dark theme raised surfaces get lighter. The light theme's page
      // is already white, so its raised surfaces step down into a near-white
      // grey instead — otherwise fields and cards would vanish into the page.
      surfaceContainerLowest: light
          ? const Color(0xFFFFFFFF)
          : const Color(0xFF08080A),
      surfaceContainerLow: light
          ? const Color(0xFFF6F6F8)
          : const Color(0xFF141416),
      surfaceContainer: light
          ? const Color(0xFFF0F0F3)
          : const Color(0xFF19191C),
      surfaceContainerHigh: light
          ? const Color(0xFFEAEAEE)
          : const Color(0xFF1F1F23),
      surfaceContainerHighest: light
          ? const Color(0xFFE3E3E8)
          : const Color(0xFF27272C),
      surfaceDim: light ? const Color(0xFFEDEDF0) : const Color(0xFF050506),
      surfaceBright: light ? const Color(0xFFFFFFFF) : const Color(0xFF2E2E33),
      inverseSurface: light ? const Color(0xFF1B1C20) : _lightPage,
      onInverseSurface: light ? _lightPage : _lightInk,
      inversePrimary: base.primaryContainer,
      scrim: Colors.black,
    );
  }
}
