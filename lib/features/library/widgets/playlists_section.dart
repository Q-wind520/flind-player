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
import 'package:flind_player/data/providers/playlist_providers.dart';
import 'package:flind_player/features/library/playlist_detail_screen.dart';
import 'package:flind_player/features/library/widgets/library_card_shell.dart';
import 'package:flind_player/features/library/widgets/playlist_card.dart';
import 'package:flind_player/l10n/app_localizations.dart';
import 'package:flind_player/shared/cover_image.dart';
import 'package:flind_player/shared/section_header.dart';

/// The 歌单 section of the library: source shortcuts followed by every
/// user-created playlist.
///
/// Favourites have their own library tab, so this section deliberately does
/// not repeat a favourites row.
class PlaylistsSection extends ConsumerWidget {
  const PlaylistsSection({
    super.key,
    required this.view,
    this.header,
  });

  /// The layout chosen for the playlists scope (showcase or list).
  final LibraryView view;

  /// Optional source-shortcut block rendered above the playlists.
  final Widget? header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // The shell floats the bottom chrome over the content, so a view with an
    // explicit padding must reserve its height itself.
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final compact = MediaQuery.sizeOf(context).width < 600;
    final horizontal = compact ? 16.0 : 28.0;
    final custom = ref.watch(customPlaylistsProvider);

    // The showcase grid needs a cover-sized card; with no custom playlists
    // fall back to the list branch so the empty-state notice stays visible.
    if (view == LibraryView.showcase && custom.isNotEmpty) {
      return CustomScrollView(
        slivers: [
          if (header != null)
            SliverToBoxAdapter(child: header),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              horizontal,
              AppSpacing.sm,
              horizontal,
              AppSpacing.md + bottomInset,
            ),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: libraryCardMaxWidth,
                    childAspectRatio: libraryCardAspectRatio(
                      constraints.crossAxisExtent,
                    ),
                    crossAxisSpacing: libraryCardSpacing,
                    mainAxisSpacing: libraryCardSpacing,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final playlist = custom[index];
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
                  }, childCount: custom.length),
                );
              },
            ),
          ),
        ],
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
        ?header,
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
  const _PlaylistCover({required this.cover, required this.size});

  final PlaylistCover? cover;
  final double size;

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
    child: Icon(
      AppIcons.queueMusic,
      size: size * 0.5,
      color: scheme.onSurfaceVariant,
    ),
  );
}

/// Shown when there are no user-created playlists.
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
