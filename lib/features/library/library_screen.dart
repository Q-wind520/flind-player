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

import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flind_player/core/models/playback_queue.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/data/providers/database_providers.dart';
import 'package:flind_player/data/providers/library_providers.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/data/services/library_sync_service.dart';
import 'package:flind_player/features/library/widgets/cache_action_button.dart';
import 'package:flind_player/shared/duration_format.dart';

/// Actions exposed by the library overflow menu.
enum _LibraryAction { addFolder, rescan, importFiles }

/// The music library: a searchable, mixed local + online track browser with
/// folder scanning, import and tap-to-play.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';

  /// Local FTS is fast, but debouncing keeps the family provider from churning
  /// on every keystroke.
  static const Duration _debounceDelay = Duration(milliseconds: 250);

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () {
      if (!mounted) return;
      final trimmed = value.trim();
      if (trimmed == _query) return;
      setState(() => _query = trimmed);
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    if (_query.isNotEmpty) {
      setState(() => _query = '');
    }
  }

  Future<void> _onAction(_LibraryAction action) async {
    switch (action) {
      case _LibraryAction.addFolder:
        await _addFolder();
      case _LibraryAction.rescan:
        _startSync();
      case _LibraryAction.importFiles:
        await _importFiles();
    }
  }

  /// Picks a directory, persists it as a scan root and starts a sync.
  Future<void> _addFolder() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final path = await FilePicker.getDirectoryPath(dialogTitle: '选择音乐文件夹');
      if (path == null) {
        return;
      }
      await ref.read(musicLibraryRepositoryProvider).addScanRoot(path);
      ref.invalidate(scanRootsProvider);
      _startSync();
      messenger.showSnackBar(SnackBar(content: Text('已添加文件夹：$path')));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('添加文件夹失败：$error')));
    }
  }

  /// Runs a full library sync. The service publishes progress through
  /// [librarySyncStateProvider] and is a no-op while already running.
  void _startSync() {
    unawaited(ref.read(librarySyncServiceProvider).sync());
  }

  /// Picks local files, persists every readable track, and reports the result.
  Future<void> _importFiles() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final importer = ref.read(localFileImporterProvider);
      final repository = ref.read(musicLibraryRepositoryProvider);

      final tracks = await importer.pickAndImport();
      if (tracks.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('未选择或未识别到可导入的音频文件')),
        );
        return;
      }

      for (final track in tracks) {
        await repository.upsertTrack(track);
      }
      messenger.showSnackBar(
        SnackBar(content: Text('已导入 ${tracks.length} 首歌曲')),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('导入失败：$error')));
    }
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

  @override
  Widget build(BuildContext context) {
    final syncState =
        ref.watch(librarySyncStateProvider).value ?? LibrarySyncState.idle;
    final isSyncing = switch (syncState.phase) {
      LibrarySyncPhase.scanning ||
      LibrarySyncPhase.saving ||
      LibrarySyncPhase.artwork => true,
      _ => false,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('音乐库'),
        actions: [
          PopupMenuButton<_LibraryAction>(
            tooltip: '更多操作',
            onSelected: _onAction,
            itemBuilder: (context) => <PopupMenuEntry<_LibraryAction>>[
              PopupMenuItem(
                value: _LibraryAction.addFolder,
                enabled: !isSyncing,
                child: const _MenuRow(
                  icon: Icons.create_new_folder_outlined,
                  label: '添加文件夹',
                ),
              ),
              PopupMenuItem(
                value: _LibraryAction.rescan,
                enabled: !isSyncing,
                child: const _MenuRow(icon: Icons.refresh, label: '重新扫描'),
              ),
              const PopupMenuItem(
                value: _LibraryAction.importFiles,
                child: _MenuRow(icon: Icons.add, label: '导入文件'),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _searchController,
              builder: (context, value, child) {
                return TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: '搜索曲库',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: value.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            tooltip: '清空',
                            onPressed: _clearSearch,
                          ),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                );
              },
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _SyncStatus(state: syncState),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final playback = ref.watch(playbackStateProvider).value;
    final currentUri = playback?.currentTrack?.uri;
    final isPlaying = playback?.isPlaying ?? false;

    if (_query.isNotEmpty) {
      final resultsAsync = ref.watch(librarySearchProvider(_query));
      return resultsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            _LibraryError(error: error, title: '搜索失败'),
        data: (tracks) {
          if (tracks.isEmpty) {
            return const _NoSearchResults();
          }
          return _trackList(tracks, currentUri, isPlaying);
        },
      );
    }

    final tracksAsync = ref.watch(libraryTracksProvider);
    return tracksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => _LibraryError(error: error),
      data: (tracks) {
        if (tracks.isEmpty) {
          return _EmptyLibrary(onImport: _importFiles, onAddFolder: _addFolder);
        }
        return _trackList(tracks, currentUri, isPlaying);
      },
    );
  }

  Widget _trackList(List<Track> tracks, String? currentUri, bool isPlaying) {
    return ListView.builder(
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        final isCurrent = currentUri != null && track.uri == currentUri;
        return _TrackTile(
          track: track,
          isCurrent: isCurrent,
          isPlaying: isCurrent && isPlaying,
          onTap: () => _play(tracks, index),
        );
      },
    );
  }
}

