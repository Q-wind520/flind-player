// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flind_player/data/providers/playlist_providers.dart';
import 'package:flind_player/l10n/app_localizations.dart';
import 'package:flind_player/shared/cover_image.dart';

/// One playlist as a card (cover + name + song count).
class PlaylistCard extends ConsumerWidget {
  const PlaylistCard({
    super.key,
    required this.playlistId,
    required this.name,
    required this.onTap,
    this.fallbackIcon = Icons.queue_music,
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

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                color: scheme.surfaceContainerHighest,
                child: hasCover
                    ? CoverImage(
                        path: path,
                        url: url,
                        size: double.infinity,
                        errorBuilder: (context, error, stackTrace) =>
                            Icon(fallbackIcon, size: 40),
                      )
                    : Icon(fallbackIcon, size: 40),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
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
      ),
    );
  }
}
