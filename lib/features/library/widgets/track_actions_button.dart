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
import 'package:flind_player/data/cache/audio_cache_store.dart';
import 'package:flind_player/data/providers/cache_providers.dart';
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
/// - 收藏 / 取消收藏  (always)
/// - 缓存到本地 / 已缓存 (online tracks only)
/// - 存入曲库          (when [showSaveToLibrary] is true)
/// - 加入歌单          (always)
/// - 移出歌单          (when [playlistId] is non-null)
enum _TrackAction { favorite, cache, saveToLibrary, addToPlaylist, removeFromPlaylist }

class TrackActionsButton extends ConsumerWidget {
  const TrackActionsButton({
    super.key,
    required this.track,
    this.showSaveToLibrary = false,
    this.onSaveToLibrary,
    this.playlistId,
  });

  final Track track;

  /// Whether to show the "存入曲库" menu item (search rows only).
  final bool showSaveToLibrary;

  /// Called when the user selects "存入曲库".
  final VoidCallback? onSaveToLibrary;

  /// The playlist this button is rendered inside, when non-null. Adds a
  /// "移出歌单" item to the menu.
  final int? playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavourite =
        ref.watch(_isFavouriteProvider(track.uri)).value ?? false;
    final cacheEntry = ref.watch(audioCacheEntryProvider(track)).value;
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    final isLocal = track.source == 'local';

    return PopupMenuButton<_TrackAction>(
      // Empty message suppresses PopupMenuButton's default "Show menu" bubble.
      tooltip: '',
      onSelected: (action) =>
          _onSelected(context, ref, action, cacheEntry: cacheEntry),
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
            child: Row(
              children: [
                Icon(_cacheIcon(cacheEntry), size: 20),
                const SizedBox(width: 12),
                Text(_cacheLabel(l10n, cacheEntry)),
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
      ],
    );
  }

  void _onSelected(
    BuildContext context,
    WidgetRef ref,
    _TrackAction action, {
    CachedAudio? cacheEntry,
  }) {
    switch (action) {
      case _TrackAction.favorite:
        _toggleFavorite(context, ref);
      case _TrackAction.cache:
        _cacheTrack(ref, cacheEntry);
      case _TrackAction.saveToLibrary:
        onSaveToLibrary?.call();
      case _TrackAction.addToPlaylist:
        _addToPlaylist(context);
      case _TrackAction.removeFromPlaylist:
        _removeFromPlaylist(context, ref);
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

  void _cacheTrack(WidgetRef ref, CachedAudio? cacheEntry) {
    final manager = ref.read(downloadManagerProvider);
    if (cacheEntry != null && cacheEntry.pinned) {
      // Already cached and pinned — unpin via removing the entry.
      // The existing CacheActionButton pattern removes the entry via the store.
      // We mirror that: removing unpin-then-re-cache would be a no-op for LRU,
      // so we just re-cache as pinned (the DownloadManager handles the skip).
      manager.cacheTrack(track, pinned: true);
    } else {
      manager.cacheTrack(track, pinned: true);
    }
  }

  static IconData _cacheIcon(CachedAudio? entry) {
    if (entry == null) return Icons.download_outlined;
    if (entry.pinned) return Icons.download_done;
    return Icons.offline_pin_outlined;
  }

  static String _cacheLabel(AppLocalizations l10n, CachedAudio? entry) {
    if (entry == null) return l10n.cacheToLocal;
    if (entry.pinned) return l10n.cached;
    return l10n.cachedUnpinned;
  }
}

/// Whether [uri] is currently favourited.  Automatic retries are disabled so
/// a transient DB error surfaces immediately instead of hiding the state.
final _isFavouriteProvider = FutureProvider.family<bool, String>((ref, uri) {
  ref.watch(favoritesProvider);
  return ref.watch(favoritesRepositoryProvider).isFavorite(uri);
}, retry: (_, _) => null);
