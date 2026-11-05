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
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/features/library/widgets/library_card_shell.dart';
import 'package:flind_player/features/library/widgets/track_actions_button.dart';
import 'package:flind_player/l10n/app_localizations.dart';
import 'package:flind_player/shared/cover_image.dart';
import 'package:flind_player/shared/duration_format.dart';

/// A single library row with cover, title, artist, source badge, duration and
/// a consolidated actions popup menu.
class TrackTile extends StatelessWidget {
  const TrackTile({
    required this.track,
    required this.isCurrent,
    required this.isPlaying,
    required this.onTap,
    this.playlistId,
    this.showDeleteTrack = false,
    this.unavailable = false,
    super.key,
  });

  final Track track;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback onTap;

  /// The playlist this tile is rendered inside, when non-null. Forwarded to
  /// [TrackActionsButton] so its menu can offer "remove from playlist".
  final int? playlistId;

  /// Whether to show the "删除歌曲" menu item.
  final bool showDeleteTrack;

  /// Whether [track] could not be resolved to a playable row. Unresolvable
  /// rows stay visible but are dimmed and announce
  /// [AppLocalizations.trackUnavailable] instead of the artist.
  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TrackListRow(
      track: track,
      isCurrent: isCurrent,
      isPlaying: isPlaying,
      unavailable: unavailable,
      onTap: unavailable ? null : onTap,
      showSourceBadge: true,
      subtitle: unavailable
          ? l10n.trackUnavailable
          : track.artist ?? l10n.unknownArtist,
      action: TrackActionsButton(
        track: track,
        playlistId: playlistId,
        showDeleteTrack: showDeleteTrack,
      ),
    );
  }
}

/// The shared track row used by the library and online search.
///
/// Cover, text stack, playing indicator and duration are always laid out the
/// same way; each surface supplies its own [action] menu. The current row
/// grows a soft accent wash that animates in and out.
class TrackListRow extends StatelessWidget {
  const TrackListRow({
    super.key,
    required this.track,
    required this.isCurrent,
    required this.isPlaying,
    required this.onTap,
    required this.subtitle,
    this.showSourceBadge = false,
    this.unavailable = false,
    this.action,
  });

