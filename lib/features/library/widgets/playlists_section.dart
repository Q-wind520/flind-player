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
import 'package:flind_player/app/theme/app_tokens.dart';
import 'package:flind_player/core/models/library_view.dart';
import 'package:flind_player/core/repositories/playlist_repository.dart';
import 'package:flind_player/data/database/playlist_defaults.dart';
import 'package:flind_player/data/providers/playlist_providers.dart';
import 'package:flind_player/features/library/playlist_detail_screen.dart';
import 'package:flind_player/features/library/widgets/playlist_card.dart';
import 'package:flind_player/l10n/app_localizations.dart';
import 'package:flind_player/shared/cover_image.dart';
import 'package:flind_player/shared/section_header.dart';

/// The 歌单 section of the library: a pinned favourites row followed by every
/// user-created playlist.
class PlaylistsSection extends ConsumerWidget {
  const PlaylistsSection({
    super.key,
    required this.view,
    required this.onOpenFavorites,
  });

  /// The layout chosen for the playlists scope (showcase or list).
  final LibraryView view;

  /// Called when the pinned favourites row is tapped.
  final VoidCallback onOpenFavorites;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // The shell floats the bottom chrome over the content, so a view with an
    // explicit padding must reserve its height itself.
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final compact = MediaQuery.sizeOf(context).width < 600;
    final horizontal = compact ? 16.0 : 28.0;
    final custom = ref.watch(customPlaylistsProvider);
    final favoritesCount = ref
        .watch(playlistTracksProvider(favoritesPlaylistId))
        .value
        ?.length;

    // The showcase grid needs a cover-sized card; with no custom playlists
    // fall back to the list branch so the empty-state notice stays visible.
    if (view == LibraryView.showcase && custom.isNotEmpty) {
      return GridView.builder(
        padding: EdgeInsets.fromLTRB(
          horizontal,
          AppSpacing.sm,
          horizontal,
          AppSpacing.md + bottomInset,
        ),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 260,
          childAspectRatio: 0.82,
          crossAxisSpacing: 24,
          mainAxisSpacing: 28,
        ),
        itemCount: custom.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return PlaylistCard(
              playlistId: favoritesPlaylistId,
              name: l10n.tabFavorites,
              fallbackIcon: AppIcons.favorite,
              onTap: onOpenFavorites,
            );
          }
          final playlist = custom[index - 1];
          return PlaylistCard(
            playlistId: playlist.id,
            name: playlist.name,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) =>
                    PlaylistDetailScreen(playlistId: playlist.id),
              ),
            ),
          );
        },
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
        (horizontal - AppSpacing.lg).clamp(0.0, 16.0),
        4,
        (horizontal - AppSpacing.lg).clamp(0.0, 16.0),
        4 + bottomInset,
      ),
      children: [
        _FavoritesRow(trackCount: favoritesCount, onTap: onOpenFavorites),
        if (custom.isEmpty)
          const _EmptyPlaylists()
        else ...[
          SectionHeader(l10n.myPlaylists),
          for (final playlist in custom) _PlaylistRow(playlist: playlist),
        ],
      ],
    );
  }
}

/// The pinned favourites row: primary-toned, always first, never deletable.
class _FavoritesRow extends ConsumerWidget {
  const _FavoritesRow({required this.trackCount, required this.onTap});

  final int? trackCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cover = ref.watch(playlistCoverProvider(favoritesPlaylistId)).value;
    final count = trackCount;

    return ListTile(
      onTap: onTap,
      leading: _PlaylistCover(
        cover: cover,
        size: 48,
        fallbackIcon: AppIcons.favorite,
      ),
      title: Text(
        l10n.tabFavorites,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: count == null ? null : Text(l10n.playlistTrackCount(count)),
      trailing: const Icon(AppIcons.chevronRight),
    );
  }
}

/// One user-created playlist row; tapping pushes its detail screen.
class _PlaylistRow extends ConsumerWidget {
  const _PlaylistRow({required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cover = ref.watch(playlistCoverProvider(playlist.id)).value;
    final count = ref.watch(playlistTracksProvider(playlist.id)).value?.length;

    return ListTile(
      leading: _PlaylistCover(cover: cover, size: 48),
      title: Text(playlist.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: count == null ? null : Text(l10n.playlistTrackCount(count)),
      trailing: const Icon(AppIcons.chevronRight),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => PlaylistDetailScreen(playlistId: playlist.id),
          ),
        );
      },
    );
  }
}

/// Rounded playlist cover with a tonal fallback icon.
class _PlaylistCover extends StatelessWidget {
  const _PlaylistCover({
    required this.cover,
    required this.size,
    this.fallbackIcon = AppIcons.queueMusic,
  });

  final PlaylistCover? cover;
  final double size;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final path = cover?.coverPath;
    final url = cover?.coverUrl;
    final hasCover =
        (path != null && path.isNotEmpty) || (url != null && url.isNotEmpty);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        width: size,
        height: size,
        color: scheme.surfaceContainerHighest,
        child: hasCover
            ? CoverImage(
                path: path,
                url: url,
                size: size,
                errorBuilder: (context, error, stackTrace) =>
                    _placeholder(scheme),
              )
            : _placeholder(scheme),
      ),
    );
  }

  Widget _placeholder(ColorScheme scheme) => Center(
    child: Icon(fallbackIcon, size: size * 0.5, color: scheme.onSurfaceVariant),
  );
}

/// Shown when there are no user-created playlists (the favourites row stays).
class _EmptyPlaylists extends StatelessWidget {
  const _EmptyPlaylists();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            AppIcons.queueMusic,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(l10n.noPlaylists, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            l10n.noPlaylistsHint,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
