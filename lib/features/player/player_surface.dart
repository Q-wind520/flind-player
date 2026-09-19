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

/// The single background surface shared by the player screen and every player
/// chrome element (mini player bar, MiniSettings, volume bar, lyrics strip).
///
/// Every player background goes through this widget so a future transparent /
/// glass style can be introduced in one place without touching each widget.
class PlayerSurface extends StatelessWidget {
  const PlayerSurface({super.key, required this.child, this.borderRadius});

  final Widget child;
  final BorderRadius? borderRadius;

  /// The flat colour every player surface uses today.
  static Color colorOf(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerHigh;

  @override
  Widget build(BuildContext context) => Material(
    color: colorOf(context),
    borderRadius: borderRadius,
    clipBehavior: borderRadius == null ? Clip.none : Clip.antiAlias,
    child: child,
  );
}
