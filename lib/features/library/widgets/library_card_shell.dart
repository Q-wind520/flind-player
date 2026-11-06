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
import 'package:flind_player/app/theme/app_tokens.dart';

/// Reserved height for a card's two-line title.
///
/// `bodyMedium` is 14 px with a 1.65 line height, so two lines need 46.2 px;
/// the old 40 px box clipped the second line's descenders.
const double libraryCardTitleHeight = 46;

/// Preferred maximum width of one grid card.
const double libraryCardMaxWidth = 260;

/// Gap between grid cards, horizontally and vertically.
const double libraryCardSpacing = 16;

/// The tonal surface shared by every cover card in the library.
///
/// A card is a framed panel rather than a bare cover floating on the page:
/// the near-black canvas hides a cover's dark edges, and a hairline plus an
/// [AppSpacing.sm] mat keeps the artwork readable. Hover, keyboard focus and
/// the currently-playing track all change the same border, so the state reads
/// at a glance without extra chrome.
class LibraryCardShell extends StatefulWidget {
  const LibraryCardShell({
    super.key,
    required this.child,
    required this.onTap,
    this.enabled = true,
    this.isPlaying = false,
    this.padding = const EdgeInsets.all(AppSpacing.sm),
  });

  /// Card content, laid out inside the shell's mat.
  final Widget child;

  final VoidCallback onTap;

  /// Disabled cards keep their surface but ignore hover and taps.
  final bool enabled;

  /// Tints the surface and border with the accent for the current track.
  final bool isPlaying;

  /// Mat around [child]. Full-bleed artwork cards pass [EdgeInsets.zero].
  final EdgeInsetsGeometry padding;

  @override
  State<LibraryCardShell> createState() => _LibraryCardShellState();
}

class _LibraryCardShellState extends State<LibraryCardShell> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final highlighted = widget.enabled && (_hovered || _focused);
    final radius = BorderRadius.circular(AppRadius.md);

    final Color background;
    if (widget.isPlaying) {
      // A wash rather than a solid accent: the artwork stays dominant.
      background = Color.alphaBlend(
        scheme.primary.withValues(alpha: 0.07),
        scheme.surfaceContainerLow,
      );
    } else if (highlighted) {
      background = scheme.surfaceContainer;
    } else {
      background = scheme.surfaceContainerLow;
    }

    final Color border;
    if (widget.isPlaying) {
      border = scheme.primary.withValues(alpha: 0.45);
    } else if (highlighted) {
      border = scheme.outline.withValues(alpha: 0.42);
    } else {
      border = scheme.outlineVariant.withValues(alpha: 0.55);
    }

    return AnimatedContainer(
      duration: AppMotion.fast,
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: background,
        borderRadius: radius,
        boxShadow: highlighted ? _hoverShadow(context) : const [],
      ),
      // Draw the border above the child so a full-bleed cover cannot hide it.
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: border),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        child: InkWell(
          onTap: widget.enabled ? widget.onTap : null,
          onHover: (value) {
            if (_hovered != value) setState(() => _hovered = value);
          },
          onFocusChange: (value) {
            if (_focused != value) setState(() => _focused = value);
          },
          borderRadius: radius,
          child: Padding(padding: widget.padding, child: widget.child),
        ),
      ),
    );
  }

  static List<BoxShadow> _hoverShadow(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: dark ? 0.28 : 0.10),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ];
  }
}

/// The equalizer mark overlaid on a playing cover.
class NowPlayingBadge extends StatelessWidget {
  const NowPlayingBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Icon(AppIcons.graphicEq, size: 12, color: scheme.onPrimary),
      ),
    );
  }
}

/// Tonal gradient placeholder for a track or playlist without cover art.
class LibraryCoverPlaceholder extends StatelessWidget {
  const LibraryCoverPlaceholder({
    super.key,
    required this.icon,
    this.iconSize = 40,
  });

  final IconData icon;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.surfaceContainerHigh, scheme.surfaceContainerLow],
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          size: iconSize,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}
