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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flind_player/core/models/playback_queue.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/data/providers/database_providers.dart';
import 'package:flind_player/data/providers/library_providers.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/shared/duration_format.dart';

/// The local music library: a reactive list of tracks with import and
/// tap-to-play.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracksAsync = ref.watch(libraryTracksProvider);
    final playback = ref.watch(playbackStateProvider).value;
    final currentUri = playback?.currentTrack?.uri;
    final isPlaying = playback?.isPlaying ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('音乐库'),
        actions: [
          IconButton(
            onPressed: () => _importFiles(context, ref),
            icon: const Icon(Icons.add),
            tooltip: '导入本地音乐',
          ),
        ],
      ),
      body: tracksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _LibraryError(error: error),
        data: (tracks) {
          if (tracks.isEmpty) {
            return _EmptyLibrary(onImport: () => _importFiles(context, ref));
          }
          return ListView.builder(
            itemCount: tracks.length,
            itemBuilder: (context, index) {
              final track = tracks[index];
              final isCurrent = currentUri != null && track.uri == currentUri;
              return _TrackTile(
                track: track,
                isCurrent: isCurrent,
                isPlaying: isCurrent && isPlaying,
                onTap: () => _play(ref, tracks, index),
              );
            },
          );
        },
      ),
    );
  }

  /// Picks local files, persists every readable track, and reports the result.
  Future<void> _importFiles(BuildContext context, WidgetRef ref) async {
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
  Future<void> _play(WidgetRef ref, List<Track> tracks, int index) {
    final queue = PlaybackQueue(
      tracks: tracks,
      currentIndex: index,
      originalOrder: List<int>.generate(tracks.length, (i) => i),
    );
    return ref.read(playbackControllerProvider).playQueue(queue, index: index);
  }
}

/// A single library row with cover, title, artist and duration.
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
      subtitle: Text(
        track.artist ?? '未知艺术家',
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
        ],
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
  const _EmptyLibrary({required this.onImport});

  final VoidCallback onImport;

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
              '点击下方按钮导入本地音乐文件',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.tonalIcon(
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

/// Shown when the library stream fails.
class _LibraryError extends StatelessWidget {
  const _LibraryError({required this.error});

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
            Text(
              '加载音乐库失败',
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
