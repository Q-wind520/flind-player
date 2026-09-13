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

/// Centres [child] in the available space, scrolling instead of overflowing
/// when the viewport is shorter than the content.
///
/// Empty-state panels (an icon, a title and a hint) used to be a bare
/// [Center] around a non-scrollable [Column]. In a short window — a phone in
/// landscape or a squeezed desktop window — that column exceeded the viewport
/// and threw `RenderFlex overflowed`. This widget keeps the centred look when
/// there is room and becomes vertically scrollable when there is not.
class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({super.key, required this.child});

  /// The content to centre (typically a [Column] with a fixed intrinsic size).
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // An unbounded height cannot be used as a minimum; fall back to zero
        // so the widget still lays out in unbounded contexts.
        final minHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : 0.0;
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Center(child: child),
          ),
        );
      },
    );
  }
}
