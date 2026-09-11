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
import 'package:flind_player/features/library/library_screen.dart';
import 'package:flind_player/features/player/mini_player_bar.dart';
import 'package:flind_player/features/player/player_screen.dart';
import 'package:flind_player/features/search/search_screen.dart';
import 'package:flind_player/features/settings/settings_screen.dart';

/// Adaptive application shell.
///
/// Below [AppBreakpoints.compact] navigation lives in a bottom
/// [NavigationBar] with the [MiniPlayerBar] above it; at or above it, a
/// leading [NavigationRail] is used with the mini player below the content.
///
/// At or above [AppBreakpoints.playerPanel] tapping the mini bar toggles a
/// docked right-hand side panel instead of opening a modal bottom sheet.
/// The shell only provides navigation chrome — each destination owns its own
/// `Scaffold`/`AppBar`.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  /// Well-known key for the docked player panel (wide screens only).
  static const Key playerPanelKey = Key('player_panel');

  /// Well-known key for the panel close button.
  static const Key playerPanelCloseKey = Key('player_panel_close');

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;
  bool _playerPanelOpen = false;

  static const List<Widget> _screens = <Widget>[
    SearchScreen(),
    LibraryScreen(),
    SettingsScreen(),
  ];

  static const List<NavigationDestination> _destinations =
      <NavigationDestination>[
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: '首页',
        ),
        NavigationDestination(
          icon: Icon(Icons.library_music_outlined),
          selectedIcon: Icon(Icons.library_music),
          label: '曲库',
        ),
        NavigationDestination(
          icon: Icon(Icons.account_circle_outlined),
          selectedIcon: Icon(Icons.account_circle),
          label: '账户',
        ),
      ];

  static const List<NavigationRailDestination> _railDestinations =
      <NavigationRailDestination>[
        NavigationRailDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: Text('首页'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.library_music_outlined),
          selectedIcon: Icon(Icons.library_music),
          label: Text('曲库'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.account_circle_outlined),
          selectedIcon: Icon(Icons.account_circle),
          label: Text('账户'),
        ),
      ];

  void _onDestinationSelected(int index) {
    if (index == _selectedIndex) {
      return;
    }
    setState(() => _selectedIndex = index);
  }

  void _togglePlayerPanel() {
    setState(() => _playerPanelOpen = !_playerPanelOpen);
  }

  void _closePlayerPanel() {
    setState(() => _playerPanelOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final expanded = constraints.maxWidth >= AppBreakpoints.compact;
        final wideEnoughForPanel =
            constraints.maxWidth >= AppBreakpoints.playerPanel;
        if (expanded) {
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  NavigationRail(
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: _onDestinationSelected,
                    labelType: NavigationRailLabelType.all,
                    destinations: _railDestinations,
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Expanded(
                                child: IndexedStack(
                                  index: _selectedIndex,
                                  children: _screens,
                                ),
                              ),
                              MiniPlayerBar(
                                onTap: wideEnoughForPanel
                                    ? _togglePlayerPanel
                                    : null,
                              ),
                            ],
                          ),
                        ),
                        if (_playerPanelOpen && wideEnoughForPanel) ...[
                          const VerticalDivider(width: 1, thickness: 1),
                          _PlayerPanel(onClose: _closePlayerPanel),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          body: IndexedStack(index: _selectedIndex, children: _screens),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MiniPlayerBar(),
              NavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: _onDestinationSelected,
                destinations: _destinations,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Docked player panel shown on wide screens (>= [AppBreakpoints.playerPanel]).
///
/// Displays [PlayerView] in a fixed-width trailing column with a close affordance.
class _PlayerPanel extends StatelessWidget {
  const _PlayerPanel({required this.onClose});

  final VoidCallback onClose;

  static const double panelWidth = 400;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      key: HomeShell.playerPanelKey,
      width: panelWidth,
      child: ColoredBox(
        color: scheme.surface,
        child: Column(
          children: [
            // Header row with title and close button.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  Text('正在播放', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  IconButton(
                    key: HomeShell.playerPanelCloseKey,
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                    tooltip: '关闭播放器',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Player content.
            const Expanded(child: PlayerView()),
          ],
        ),
      ),
    );
  }
}
