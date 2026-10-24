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
import 'package:flind_player/app/theme/app_theme.dart';
import 'package:flind_player/app/theme/app_tokens.dart';
import 'package:flind_player/core/models/library_view.dart';
import 'package:flind_player/core/models/playback_queue.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/repositories/playlist_repository.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/data/providers/playlist_providers.dart';
import 'package:flind_player/features/library/library_view_provider.dart';
import 'package:flind_player/features/library/widgets/library_view_menu_button.dart';
import 'package:flind_player/features/library/widgets/playlist_editor_dialog.dart';
import 'package:flind_player/features/library/widgets/track_view.dart';
import 'package:flind_player/l10n/app_localizations.dart';
import 'package:flind_player/shared/app_surface.dart';
import 'package:flind_player/shared/cover_image.dart';
import 'package:flind_player/shared/empty_state.dart';
import 'package:flind_player/shared/error_snack_bar.dart';

/// Detail view of one playlist: header (cover, name, description, count,
/// edit/delete) plus the member list.
class PlaylistDetailScreen extends ConsumerWidget {
  const PlaylistDetailScreen({super.key, required this.playlistId});

  final int playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final playlistsAsync = ref.watch(playlistsProvider);
    final tracksAsync = ref.watch(playlistTracksProvider(playlistId));
    final coverAsync = ref.watch(playlistCoverProvider(playlistId));

    final playlist = _findPlaylist(playlistsAsync.value, playlistId);
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;

    if (playlist == null) {
      return Scaffold(
        backgroundColor: AppSurface.colorOf(context),
        body: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                children: [
                  _PlaylistTopBar(compact: compact, actions: const []),
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final canManage = playlist.kind != PlaylistKind.favorites;
    final horizontal = compact ? 16.0 : 28.0;

    return Scaffold(
      backgroundColor: AppSurface.colorOf(context),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Column(
              children: [
                // The back button and playlist actions live inside the content
                // column so they line up with the header on wide windows
                // instead of hugging the window edge under a bare AppBar.
                _PlaylistTopBar(
                  compact: compact,
                  actions: [
                    if (canManage) ...[
                      IconButton(
                        tooltip: l10n.editPlaylist,
                        icon: const Icon(AppIcons.editOutlined),
                        onPressed: () => _edit(context, ref, playlist),
                      ),
                      IconButton(
                        tooltip: l10n.deletePlaylistTitle,
                        icon: const Icon(AppIcons.delete),
                        onPressed: () => _confirmDelete(context, ref, playlist),
                      ),
                    ],
                    const LibraryViewMenuButton(
                      scope: LibraryViewScope.playlistDetail,
                    ),
                  ],
                ),
                Expanded(
                  child: tracksAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stackTrace) => Center(
                      child: TextButton.icon(
                        onPressed: () =>
                            ref.invalidate(playlistTracksProvider(playlistId)),
                        icon: const Icon(AppIcons.refresh),
                        label: Text(l10n.retry),
                      ),
                    ),
                    data: (tracks) => Column(
                      children: [
                        _PlaylistHeader(
                          playlist: playlist,
                          cover: coverAsync.value,
                          count: tracks.length,
                          compact: compact,
                          onEditCover: canManage
                              ? () => _edit(context, ref, playlist)
                              : null,
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: horizontal),
                          child: Divider(
                            height: 1,
                            color: Theme.of(context).colorScheme.outlineVariant
                                .withValues(alpha: 0.55),
                          ),
                        ),
                        Expanded(
                          child: tracks.isEmpty
                              ? const _EmptyPlaylist()
                              : _memberList(ref, tracks),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Returns the playlist with [playlistId], or `null` while loading.
  Playlist? _findPlaylist(List<Playlist>? playlists, int playlistId) {
    if (playlists == null) return null;
    for (final candidate in playlists) {
      if (candidate.id == playlistId) {
        return candidate;
      }
    }
    return null;
  }

  /// Plays [tracks] starting at [index] using an identity queue.
  void _play(WidgetRef ref, List<Track> tracks, int index) {
    final queue = PlaybackQueue(
      tracks: tracks,
      currentIndex: index,
      originalOrder: List<int>.generate(tracks.length, (i) => i),
    );
    ref.read(playbackControllerProvider).playQueue(queue, index: index);
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    Playlist playlist,
  ) async {
    await showPlaylistEditorDialog(context, playlist: playlist);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Playlist playlist,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deletePlaylistTitle),
        content: Text(l10n.deletePlaylistBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(playlistRepositoryProvider).deletePlaylist(playlist.id);
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (context.mounted) {
        showErrorSnackBar(context, error);
      }
    }
  }

  Widget _memberList(WidgetRef ref, List<Track> tracks) {
    final view =
        (ref.watch(libraryViewsProvider).value ?? LibraryViews.defaults).viewOf(
          LibraryViewScope.playlistDetail,
        );
    return TrackView(
      tracks: tracks,
      view: view,
      currentUri: null,
      isPlaying: false,
      onPlay: (index) => _play(ref, tracks, index),
      playlistId: playlistId,
      showDeleteTrack: true,
    );
  }
}

/// The route chrome above the playlist header: back on the left, playlist
/// actions on the right, both aligned with the same content width.
class _PlaylistTopBar extends StatelessWidget {
  const _PlaylistTopBar({required this.compact, required this.actions});

  final bool compact;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final horizontal = compact ? 8.0 : 20.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontal, AppSpacing.xs, horizontal, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: const Icon(AppIcons.arrowBack),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const Spacer(),
          for (final action in actions) action,
        ],
      ),
    );
  }
}

/// The playlist header: tappable cover, name, description and member count.
class _PlaylistHeader extends StatelessWidget {
  const _PlaylistHeader({
    required this.playlist,
    required this.cover,
    required this.count,
    required this.compact,
    required this.onEditCover,
  });

  final Playlist playlist;
  final PlaylistCover? cover;
  final int count;
  final bool compact;
  final VoidCallback? onEditCover;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final path = cover?.coverPath;
    final url = cover?.coverUrl;
    final hasCover =
        (path != null && path.isNotEmpty) || (url != null && url.isNotEmpty);
    final coverSize = compact ? 104.0 : 128.0;
    final horizontal = compact ? 16.0 : 28.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontal,
        AppSpacing.md,
        horizontal,
        AppSpacing.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onEditCover,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: Container(
                    width: coverSize,
                    height: coverSize,
                    color: scheme.surfaceContainerHighest,
                    child: hasCover
                        ? CoverImage(
                            path: path,
                            url: url,
                            size: coverSize,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              AppIcons.queueMusic,
                              size: coverSize * 0.35,
                              color: scheme.onSurfaceVariant,
                            ),
                          )
                        : Icon(
                            AppIcons.queueMusic,
                            size: coverSize * 0.35,
                            color: scheme.onSurfaceVariant,
                          ),
                  ),
                ),
                if (onEditCover != null)
                  Positioned(
                    right: AppSpacing.sm,
                    bottom: AppSpacing.sm,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: scheme.surface.withValues(alpha: 0.86),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        AppIcons.edit,
                        size: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playlist.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall,
                ),
                if (playlist.description != null &&
                    playlist.description!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    playlist.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.playlistTrackCount(count),
                  style: theme.textTheme.labelMedium?.copyWith(
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

/// Shown when the playlist has no members yet.
class _EmptyPlaylist extends StatelessWidget {
  const _EmptyPlaylist();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      icon: AppIcons.queueMusic,
      title: l10n.emptyPlaylist,
      message: l10n.emptyPlaylistHint,
    );
  }
}
