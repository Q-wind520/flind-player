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
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flind_player/app/theme/app_icons.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/data/providers/persistence_providers.dart';
import 'package:flind_player/l10n/app_localizations.dart';

/// Heart toggle for one track, shared by the player screen and desktop bar.
///
/// The active favourite uses the theme's error role, so it reads the same in
/// the dark player, the light shell, and the desktop dock. The caller chooses
/// whether the toggle shows the short confirmation snack bar.
class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({
    super.key,
    required this.track,
    this.size = 44,
    this.iconSize = 26,
    this.showFeedback = true,
  });

  final Track track;

  /// The diameter of the round tap target.
  final double size;

  /// The icon glyph size inside the tap target.
  final double iconSize;

  /// Whether to show the "已收藏/已取消收藏" snack bar after the toggle.
  final bool showFeedback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavourite = ref.watch(isFavoriteProvider(track.uri)).value ?? false;
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return IconButton(
      tooltip: isFavourite ? l10n.unfavorite : l10n.favorite,
      onPressed: () async {
        final repo = ref.read(favoritesRepositoryProvider);
        final isNowFavourite = await repo.toggleFavorite(track);
        if (showFeedback && context.mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  isNowFavourite ? l10n.favorited : l10n.unfavorited,
                ),
                duration: const Duration(seconds: 1),
              ),
            );
        }
      },
      icon: Icon(
        isFavourite ? AppIcons.favoriteActive : AppIcons.favoriteBorder,
      ),
      iconSize: iconSize,
      color: isFavourite ? scheme.error : scheme.onSurfaceVariant,
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(width: size, height: size),
    );
  }
}
