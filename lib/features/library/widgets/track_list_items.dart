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

import 'package:flind_player/core/models/track.dart';
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

  /// Whether [track] could not be resolved to a playable row. Unresolvable
  /// rows stay visible but are dimmed and announce
  /// [AppLocalizations.trackUnavailable] instead of the artist.
  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return ListTile(
      onTap: unavailable ? null : onTap,
      enabled: !unavailable,
      selected: isCurrent,
      leading: TrackCover(track: track, size: 48),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              unavailable
                  ? l10n.trackUnavailable
                  : track.artist ?? l10n.unknownArtist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          SourceBadge(source: track.source),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPlaying) ...[
            Icon(Icons.graphic_eq, size: 20, color: scheme.primary),
            const SizedBox(width: 8),
          ],
          Text(
            formatTrackDuration(track.duration),
            style: theme.textTheme.labelMedium,
          ),
          TrackActionsButton(track: track, playlistId: playlistId),
        ],
      ),
    );
  }
}

/// A card tile for the wide-screen grid layout.
///
/// Shows a square cover, title, artist, source badge, playing indicator, and
/// a trailing actions button overlaid in the top-right corner.
class TrackCard extends StatelessWidget {
  const TrackCard({
    required this.track,
    required this.isCurrent,
    required this.isPlaying,
    required this.onTap,
    this.playlistId,
    this.unavailable = false,
    super.key,
  });

  final Track track;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback onTap;

  /// The playlist this card is rendered inside, when non-null. Forwarded to
  /// [TrackActionsButton] so its menu can offer "remove from playlist".
  final int? playlistId;

  /// Whether [track] could not be resolved to a playable row. Unresolvable
  /// rows stay visible but are dimmed and announce
  /// [AppLocalizations.trackUnavailable] instead of the artist.
  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: unavailable ? null : onTap,
        child: Opacity(
          opacity: unavailable ? 0.55 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    TrackCover(track: track, size: double.infinity),
                    if (isPlaying)
                      Positioned(
                        bottom: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(
                            Icons.graphic_eq,
                            size: 14,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: TrackActionsButton(
                        track: track,
                        playlistId: playlistId,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      unavailable
                          ? l10n.trackUnavailable
                          : track.artist ?? l10n.unknownArtist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    SourceBadge(source: track.source),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small tonal chip naming the track's source.
class SourceBadge extends StatelessWidget {
  const SourceBadge({required this.source, super.key});

  final String source;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final label = switch (source) {
      'local' => l10n.sourceLocal,
      'bilibili' => l10n.sourceBilibili,
      _ => source,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

/// Rounded cover art, falling back to a tonal music-note placeholder.
class TrackCover extends StatelessWidget {
  const TrackCover({required this.track, required this.size, super.key});

  final Track track;

  /// Fixed size in pixels, or `double.infinity` when the cover should fill its
  /// parent (used inside the grid card's [Expanded] wrapper).
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final coverPath = track.coverPath;
    final coverUrl = track.coverUrl;
    final hasCover =
        (coverPath != null && coverPath.isNotEmpty) ||
        (coverUrl != null && coverUrl.isNotEmpty);
    final useFixedSize = !size.isInfinite;
    final borderRadius = useFixedSize ? size * 0.16 : 4.0;

    Widget child = Container(
      width: useFixedSize ? size : null,
      height: useFixedSize ? size : null,
      color: scheme.surfaceContainerHighest,
      child: hasCover
          ? CoverImage(
              path: coverPath,
              url: coverUrl,
              size: size,
              errorBuilder: (context, error, stackTrace) =>
                  _placeholder(scheme),
            )
          : _placeholder(scheme),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: child,
    );
  }

  Widget _placeholder(ColorScheme scheme) => Center(
    child: Icon(
      Icons.music_note,
      size: size.isInfinite ? 40 : size * 0.5,
      color: scheme.onSurfaceVariant,
    ),
  );
}
