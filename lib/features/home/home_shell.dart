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
import 'package:flind_player/features/search/search_screen.dart';
import 'package:flind_player/features/settings/settings_screen.dart';

/// Adaptive application shell.
///
/// Below [AppBreakpoints.compact] navigation lives in a bottom
/// [NavigationBar] with the [MiniPlayerBar] above it; at or above it, a
/// leading [NavigationRail] is used with the mini player below the content.
/// Tapping the mini player opens the full-screen now-playing player on every
/// platform and window size.
///
/// The shell only provides navigation chrome — each destination owns its own
/// `Scaffold`/`AppBar`.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  /// Below this window height the [NavigationRail] drops its always-visible
  /// labels: three labelled destinations need roughly 240 px, and stacking
  /// them in a very short window would overflow the rail.
  static const double _railLabelsMinHeight = 420;

  static const List<Widget> _screens = <Widget>[
    SearchScreen(),
    LibraryScreen(),
    SettingsScreen(),
  ];

  static const List<NavigationDestination> _destinations =
      <NavigationDestination>[
        NavigationDestination(
          icon: Icon(Icons.search_outlined),
          selectedIcon: Icon(Icons.search),
          label: '搜索',
        ),
        NavigationDestination(
          icon: Icon(Icons.library_music_outlined),
          selectedIcon: Icon(Icons.library_music),
          label: '曲库',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: '设置',
        ),
      ];

  static const List<NavigationRailDestination> _railDestinations =
      <NavigationRailDestination>[
        NavigationRailDestination(
          icon: Icon(Icons.search_outlined),
          selectedIcon: Icon(Icons.search),
          label: Text('搜索'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.library_music_outlined),
          selectedIcon: Icon(Icons.library_music),
          label: Text('曲库'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: Text('设置'),
        ),
      ];

  void _onDestinationSelected(int index) {
    if (index == _selectedIndex) {
      return;
    }
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = AppBreakpoints.isCompact(constraints.biggest);
        if (!compact) {
          final showRailLabels = constraints.maxHeight >= _railLabelsMinHeight;
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  NavigationRail(
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: _onDestinationSelected,
                    labelType: showRailLabels
                        ? NavigationRailLabelType.all
                        : NavigationRailLabelType.selected,
                    destinations: _railDestinations,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: IndexedStack(
                            index: _selectedIndex,
                            children: _screens,
                          ),
                        ),
                        const MiniPlayerBar(),
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