  final Track track;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback? onTap;
  final String subtitle;
  final bool showSourceBadge;
  final bool unavailable;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: isCurrent ? 1 : 0),
      duration: AppMotion.standard,
      curve: AppMotion.standardCurve,
      builder: (context, tint, child) {
        final background = tint > 0.001
            ? AppTheme.playingRowTint(
                scheme,
                AppTheme.playingRowTintAlpha * tint,
              )
            : Colors.transparent;
        return Material(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Opacity(
                    opacity: unavailable ? 0.55 : 1,
                    child: TrackCover(track: track, size: 48),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: unavailable
                                ? scheme.onSurfaceVariant
                                : scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            if (showSourceBadge) ...[
                              const SizedBox(width: AppSpacing.sm),
                              SourceBadge(source: track.source),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isPlaying) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Icon(AppIcons.graphicEq, size: 18, color: scheme.primary),
                  ],
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    formatTrackDuration(track.duration),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (action != null) ...[
                    const SizedBox(width: AppSpacing.xs),
                    action!,
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A card tile for the showcase (展柜) grid view.
///
/// Shows a square cover, title, artist, source badge, playing indicator, and
/// a trailing actions button overlaid in the top-right corner.
class TrackCard extends StatelessWidget {
  const TrackCard({
    required this.track,
    required this.isPlaying,
    required this.onTap,
    this.playlistId,
    this.showDeleteTrack = false,
    this.unavailable = false,
    super.key,
  });

  final Track track;
  final bool isPlaying;
  final VoidCallback onTap;

  /// The playlist this card is rendered inside, when non-null. Forwarded to
  /// [TrackActionsButton] so its menu can offer "remove from playlist".
  final int? playlistId;

  /// Whether to show the "删除歌曲" menu item.
  final bool showDeleteTrack;

  /// Whether [track] could not be resolved to a playable row. Unresolvable
  /// rows stay visible but are dimmed and announce
  /// [AppLocalizations.trackUnavailable] instead of the artist.
  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return LibraryCardShell(
      onTap: onTap,
      enabled: !unavailable,
      isPlaying: isPlaying,
      child: Opacity(
        opacity: unavailable ? 0.55 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  TrackCover(
                    track: track,
                    size: double.infinity,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  if (isPlaying)
                    Positioned(
                      bottom: AppSpacing.sm,
                      left: AppSpacing.sm,
                      child: NowPlayingBadge(label: l10n.nowPlaying),
                    ),
                  Positioned(
                    top: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: ClipOval(
                      child: ColoredBox(
                        color: scheme.surface.withValues(alpha: 0.68),
                        child: TrackActionsButton(
                          track: track,
                          playlistId: playlistId,
                          showDeleteTrack: showDeleteTrack,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, AppSpacing.sm, 0, 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: libraryCardTitleHeight,
                    child: Text(
                      track.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          unavailable
                              ? l10n.trackUnavailable
                              : track.artist ?? l10n.unknownArtist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      SourceBadge(source: track.source, chip: true),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small tonal chip naming the track's source.
///
/// Rows use the bare dot + label; cards pass [chip] so the source reads as a
/// self-contained tag on the card surface instead of loose text.
class SourceBadge extends StatelessWidget {
  const SourceBadge({required this.source, this.chip = false, super.key});

  final String source;

  /// Whether to draw the pill background. Cards enable this; rows do not.
  final bool chip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final label = switch (source) {
      'local' => l10n.sourceLocal,
      'bilibili' => l10n.sourceBilibili,
      'netease' => l10n.sourceNetease,
      _ => source,
    };

    final marker = switch (source) {
      'bilibili' => const Color(0xFFFB7299),
      'netease' => const Color(0xFFE0463D),
      _ => scheme.onSurfaceVariant.withValues(alpha: 0.55),
    };

    final text = Text(
      label,
      style: (chip ? theme.textTheme.labelSmall : theme.textTheme.labelMedium)
          ?.copyWith(color: scheme.onSurfaceVariant),
    );
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(color: marker, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs),
        text,
      ],
    );
    if (!chip) return content;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: content,
    );
  }
}

/// Rounded cover art, falling back to a tonal music-note placeholder.
class TrackCover extends StatelessWidget {
  const TrackCover({
    required this.track,
    required this.size,
    this.borderRadius,
    super.key,
  });

  final Track track;

  /// Fixed size in pixels, or `double.infinity` when the cover should fill its
  /// parent (used inside the grid card's [Expanded] wrapper).
  final double size;

  /// Overrides the compact 8 px row radius; grid cards use 16.
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final coverPath = track.coverPath;
    final coverUrl = track.coverUrl;
    final hasCover =
        (coverPath != null && coverPath.isNotEmpty) ||
        (coverUrl != null && coverUrl.isNotEmpty);
    final useFixedSize = !size.isInfinite;
    final radius = borderRadius ?? BorderRadius.circular(AppRadius.sm);

    final child = Container(
      width: useFixedSize ? size : null,
      height: useFixedSize ? size : null,
      color: scheme.surfaceContainerHighest,
      child: hasCover
          ? CoverImage(
              path: coverPath,
              url: coverUrl,
              size: size,
              errorBuilder: (context, error, stackTrace) => _placeholder(),
            )
          : _placeholder(),
    );

    return Container(
      // A hairline keeps dark artwork from bleeding into the card mat. Compact
      // row thumbnails already sit inside a row, so they skip it.
      foregroundDecoration: useFixedSize
          ? null
          : BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
      child: ClipRRect(borderRadius: radius, child: child),
    );
  }

  Widget _placeholder() => LibraryCoverPlaceholder(
    icon: AppIcons.musicNote,
    iconSize: size.isInfinite ? 40 : size * 0.5,
  );
}
