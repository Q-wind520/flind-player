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

import 'package:flind_player/core/models/playback_queue.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/repositories/playlist_repository.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/data/providers/playlist_providers.dart';
import 'package:flind_player/features/library/widgets/playlist_editor_dialog.dart';
import 'package:flind_player/features/library/widgets/track_list_items.dart';
import 'package:flind_player/app/theme/app_theme.dart';
import 'package:flind_player/l10n/app_localizations.dart';
import 'package:flind_player/shared/app_surface.dart';
import 'package:flind_player/shared/cover_image.dart';
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

    if (playlist == null) {
      return Scaffold(
        backgroundColor: AppSurface.colorOf(context),
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final canManage = playlist.kind != PlaylistKind.favorites;

    return Scaffold(
      backgroundColor: AppSurface.colorOf(context),
      appBar: AppBar(
        title: Text(
          playlist.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (canManage) ...[
            IconButton(
              tooltip: l10n.editPlaylist,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _edit(context, ref, playlist),
            ),
            IconButton(
              tooltip: l10n.deletePlaylistTitle,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context, ref, playlist),
            ),
          ],
        ],
      ),
      body: tracksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: TextButton.icon(
            onPressed: () => ref.invalidate(playlistTracksProvider(playlistId)),
            icon: const Icon(Icons.refresh),
            label: Text(l10n.retry),
          ),
        ),
        data: (tracks) => Column(
          children: [
            _PlaylistHeader(
              playlist: playlist,
              cover: coverAsync.value,
              count: tracks.length,
              onEditCover: canManage
                  ? () => _edit(context, ref, playlist)
                  : null,
            ),
            Expanded(
              child: tracks.isEmpty
                  ? const _EmptyPlaylist()
                  : _memberList(ref, tracks),
            ),
          ],
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
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!AppBreakpoints.isCompact(constraints.biggest)) {
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              childAspectRatio: 0.82,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: tracks.length,
            itemBuilder: (context, index) {
              final track = tracks[index];
              return TrackCard(
                track: track,
                isCurrent: false,
                isPlaying: false,
                unavailable: track.id == null,
                playlistId: playlistId,
                onTap: () => _play(ref, tracks, index),
              );
            },
          );
        }
        return ListView.builder(
          itemCount: tracks.length,
          itemBuilder: (context, index) {
            final track = tracks[index];
            return TrackTile(
              track: track,
              isCurrent: false,
              isPlaying: false,
              unavailable: track.id == null,
              playlistId: playlistId,
              onTap: () => _play(ref, tracks, index),
            );
          },
        );
      },
    );
  }
}

/// The playlist header: tappable cover, name, description and member count.
class _PlaylistHeader extends StatelessWidget {
  const _PlaylistHeader({
    required this.playlist,
    required this.cover,
    required this.count,
    required this.onEditCover,
  });

  final Playlist playlist;
  final PlaylistCover? cover;
  final int count;
  final VoidCallback? onEditCover;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final path = cover?.coverPath;
    final url = cover?.coverUrl;
    final hasCover =
        (path != null && path.isNotEmpty) || (url != null && url.isNotEmpty);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: onEditCover,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 96,
                height: 96,
                color: theme.colorScheme.surfaceContainerHighest,
                child: hasCover
                    ? CoverImage(
                        path: path,
                        url: url,
                        size: 96,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.queue_music, size: 40),
                      )
                    : const Icon(Icons.queue_music, size: 40),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playlist.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (playlist.description != null &&
                    playlist.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    playlist.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  l10n.playlistTrackCount(count),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.queue_music,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(l10n.emptyPlaylist, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              l10n.emptyPlaylistHint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}