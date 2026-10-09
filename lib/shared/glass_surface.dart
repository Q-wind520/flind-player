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
    this.boxShadow,
  });

  final Widget child;

  /// Clips the blur and tint to this radius; `null` leaves square corners.
  final BorderRadius? borderRadius;

  /// Backdrop blur strength.
  final double blurSigma;

  /// Optional edge highlight, painted above the child.
  final Border? border;

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
        decoration: BoxDecoration(color: AppGlass.tintOn(scheme)),
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(border: border, borderRadius: radius),
          child: child,
        ),
      ),
    );

    if (radius != null) {
      surface = ClipRRect(borderRadius: radius, child: surface);
    }

    return DecoratedBox(
      position: DecorationPosition.background,
      decoration: BoxDecoration(borderRadius: radius, boxShadow: boxShadow),
      child: surface,
    );
  }
}
