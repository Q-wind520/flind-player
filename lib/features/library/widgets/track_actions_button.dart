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

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/data/providers/cache_providers.dart';
import 'package:flind_player/data/providers/deletion_providers.dart';
import 'package:flind_player/data/providers/library_providers.dart';
import 'package:flind_player/data/providers/offline_cache_providers.dart';
import 'package:flind_player/data/providers/persistence_providers.dart';
import 'package:flind_player/data/providers/playlist_providers.dart';
import 'package:flind_player/features/library/widgets/cache_action_button.dart';
import 'package:flind_player/features/library/widgets/playlist_picker_sheet.dart';
import 'package:flind_player/l10n/app_localizations.dart';
import 'package:flind_player/shared/error_snack_bar.dart';

/// Consolidated row actions for library and search track rows.
///
/// **Layout decision:** At 400 px, appending a standalone favourite IconButton
/// alongside the existing [CacheActionButton] and (for search rows) store
/// button overflows.  We therefore fold all per-row actions into a single
/// [PopupMenuButton], keeping the trailing area to exactly two widgets
/// (duration text + this button).  The playing indicator is a passive visual
/// element and does not count toward that limit.
///
/// Menu items:
/// - 收藏 / 取消收藏    (always)
/// - 离线缓存 / 已缓存  (online tracks only; 已缓存 is disabled)
/// - 存入曲库           (when [showSaveToLibrary] is true)
/// - 加入歌单           (always)
/// - 移出歌单           (when [playlistId] is non-null)
/// - 删除歌曲           (when [showDeleteTrack] is true)
enum _TrackAction {
  favorite,
  cache,
  saveToLibrary,
  addToPlaylist,
  removeFromPlaylist,
  deleteTrack,
}

class TrackActionsButton extends ConsumerWidget {
  const TrackActionsButton({
    super.key,
    required this.track,
    this.showSaveToLibrary = false,
    this.onSaveToLibrary,
    this.playlistId,
    this.showDeleteTrack = false,
  });

  final Track track;

  /// Whether to show the "存入曲库" menu item (search rows only).
  final bool showSaveToLibrary;

  /// Called when the user selects "存入曲库".
  final VoidCallback? onSaveToLibrary;

  /// The playlist this button is rendered inside, when non-null. Adds a
  /// "移出歌单" item to the menu.
  final int? playlistId;

  /// Whether to show the "删除歌曲" menu item (library rows).
  final bool showDeleteTrack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavourite =
        ref.watch(isFavoriteProvider(track.uri)).value ?? false;
    final cacheEntry = ref.watch(audioCacheEntryProvider(track)).value;
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    final isLocal = track.source == 'local';

    return PopupMenuButton<_TrackAction>(
      // Empty message suppresses PopupMenuButton's default "Show menu" bubble.
      tooltip: '',
      onSelected: (action) => _onSelected(context, ref, action),
      itemBuilder: (context) => [
        PopupMenuItem<_TrackAction>(
          value: _TrackAction.favorite,
          child: Row(
            children: [
              Icon(
                isFavourite ? Icons.favorite : Icons.favorite_border,
                color: isFavourite ? scheme.primary : null,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(isFavourite ? l10n.unfavorite : l10n.favorite),
            ],
          ),
        ),
        if (!isLocal)
          PopupMenuItem<_TrackAction>(
            value: _TrackAction.cache,
            enabled: cacheEntry == null,
            child: Row(
              children: [
                Icon(
                  cacheEntry == null
                      ? Icons.download_outlined
                      : Icons.download_done,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(cacheEntry == null ? l10n.cacheOffline : l10n.cached),
              ],
            ),
          ),
        if (showSaveToLibrary)
          PopupMenuItem<_TrackAction>(
            value: _TrackAction.saveToLibrary,
            child: Row(
              children: [
                Icon(Icons.library_add_outlined, size: 20),
                SizedBox(width: 12),
                Text(l10n.saveToLibrary),
              ],
            ),
          ),
        PopupMenuItem<_TrackAction>(
          value: _TrackAction.addToPlaylist,
          child: Row(
            children: [
              const Icon(Icons.playlist_add, size: 20),
              const SizedBox(width: 12),
              Text(l10n.addToPlaylist),
            ],
          ),
        ),
        if (playlistId != null)
          PopupMenuItem<_TrackAction>(
            value: _TrackAction.removeFromPlaylist,
            child: Row(
              children: [
                const Icon(Icons.playlist_remove, size: 20),
                const SizedBox(width: 12),
                Text(l10n.removeFromPlaylist),
              ],
            ),
          ),
        if (showDeleteTrack)
          PopupMenuItem<_TrackAction>(
            value: _TrackAction.deleteTrack,
            child: Row(
              children: [
                const Icon(Icons.delete_outline, size: 20),
                const SizedBox(width: 12),
                Text(l10n.deleteTrack),
              ],
            ),
          ),
      ],
    );
  }

  void _onSelected(BuildContext context, WidgetRef ref, _TrackAction action) {
    switch (action) {
      case _TrackAction.favorite:
        _toggleFavorite(context, ref);
      case _TrackAction.cache:
        _cacheTrack(ref);
      case _TrackAction.saveToLibrary:
        onSaveToLibrary?.call();
      case _TrackAction.addToPlaylist:
        _addToPlaylist(context);
      case _TrackAction.removeFromPlaylist:
        _removeFromPlaylist(context, ref);
      case _TrackAction.deleteTrack:
        _deleteTrack(context, ref);
    }
  }

  Future<void> _addToPlaylist(BuildContext context) async {
    await showPlaylistPickerSheet(context, track: track);
  }

  Future<void> _removeFromPlaylist(BuildContext context, WidgetRef ref) async {
    final id = playlistId;
    if (id == null) return;
    try {
      await ref.read(playlistRepositoryProvider).removeTrack(id, track.uri);
    } catch (error) {
      if (context.mounted) {
        showErrorSnackBar(context, error);
      }
    }
  }

  /// Confirms, then permanently deletes the track from playlists, the library
  /// and the offline cache (local files on disk are left alone).
  Future<void> _deleteTrack(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteTrackTitle),
        content: Text(l10n.deleteTrackBody(track.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(trackDeletionServiceProvider).deleteEverywhere(track);
      ref.invalidate(audioCacheEntryProvider(track));
      ref.invalidate(audioCacheUsageProvider);
      ref.invalidate(libraryTracksProvider);
      // A 全部 search result comes from `librarySearchProvider(_query)`, which
      // is cached per query; without this the deleted row would stay visible.
      ref.invalidate(librarySearchProvider);
      // The settings screen's offline list is keep-alive; refresh it too.
      ref.invalidate(offlineCacheEntriesProvider);
      ref.invalidate(favoritesProvider);
      ref.invalidate(playlistsProvider);
      final id = playlistId;
      if (id != null) ref.invalidate(playlistTracksProvider(id));
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(l10n.trackDeleted(track.title))),
          );
      }
    } catch (error) {
      if (context.mounted) showErrorSnackBar(context, error);
    }
  }

  Future<void> _toggleFavorite(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(favoritesRepositoryProvider);
    final isNowFavourite = await repo.toggleFavorite(track);
    if (context.mounted) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(isNowFavourite ? l10n.favorited : l10n.unfavorited),
            duration: const Duration(seconds: 1),
          ),
        );
    }
  }

  void _cacheTrack(WidgetRef ref) {
    ref.read(downloadManagerProvider).cacheTrack(track, pinned: true);
  }
}

