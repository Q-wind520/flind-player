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
import 'package:flind_player/data/sources/bilibili/bili_client.dart';
import 'package:flind_player/shared/duration_format.dart';

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

  bool _loading = false;
  Object? _error;
  List<RemotePlaylist> _folders = const <RemotePlaylist>[];
  List<Track> _tracks = const <Track>[];

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
      _folders = const <RemotePlaylist>[];
      _tracks = const <Track>[];
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
      _tracks = const <Track>[];
    });

    try {
      final tracks = await ref
          .read(remotePlaylistSourceProvider)
          .playlistTracks(folder.id);
      if (!mounted || request != _requestId) return;
      setState(() {
        _loading = false;
        _tracks = tracks;
      });
    } catch (error) {
      if (!mounted || request != _requestId) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  void _backToFolders() {
    setState(() {
      _openFolder = null;
      _tracks = const <Track>[];
      _error = null;
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
      messenger.showSnackBar(SnackBar(content: Text('存入曲库失败：$error')));
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
      return _FavoritesError(error: _error!);
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
      itemCount: _tracks.length,
      itemBuilder: (context, index) {
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
  const _FavoritesError({required this.error});

  final Object error;

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
              _favoritesErrorMessage(error),
              style: theme.textTheme.bodySmall?.copyWith(
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

/// Turns a raw error into a readable message, special-casing the Bilibili
/// risk-control / IP-block codes.
String _favoritesErrorMessage(Object error) {
  if (error is BiliApiException) {
    if (error.code == -412 || error.code == -352) {
      return '请求过于频繁，请稍后再试';
    }
    if (error.code == -101) {
      return '该收藏夹需要登录后才能查看';
    }
    return error.message;
  }
  return '$error';
}
