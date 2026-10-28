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

import 'package:flind_player/app/theme/app_icons.dart';
import 'package:flind_player/app/theme/app_theme.dart';
import 'package:flind_player/app/theme/app_tokens.dart';
import 'package:flind_player/features/library/library_screen.dart';
import 'package:flind_player/features/player/desktop_player_bar.dart';
import 'package:flind_player/features/player/mini_player_bar.dart';
import 'package:flind_player/features/search/search_screen.dart';
import 'package:flind_player/features/settings/settings_screen.dart';
import 'package:flind_player/l10n/app_localizations.dart';
import 'package:flind_player/shared/app_surface.dart';
import 'package:flind_player/shared/glass_surface.dart';

/// Adaptive application shell.
///
/// Expanded windows get a dedicated sidebar and a fixed, full-width
/// now-playing bar below the content. Compact windows keep the gesture-first
/// bottom chrome, with the mini player and navigation sharing one glass dock.
/// Each destination still owns its own `Scaffold`.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = <Widget>[
    SearchScreen(),
    LibraryScreen(),
    SettingsScreen(),
  ];

  List<NavigationDestination> _destinations(AppLocalizations l10n) =>
      <NavigationDestination>[
        NavigationDestination(
          icon: const Icon(AppIcons.searchOutlined),
          selectedIcon: const Icon(AppIcons.search),
          label: l10n.navSearch,
          // Empty message suppresses the label hover bubble.
          tooltip: '',
        ),
        NavigationDestination(
          icon: const Icon(AppIcons.libraryMusicOutlined),
          selectedIcon: const Icon(AppIcons.libraryMusic),
          label: l10n.navLibrary,
          tooltip: '',
        ),
        NavigationDestination(
          icon: const Icon(AppIcons.settingsOutlined),
          selectedIcon: const Icon(AppIcons.settings),
          label: l10n.navSettings,
          tooltip: '',
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
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = AppBreakpoints.isCompact(constraints.biggest);

        if (!compact) {
          return Scaffold(
            backgroundColor: AppSurface.colorOf(context),
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        _NarrowRail(
                          selectedIndex: _selectedIndex,
                          onDestinationSelected: _onDestinationSelected,
                          destinations: <_RailDestination>[
                            _RailDestination(
                              icon: AppIcons.searchOutlined,
                              selectedIcon: AppIcons.search,
                              label: l10n.navSearch,
                            ),
                            _RailDestination(
                              icon: AppIcons.libraryMusicOutlined,
                              selectedIcon: AppIcons.libraryMusic,
                              label: l10n.navLibrary,
                            ),
                            _RailDestination(
                              icon: AppIcons.settingsOutlined,
                              selectedIcon: AppIcons.settings,
                              label: l10n.navSettings,
                            ),
                          ],
                        ),
                        Expanded(
                          child: IndexedStack(
                            index: _selectedIndex,
                            children: _screens,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const DesktopPlayerBar(),
                ],
              ),
            ),
          );
        }

        final scheme = Theme.of(context).colorScheme;
        return Scaffold(
          backgroundColor: AppSurface.colorOf(context),
          // The list extends behind the bottom chrome so the frosted dock
          // blurs it instead of sitting on a flat background.
          extendBody: true,
          body: IndexedStack(index: _selectedIndex, children: _screens),
          bottomNavigationBar: SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              0,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: GlassSurface(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              tint: AppGlass.navBarTintOn(scheme),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.6),
              ),
              boxShadow: AppGlass.shadow,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const MiniPlayerBar(embedded: true),
                  NavigationBar(
                    labelBehavior:
                        NavigationDestinationLabelBehavior.onlyShowSelected,
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: _onDestinationSelected,
                    destinations: _destinations(l10n),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One destination in the narrow rail.
class _RailDestination {
  const _RailDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// The narrow desktop navigation rail.
///
/// A hand-built rail instead of [NavigationRail] so the selected/hover fill is
/// a circle behind the icon (the stock rail paints a square highlight), a tap
/// paints no rounded-rectangle ripple over the item, and the label cross-fades
/// exactly like the compact bottom bar's.
class _NarrowRail extends StatelessWidget {
  const _NarrowRail({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<_RailDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('app_narrow_rail'),
      width: 76,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(
        children: [
          const _RailBrand(),
          for (var i = 0; i < destinations.length; i++)
            _RailItem(
              key: ValueKey<String>('rail_destination_$i'),
              destination: destinations[i],
              selected: i == selectedIndex,
              onTap: () => onDestinationSelected(i),
            ),
        ],
      ),
    );
  }
}

class _RailItem extends StatefulWidget {
  const _RailItem({
    super.key,
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _RailDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_RailItem> createState() => _RailItemState();
}

class _RailItemState extends State<_RailItem>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  bool _focused = false;

  // The compact `NavigationBar`'s label cross-fade, mirrored here so the rail
  // and the bottom bar reveal a label the same way: 500 ms, emphasised easing,
  // a mirrored curve while fading back out.
  static const Duration _labelDuration = Duration(milliseconds: 500);

  late final AnimationController _label = AnimationController(
    vsync: this,
    duration: _labelDuration,
    value: widget.selected ? 1 : 0,
  );

  late final Animation<double> _labelOpacity = CurvedAnimation(
    parent: _label,
    curve: Curves.easeInOutCubicEmphasized,
    reverseCurve: Curves.easeInOutCubicEmphasized.flipped,
  );

  @override
  void didUpdateWidget(covariant _RailItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      widget.selected ? _label.forward() : _label.reverse();
    }
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selected = widget.selected;
    final background = selected
        ? scheme.primary.withValues(alpha: 0.14)
        : _hovered
        ? scheme.onSurface.withValues(alpha: 0.06)
        : Colors.transparent;
    final radius = BorderRadius.circular(AppRadius.md);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Semantics(
        button: true,
        selected: selected,
        label: widget.destination.label,
        excludeSemantics: true,
        child: Tooltip(
          message: widget.destination.label,
          waitDuration: const Duration(milliseconds: 600),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: radius,
              hoverColor: Colors.transparent,
              focusColor: Colors.transparent,
              highlightColor: Colors.transparent,
              // The ripple would be clipped into a large rounded-rectangle
              // overlay across the whole item; the circular fill below is the
              // only feedback this destination paints.
              splashFactory: NoSplash.splashFactory,
              onHover: (value) => setState(() => _hovered = value),
              onFocusChange: (value) => setState(() => _focused = value),
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 6,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // A circular fill carries selected/hover; the ring is
                    // painted only for keyboard focus.
                    AnimatedContainer(
                      duration: AppMotion.fast,
                      curve: AppMotion.standardCurve,
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: background,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _focused ? scheme.primary : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        selected
                            ? widget.destination.selectedIcon
                            : widget.destination.icon,
                        size: 22,
                        color: selected
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FadeTransition(
                      alwaysIncludeSemantics: true,
                      opacity: _labelOpacity,
                      child: Text(
                        widget.destination.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The compact brand mark at the top of the narrow rail.
class _RailBrand extends StatelessWidget {
  const _RailBrand();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.xl),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: scheme.primary,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: scheme.onPrimary.withValues(alpha: 0.7),
              width: 1.2,
            ),
          ),
          alignment: Alignment.center,
          child: Container(
            width: 2.5,
            height: 2.5,
            decoration: BoxDecoration(
              color: scheme.onPrimary,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
