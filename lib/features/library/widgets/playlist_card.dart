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
import 'package:flind_player/data/providers/playlist_providers.dart';
import 'package:flind_player/features/library/widgets/library_card_shell.dart';
import 'package:flind_player/l10n/app_localizations.dart';
import 'package:flind_player/shared/cover_image.dart';

/// One playlist as a card (cover + name + song count).
class PlaylistCard extends ConsumerWidget {
  const PlaylistCard({
    super.key,
    required this.playlistId,
    required this.name,
    required this.onTap,
    this.fallbackIcon = AppIcons.queueMusic,
  });

  final int playlistId;
  final String name;
  final VoidCallback onTap;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final cover = ref.watch(playlistCoverProvider(playlistId)).value;
    final count = ref.watch(playlistTracksProvider(playlistId)).value?.length;
    final path = cover?.coverPath;
    final url = cover?.coverUrl;
    final hasCover =
        (path != null && path.isNotEmpty) || (url != null && url.isNotEmpty);

    final coverRadius = BorderRadius.circular(AppRadius.sm);
    final placeholder = LibraryCoverPlaceholder(
      icon: fallbackIcon,
      iconSize: 40,
    );
    return LibraryCardShell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              foregroundDecoration: BoxDecoration(
                borderRadius: coverRadius,
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
              child: ClipRRect(
                borderRadius: coverRadius,
                child: hasCover
                    ? CoverImage(
                        path: path,
                        url: url,
                        size: double.infinity,
                        errorBuilder: (context, error, stackTrace) =>
                            placeholder,
                      )
                    : placeholder,
              ),
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
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  count == null ? '' : l10n.playlistTrackCount(count),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
