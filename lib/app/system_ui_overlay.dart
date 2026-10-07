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
import 'package:flutter/services.dart';

/// Applies [systemUiOverlayStyleFor] to the whole subtree.
///
/// Placed once in `MaterialApp.builder`, above the navigator, so the style
/// holds for every route. The app runs edge-to-edge on Android, so the system
/// bars sit on top of the app surface; leaving the status-bar colour to the
/// Activity theme paints it black (see `Theme.Light`'s
/// `android:statusBarColor`), which reads as a darker strip over the top
/// `SafeArea` inset. A transparent bar with contrast enforcement off keeps the
/// inset flush with the app surface, while the icon brightness follows the
/// theme so the clock and glyphs stay legible.
class AppSystemUiOverlay extends StatelessWidget {
  /// Wraps [child] in the platform's status-bar annotation.
  const AppSystemUiOverlay({super.key, required this.child});

  /// The subtree, typically the navigator.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiOverlayStyleFor(Theme.of(context).brightness),
      child: child,
    );
  }
}

/// The transparent-bars [SystemUiOverlayStyle] for a [brightness].
SystemUiOverlayStyle systemUiOverlayStyleFor(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    // iOS reads the background's brightness instead of the icons'.
    statusBarBrightness: dark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: dark
        ? Brightness.light
        : Brightness.dark,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarContrastEnforced: false,
  );
}
