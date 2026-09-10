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
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/data/sources/bilibili/bili_client.dart';
import 'package:flind_player/features/search/search_providers.dart';
import 'package:flind_player/shared/duration_format.dart';

/// Bilibili search: submit a keyword, browse the results, tap one to play.
///
/// The query is only committed on submit (never per keystroke): the search
/// endpoint is hard rate-limited and would answer `-412` on a keystroke storm.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  String _submittedQuery = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _submittedQuery = trimmed);
  }

  void _clear() {
    _controller.clear();
    if (_submittedQuery.isNotEmpty) {
      setState(() => _submittedQuery = '');
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, child) {
                return TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _submit,
                  decoration: InputDecoration(
                    hintText: '搜索歌曲、UP主',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: value.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            tooltip: '清空',
                            onPressed: _clear,
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_submittedQuery.isEmpty) {
      return const _SearchHint();
    }

    final resultsAsync = ref.watch(biliSearchResultsProvider(_submittedQuery));
    final playback = ref.watch(playbackStateProvider).value;
    final currentUri = playback?.currentTrack?.uri;
    final isPlaying = playback?.isPlaying ?? false;

    return resultsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => _SearchError(error: error),
      data: (tracks) {
        if (tracks.isEmpty) {
          return const _NoResults();
        }
        return ListView.builder(
          itemCount: tracks.length,
          itemBuilder: (context, index) {
            final track = tracks[index];
            final isCurrent = currentUri != null && track.uri == currentUri;
            return _SearchResultTile(
              track: track,
              isCurrent: isCurrent,
              isPlaying: isCurrent && isPlaying,
              onTap: () => _play(tracks, index),
            );
          },
        );
      },
    );
  }
}

/// A single search result row with a placeholder cover, title, UP主 and
/// duration.
class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({
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
        ],
      ),
    );
  }
}

/// Shown before any query is submitted.
class _SearchHint extends StatelessWidget {
  const _SearchHint();

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
              Icons.search,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text('搜索 Bilibili 上的音乐', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '输入关键词后回车，即可搜索并播放 Bilibili 音频',
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

/// Shown when a completed search returned no tracks.
class _NoResults extends StatelessWidget {
  const _NoResults();

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
            Text('没有找到结果', style: theme.textTheme.titleMedium),
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

/// Shown when the search future fails.
class _SearchError extends StatelessWidget {
  const _SearchError({required this.error});

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
              '搜索失败',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage(error),
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
String _errorMessage(Object error) {
  if (error is BiliApiException) {
    if (error.code == -412 || error.code == -352) {
      return '请求过于频繁，请稍后再试';
    }
    return error.message;
  }
  return '$error';
}
