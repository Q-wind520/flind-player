// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flind_player/app/theme/app_icons.dart';
import 'package:flind_player/app/theme/app_tokens.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/features/library/cover_aspect_ratio_provider.dart';
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

    final radius = BorderRadius.circular(AppRadius.md);
    return Material(
      type: MaterialType.transparency,
      borderRadius: radius,
      child: InkWell(
        onTap: unavailable ? null : onTap,
        borderRadius: radius,
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
                      borderRadius: radius,
                    ),
                  ),
                  if (isPlaying)
                    Positioned(
                      bottom: AppSpacing.sm,
                      left: AppSpacing.sm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Icon(
                          AppIcons.graphicEq,
                          size: 12,
                          color: scheme.onPrimary,
                        ),
                      ),
                    ),
                  Positioned(
                    top: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: ClipOval(
                      child: ColoredBox(
                        color: scheme.surface.withValues(alpha: 0.82),
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
                padding: const EdgeInsets.fromLTRB(2, AppSpacing.sm, 2, 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
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
                    const SizedBox(height: AppSpacing.xs),
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
