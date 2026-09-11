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
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flind_player/core/models/playback_queue.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/remote_playlist.dart';
import 'package:flind_player/data/providers/bilibili_providers.dart';
import 'package:flind_player/data/providers/database_providers.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/shared/duration_format.dart';
import 'package:flind_player/shared/error_messages.dart';
import 'package:flind_player/shared/error_snack_bar.dart';

/// Browses a Bilibili user's **public** favourite folders by UID.
///
/// Anonymous by design: there is no login, no QR code and no secure storage —
/// only folders the user has explicitly published are reachable. The last-used
/// UID is kept in memory for the lifetime of this screen (it is intentionally
/// not persisted; persisting it is deferred until personal favourites land).
class BilibiliFavoritesScreen extends ConsumerStatefulWidget {
  const BilibiliFavoritesScreen({super.key});

  @override
  ConsumerState<BilibiliFavoritesScreen> createState() =>
      _BilibiliFavoritesScreenState();
}

class _BilibiliFavoritesScreenState
    extends ConsumerState<BilibiliFavoritesScreen> {
  final TextEditingController _uidController = TextEditingController();

  /// Last submitted UID — in memory only (see the class doc).
  String _uid = '';

  /// Non-null once a folder is opened; switches to the track view.
  RemotePlaylist? _openFolder;

  /// True while the first page (folders or tracks) is loading.
  bool _loading = false;

  /// True while a follow-up track page is being appended.
  bool _loadingMore = false;

  /// Non-null when the first page failed; rendered as a full-screen panel.
  Object? _error;

  /// Non-null when appending the next track page failed; rendered in the footer.
  Object? _loadMoreError;

  List<RemotePlaylist> _folders = const <RemotePlaylist>[];
  List<Track> _tracks = const <Track>[];

  /// Highest page loaded for the open folder, `0` before the first page lands.
  int _page = 0;

  /// Whether the source reports another page after [_page].
  bool _hasMore = false;

  /// Guards against a stale response overwriting a newer one.
  int _requestId = 0;

  @override
  void dispose() {
    _uidController.dispose();
    super.dispose();
  }

  Future<void> _loadFolders() async {
    final uid = _uidController.text.trim();
    if (uid.isEmpty) {
      return;
    }
    FocusScope.of(context).unfocus();
    final request = ++_requestId;
    setState(() {
      _uid = uid;
      _openFolder = null;
      _loading = true;
      _error = null;
      _loadingMore = false;
      _loadMoreError = null;
      _folders = const <RemotePlaylist>[];
      _tracks = const <Track>[];
      _page = 0;
      _hasMore = false;
    });

    try {
      final folders = await ref
          .read(remotePlaylistSourceProvider)
          .playlistsForUser(uid);
      if (!mounted || request != _requestId) return;
      setState(() {
        _loading = false;
        _folders = folders;
      });
    } catch (error) {
      if (!mounted || request != _requestId) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  Future<void> _openFolderTracks(RemotePlaylist folder) async {
    final request = ++_requestId;
    setState(() {
      _openFolder = folder;
      _loading = true;
      _error = null;
      _loadingMore = false;
      _loadMoreError = null;
      _tracks = const <Track>[];
      _page = 0;
      _hasMore = false;
    });

    try {
      final result = await ref
          .read(remotePlaylistSourceProvider)
          .playlistTracks(folder.id, page: 1);
      if (!mounted || request != _requestId) return;
      setState(() {
        _loading = false;
        _tracks = result.tracks;
        _page = result.page;
        _hasMore = result.hasMore;
      });
    } catch (error) {
      if (!mounted || request != _requestId) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  /// Appends the page after [_page], ignoring taps while a request is in flight.
  ///
  /// On failure [_page] stays put, so retrying via the footer re-requests the
  /// same page. No two page requests run concurrently.
  Future<void> _loadMore() async {
    final folder = _openFolder;
    if (folder == null || _loading || _loadingMore || !_hasMore) return;

    final request = _requestId;
    final nextPage = _page + 1;
    setState(() {
      _loadingMore = true;
      _loadMoreError = null;
    });

    try {
      final result = await ref
          .read(remotePlaylistSourceProvider)
          .playlistTracks(folder.id, page: nextPage);
      if (!mounted || request != _requestId) return;
      setState(() {
        _loadingMore = false;
        _tracks = <Track>[..._tracks, ...result.tracks];
        _page = result.page;
        _hasMore = result.hasMore;
      });
    } catch (error) {
      if (!mounted || request != _requestId) return;
      setState(() {
        _loadingMore = false;
        _loadMoreError = error;
      });
    }
  }

  void _backToFolders() {
    _requestId++;
    setState(() {
      _openFolder = null;
      _tracks = const <Track>[];
      _error = null;
      _loadingMore = false;
      _loadMoreError = null;
      _page = 0;
      _hasMore = false;
    });
  }

  /// Plays [tracks] starting at [index] using an identity queue.
  Future<void> _play(List<Track> tracks, int index) {
    final queue = PlaybackQueue(
      tracks: tracks,
      currentIndex: index,
      originalOrder: List<int>.generate(tracks.length, (i) => i),
    );
    return ref.read(playbackControllerProvider).playQueue(queue, index: index);
  }

  Future<void> _saveToLibrary(Track track) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(musicLibraryRepositoryProvider).upsertTrack(track);
      messenger.showSnackBar(SnackBar(content: Text('已存入曲库：${track.title}')));
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, error);
    }
  }

  /// Re-runs the request that produced the current error panel.
  void _retry() {
    final folder = _openFolder;
    if (folder != null) {
      _openFolderTracks(folder);
    } else {
      _loadFolders();
    }
  }

  @override
  Widget build(BuildContext context) {
    final folder = _openFolder;
    return Scaffold(
      appBar: AppBar(
        leading: folder == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: '返回收藏夹',
                onPressed: _backToFolders,
              ),
        title: Text(
          folder == null ? '浏览 B 站收藏夹' : folder.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        bottom: folder == null
            ? PreferredSize(
                preferredSize: const Size.fromHeight(72),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _uidController,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.search,
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onSubmitted: (_) => _loadFolders(),
                          decoration: const InputDecoration(
                            hintText: 'UP 主 UID',
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _loading ? null : _loadFolders,
                        child: const Text('加载'),
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _FavoritesError(error: _error!, onRetry: _retry);
    }
    if (_openFolder == null) {
      return _buildFolderList();
    }
    return _buildTrackList();
  }

  Widget _buildFolderList() {
    if (_uid.isEmpty) {
      return const _FavoritesHint(
        icon: Icons.cloud_outlined,
        title: '浏览公开收藏夹',
        message: '输入 Bilibili 用户的 UID，查看其公开的收藏夹',
      );
    }
    if (_folders.isEmpty) {
      return const _FavoritesHint(
        icon: Icons.folder_off_outlined,
        title: '没有公开的收藏夹',
        message: '该用户没有公开的收藏夹，或 UID 不存在',
      );
    }
    return ListView.builder(
      itemCount: _folders.length,
      itemBuilder: (context, index) {
        final folder = _folders[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
            child: const Icon(Icons.folder_outlined),
          ),
          title: Text(
            folder.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${folder.trackCount} 个内容',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openFolderTracks(folder),
        );
      },
    );
  }

  Widget _buildTrackList() {
    final playback = ref.watch(playbackStateProvider).value;
    final currentUri = playback?.currentTrack?.uri;
    final isPlaying = playback?.isPlaying ?? false;

    if (_tracks.isEmpty) {
      return const _FavoritesHint(
        icon: Icons.music_off_outlined,
        title: '没有可播放的视频',
        message: '这个收藏夹里没有可播放的视频（音频与合集暂不支持）',
      );
    }
    return ListView.builder(
      // One extra row for the pagination footer.
      itemCount: _tracks.length + 1,
      itemBuilder: (context, index) {
        if (index == _tracks.length) {
          return _TrackListFooter(
            loading: _loadingMore,
            error: _loadMoreError,
            hasMore: _hasMore,
            showExhausted: _page > 1,
            onLoadMore: _loadMore,
            onRetry: _loadMore,
          );
        }
        final track = _tracks[index];
        final isCurrent = currentUri != null && track.uri == currentUri;
        return _FavoriteTrackTile(
          track: track,
          isCurrent: isCurrent,
          isPlaying: isCurrent && isPlaying,
          onTap: () => _play(_tracks, index),
          onSave: () => _saveToLibrary(track),
        );
      },
    );
  }
}

/// Footer row under the loaded favourite tracks.
///
/// Shows a spinner while appending, a retry when the append failed, a
/// 加载更多 button while the source reports another page, and 已全部加载 once
/// more than one page has been loaded. Hidden for a single-page folder.
class _TrackListFooter extends StatelessWidget {
  const _TrackListFooter({
    required this.loading,
    required this.error,
    required this.hasMore,
    required this.showExhausted,
    required this.onLoadMore,
    required this.onRetry,
  });

  final bool loading;
  final Object? error;
  final bool hasMore;
  final bool showExhausted;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        child: Column(
          children: [
            Text(
              describeError(error!),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: OutlinedButton(
            onPressed: onLoadMore,
            child: const Text('加载更多'),
          ),
        ),
      );
    }
    if (showExhausted) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            '已全部加载',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

/// A favourite track row: placeholder cover, title, UP 主, duration and a
/// trailing 存入曲库 action.
class _FavoriteTrackTile extends StatelessWidget {
  const _FavoriteTrackTile({
    required this.track,
    required this.isCurrent,
    required this.isPlaying,
    required this.onTap,
    required this.onSave,
  });

  final Track track;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListTile(
      onTap: onTap,
      selected: isCurrent,
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.music_note, color: scheme.onSurfaceVariant),
      ),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        track.artist ?? '未知UP主',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPlaying) ...[
            Icon(Icons.graphic_eq, size: 20, color: scheme.primary),
            const SizedBox(width: 8),
          ],
          Text(
            formatTrackDuration(track.duration),
            style: theme.textTheme.labelMedium,
          ),
          IconButton(
            icon: const Icon(Icons.library_add_outlined),
            tooltip: '存入曲库',
            onPressed: onSave,
          ),
        ],
      ),
    );
  }
}

/// Shared empty / hint panel.
class _FavoritesHint extends StatelessWidget {
  const _FavoritesHint({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              message,
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

/// Shown when a folder or track load fails.
class _FavoritesError extends StatelessWidget {
  const _FavoritesError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text('加载失败', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              describeError(error),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