/// A menu entry: leading icon plus label.
class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(children: [Icon(icon), const SizedBox(width: 12), Text(label)]);
  }
}

/// Inline progress / result banner for the active or last library sync.
class _SyncStatus extends StatelessWidget {
  const _SyncStatus({required this.state});

  final LibrarySyncState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (state.phase) {
      LibrarySyncPhase.idle => const SizedBox.shrink(),
      LibrarySyncPhase.scanning => _SyncBanner(
        text: '扫描中 ${state.processed}/${state.discovered}',
        color: scheme.primary,
        showProgress: true,
        progress: state.discovered > 0
            ? state.processed / state.discovered
            : null,
      ),
      LibrarySyncPhase.saving => _SyncBanner(
        text: '保存中…',
        color: scheme.primary,
        showProgress: true,
      ),
      LibrarySyncPhase.artwork => _SyncBanner(
        text: '缓存封面 ${state.coversCached}/${state.saved}',
        color: scheme.primary,
        showProgress: true,
        progress: state.saved > 0 ? state.coversCached / state.saved : null,
      ),
      LibrarySyncPhase.done => _SyncBanner(
        text:
            '已同步 ${state.discovered} 首 · '
            '新增 ${state.saved} · 移除 ${state.markedMissing}',
        color: scheme.tertiary,
        icon: Icons.check_circle_outline,
      ),
      LibrarySyncPhase.failed => _SyncBanner(
        text: '同步失败：${state.error ?? '未知错误'}',
        color: scheme.error,
        icon: Icons.error_outline,
      ),
    };
  }
}

/// A tonal strip carrying a sync line and optional progress bar.
class _SyncBanner extends StatelessWidget {
  const _SyncBanner({
    required this.text,
    required this.color,
    this.icon,
    this.showProgress = false,
    this.progress,
  });

  final String text;
  final Color color;
  final IconData? icon;
  final bool showProgress;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    text,
                    style: theme.textTheme.bodyMedium?.copyWith(color: color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (showProgress) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progress, color: color),
            ],
          ],
        ),
      ),
    );
  }
}

/// A single library row with cover, title, artist, source badge and duration.
class _TrackTile extends StatelessWidget {
  const _TrackTile({
    required this.track,
    required this.isCurrent,
    required this.isPlaying,
    required this.onTap,
  });

  final Track track;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListTile(
      onTap: onTap,
      selected: isCurrent,
      leading: _TrackCover(track: track, size: 48),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              track.artist ?? '未知艺术家',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          _SourceBadge(source: track.source),
        ],
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
          CacheActionButton(track: track),
        ],
      ),
    );
  }
}

/// Small tonal chip naming the track's source.
class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = switch (source) {
      'local' => '本地',
      'bilibili' => 'B站',
      _ => source,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

/// Rounded cover art, falling back to a tonal music-note placeholder.
class _TrackCover extends StatelessWidget {
  const _TrackCover({required this.track, required this.size});

  final Track track;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final coverPath = track.coverPath;
    final hasCover = coverPath != null && coverPath.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.16),
      child: Container(
        width: size,
        height: size,
        color: scheme.surfaceContainerHighest,
        child: hasCover
            ? Image.file(
                File(coverPath),
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _placeholder(scheme),
              )
            : _placeholder(scheme),
      ),
    );
  }

  Widget _placeholder(ColorScheme scheme) =>
      Icon(Icons.music_note, size: size * 0.5, color: scheme.onSurfaceVariant);
}

/// Shown when the library has no tracks yet.
class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.onImport, required this.onAddFolder});

  final VoidCallback onImport;
  final VoidCallback onAddFolder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.library_music_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text('曲库还是空的', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '添加一个音乐文件夹开始扫描，或导入本地音乐文件',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.tonalIcon(
              onPressed: onAddFolder,
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const Text('添加文件夹'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.add),
              label: const Text('导入本地音乐'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when a library search returns no tracks.
class _NoSearchResults extends StatelessWidget {
  const _NoSearchResults();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text('没有找到匹配的歌曲', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '换个关键词试试',
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

/// Shown when the library stream (or a search) fails.
class _LibraryError extends StatelessWidget {
  const _LibraryError({required this.error, this.title = '加载音乐库失败'});

  final Object error;
  final String title;

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
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
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
