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

import 'package:flind_player/app/theme/app_theme.dart';

/// The single page heading used by the main destinations.
///
/// A large, left-aligned title anchors the page; actions sit on the baseline
/// on the right. Keeping this in one widget stops search, library and settings
/// from inventing three different header rhythms.
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const <Widget>[],
    this.compact,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;

  /// Overrides the responsive density; normally derived from the window width.
  final bool? compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompact =
        compact ?? MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    final horizontal = isCompact ? 16.0 : 28.0;
    final actionsRow = actions.isEmpty
        ? null
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                actions[i],
              ],
            ],
          );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontal,
        isCompact ? 12 : 24,
        horizontal - 8,
        isCompact ? 8 : 16,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 4)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: isCompact
                      ? theme.textTheme.headlineMedium
                      : theme.textTheme.headlineLarge,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actionsRow != null) ...[const SizedBox(width: 16), actionsRow],
        ],
      ),
    );
  }
}
