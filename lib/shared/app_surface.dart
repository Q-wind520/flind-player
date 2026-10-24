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

/// The single background surface shared by every screen and player chrome
/// element (mini player bar, MiniSettings, volume bar, lyrics strip).
///
/// Every page background goes through this widget (or [colorOf]) so the
/// neutral canvas is defined once. Raised surfaces use the colour scheme's
/// container roles instead.
class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.borderRadius,
    this.color,
  });

  final Widget child;
  final BorderRadius? borderRadius;

  /// Overrides the flat surface colour for chrome that must stand out from the
  /// page (e.g. the floating mini player). Defaults to [colorOf].
  final Color? color;

  /// The neutral page canvas.
  static Color colorOf(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  @override
  Widget build(BuildContext context) => Material(
    color: color ?? colorOf(context),
    borderRadius: borderRadius,
    clipBehavior: borderRadius == null ? Clip.none : Clip.antiAlias,
    child: child,
  );
}
