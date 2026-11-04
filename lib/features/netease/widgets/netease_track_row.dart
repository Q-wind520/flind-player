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
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/shared/cover_image.dart';

/// A NetEase track row with an optional account-like action.
class NeteaseTrackRow extends StatelessWidget {
  const NeteaseTrackRow({
    super.key,
    required this.track,
    required this.isCurrent,
    required this.isPlaying,
    required this.isLiked,
    required this.onTap,
    this.onLike,
  });

  final Track track;
  final bool isCurrent;
  final bool isPlaying;
  final bool isLiked;
  final VoidCallback onTap;
  final VoidCallback? onLike;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CoverImage(path: track.coverPath, url: track.coverUrl, size: 44),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: isCurrent ? TextStyle(color: theme.colorScheme.primary) : null,
      ),
      subtitle: Text(
        track.artist ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCurrent && isPlaying)
            Icon(AppIcons.graphicEq, color: theme.colorScheme.primary),
          if (onLike != null)
            IconButton(
              tooltip: '',
              onPressed: onLike,
              icon: Icon(
                isLiked ? AppIcons.favoriteActive : AppIcons.favoriteBorder,
                color: isLiked ? theme.colorScheme.error : null,
              ),
            ),
        ],
      ),
      onTap: onTap,
    );
  }
}
