// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flind_player/app/theme/app_tokens.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/features/library/cover_aspect_ratio_provider.dart';
import 'package:flind_player/features/library/widgets/library_card_shell.dart';
import 'package:flind_player/features/library/widgets/track_actions_button.dart';
import 'package:flind_player/features/library/widgets/track_list_items.dart';
import 'package:flind_player/l10n/app_localizations.dart';

/// A masonry card whose cover keeps its intrinsic aspect ratio.
class WaterfallTrackCard extends ConsumerWidget {
  const WaterfallTrackCard({
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
  final int? playlistId;
  final bool showDeleteTrack;
  final bool unavailable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    final coverKey = (track.coverPath?.isNotEmpty ?? false)
        ? track.coverPath!
        : (track.coverUrl ?? '');
    final ratio = coverKey.isEmpty
        ? 1.0
        : (ref.watch(coverAspectRatioProvider(coverKey)).value ?? 1.0);

    return LibraryCardShell(
      onTap: onTap,
      enabled: !unavailable,
      isPlaying: isPlaying,
      child: Opacity(
        opacity: unavailable ? 0.55 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                AspectRatio(
                  aspectRatio: ratio,
                  child: TrackCover(
                    track: track,
                    size: double.infinity,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
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
