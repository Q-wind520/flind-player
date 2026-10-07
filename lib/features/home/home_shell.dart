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
import 'package:flind_player/l10n/app_localizations.dart';
import 'package:flind_player/shared/app_surface.dart';

/// Adaptive application shell.
///
/// Below [AppBreakpoints.compact] navigation lives in a bottom
/// [NavigationBar]; at or above it, a leading [NavigationRail] is used. In both
/// layouts the [MiniPlayerBar] floats over the content: the content scrolls
/// behind it and reserves its height as a bottom inset, so a list's tonal panel
/// extends under the bar and the last row still clears it. Tapping the mini
/// player opens the full-screen now-playing player on every platform and window
/// size.
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

  /// Key on the floating mini player so its height can be measured after
  /// layout and reserved as the content's bottom inset.
  final GlobalKey _miniPlayerKey = GlobalKey();

  /// The measured height of the floating mini player (0 when nothing plays).
  double _miniPlayerHeight = 0;

  static const List<Widget> _screens = <Widget>[
    SearchScreen(),
    LibraryScreen(),
    SettingsScreen(),
  ];

  List<NavigationDestination> _destinations(AppLocalizations l10n) =>
      <NavigationDestination>[
        NavigationDestination(
          icon: const Icon(Icons.search_outlined),
          selectedIcon: const Icon(Icons.search),
          label: l10n.navSearch,
          // Empty message suppresses the label hover bubble.
          tooltip: '',
        ),
        NavigationDestination(
          icon: const Icon(Icons.library_music_outlined),
          selectedIcon: const Icon(Icons.library_music),
          label: l10n.navLibrary,
          // Empty message suppresses the label hover bubble.
          tooltip: '',
        ),
        NavigationDestination(
          icon: const Icon(Icons.settings_outlined),
          selectedIcon: const Icon(Icons.settings),
          label: l10n.navSettings,
          // Empty message suppresses the label hover bubble.
          tooltip: '',
        ),
      ];

  List<NavigationRailDestination> _railDestinations(AppLocalizations l10n) =>
      <NavigationRailDestination>[
        NavigationRailDestination(
          icon: const Icon(Icons.search_outlined),
          selectedIcon: const Icon(Icons.search),
          label: Text(l10n.navSearch),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.library_music_outlined),
          selectedIcon: const Icon(Icons.library_music),
          label: Text(l10n.navLibrary),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.settings_outlined),
          selectedIcon: const Icon(Icons.settings),
          label: Text(l10n.navSettings),
        ),
      ];

  void _onDestinationSelected(int index) {
    if (index == _selectedIndex) {
      return;
    }
    setState(() => _selectedIndex = index);
  }

  /// Measures [MiniPlayerBar] once it has laid out so the content can reserve
  /// exactly its height as a bottom inset.
  void _measureMiniPlayer() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _miniPlayerKey.currentContext?.findRenderObject() as RenderBox?;
      final height = box?.size.height ?? 0;
      if ((height - _miniPlayerHeight).abs() > 0.5) {
        setState(() => _miniPlayerHeight = height);
      }
    });
  }

  /// Wraps [content] with the floating [MiniPlayerBar] overlaid at its bottom.
  ///
  /// The content's `MediaQuery` bottom padding is raised by the bar's measured
  /// height, so a scrollable inside reserves room for it: the list tone extends
  /// behind the bar while the last row scrolls clear of it.
  Widget _withMiniPlayerOverlay(Widget content) {
    return Stack(
      children: [
        Positioned.fill(
          child: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: MediaQuery.of(context).padding.copyWith(
                  bottom:
                      MediaQuery.of(context).padding.bottom + _miniPlayerHeight,
                ),
              ),
              child: content,
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: KeyedSubtree(
            key: _miniPlayerKey,
            child: const MiniPlayerBar(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    _measureMiniPlayer();
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = AppBreakpoints.isCompact(constraints.biggest);
        final content = IndexedStack(index: _selectedIndex, children: _screens);

        if (!compact) {
          return Scaffold(
            backgroundColor: AppSurface.colorOf(context),
            body: SafeArea(
              child: Row(
                children: [
                  NavigationRail(
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: _onDestinationSelected,
                    // Like the compact NavigationBar: only the selected
                    // destination shows its label.
                    labelType: NavigationRailLabelType.selected,
                    destinations: _railDestinations(l10n),
                  ),
                  Expanded(child: _withMiniPlayerOverlay(content)),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppSurface.colorOf(context),
          body: _withMiniPlayerOverlay(content),
          bottomNavigationBar: NavigationBar(
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onDestinationSelected,
            destinations: _destinations(l10n),
          ),
        );
      },
    );
  }
}
