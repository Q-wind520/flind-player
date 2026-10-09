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

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'package:flind_player/app/theme/app_tokens.dart';

/// A frosted-glass surface: a backdrop blur, a translucent tonal tint, an
/// optional edge highlight, a soft shadow, and rounded-corner clipping.
///
/// The blur samples what is painted behind the widget within the app (content
/// scrolling under a glass bar), never the desktop behind the window.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius,
    this.blurSigma = AppGlass.blurSigma,
    this.border,
    this.tint,
    this.boxShadow,
  });

  final Widget child;

  /// Clips the blur and tint to this radius; `null` leaves square corners.
  final BorderRadius? borderRadius;

  /// Backdrop blur strength.
  final double blurSigma;

  /// Optional edge highlight, painted above the child.
  final Border? border;

  /// Overrides the translucent tint (defaults to [AppGlass.tintOn]).
  final Color? tint;

  /// Optional shadow behind the surface.
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = borderRadius;

    Widget surface = BackdropFilter(
      filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
      child: DecoratedBox(
        position: DecorationPosition.background,
        decoration: BoxDecoration(color: tint ?? AppGlass.tintOn(scheme)),
        child: Material(
          // A transparent ink host so descendants (taps on the mini player)
          // paint their splashes above the glass instead of on the Scaffold's
          // Material behind it.
          type: MaterialType.transparency,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(border: border, borderRadius: radius),
            child: child,
          ),
        ),
      ),
    );

    // Always clip: an unclipped BackdropFilter blurs whatever lies behind it up
    // to the nearest ancestor clip (which can be the whole screen), so a
    // square-cornered bar must still bound its blur with a zero-radius clip.
    surface = ClipRRect(
      borderRadius: radius ?? BorderRadius.zero,
      child: surface,
    );

    return DecoratedBox(
      position: DecorationPosition.background,
      decoration: BoxDecoration(borderRadius: radius, boxShadow: boxShadow),
      child: surface,
    );
  }
}
