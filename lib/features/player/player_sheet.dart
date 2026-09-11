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

import 'package:flind_player/features/player/player_screen.dart';

/// A modal bottom sheet that presents the full now-playing UI.
///
/// The sheet occupies ~92 % of the screen height with a rounded-top surface
/// and a drag handle. Dragging down dismisses it (default modal behaviour).
class PlayerSheet extends StatelessWidget {
  const PlayerSheet({super.key});

  /// A well-known key so tests can assert the sheet is showing.
  static const Key dragHandleKey = Key('player_sheet_drag_handle');

  /// Opens the player as a modal bottom sheet.
  static Future<void> showPlayerSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PlayerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final sheetHeight = mediaQuery.size.height * 0.92;

    return DraggableScrollableSheet(
      initialChildSize: sheetHeight / mediaQuery.size.height,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          height: sheetHeight,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Drag handle.
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  key: dragHandleKey,
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withAlpha(128),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Player content.
              const Expanded(child: PlayerView()),
            ],
          ),
        );
      },
    );
  }
}
