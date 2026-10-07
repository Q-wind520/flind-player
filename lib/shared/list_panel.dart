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

import 'package:flind_player/app/theme/app_tokens.dart';

/// A tonal, rounded panel the main track lists sit on.
///
/// The page background stays [`AppSurface`] (`surfaceContainerHigh`) and the
/// panel is `surfaceContainerLow`, so a list reads as a sheet resting on the
/// page. The panel clips its child to the rounded corners and casts a very
/// subtle shadow so it stays quiet in both light and dark themes.
class ListPanel extends StatelessWidget {
  const ListPanel({super.key, required this.child, this.padding});

  /// The list (or other content) shown on the panel.
  final Widget child;

  /// Padding between the panel edge and [child]. Defaults to [AppSpacing.xs].
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppRadius.xl);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          // A transparent Material so list tiles inside the panel keep a
          // Material ancestor for their background and ink splashes (the
          // panel's own colour is painted by the DecoratedBox behind).
          child: Material(
            type: MaterialType.transparency,
            child: Padding(
              padding: padding ?? const EdgeInsets.all(AppSpacing.xs),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
