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
import 'dart:math' as math;

// Flutter 3.47 exports its own `RepeatMode` (for `RepeatingAnimationBuilder`),
// which collides with the playback model of the same name.
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flind_player/app/theme/app_theme.dart';
import 'package:flind_player/core/models/playback_state.dart';
import 'package:flind_player/core/models/repeat_mode.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/shared/duration_format.dart';

/// The "now playing" screen: artwork, progress and transport controls.
class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('正在播放')),
      body: const _NowPlayingView(),
    );
  }
}

/// Reacts to [playbackStateProvider] and renders either the empty state or the
/// current track's controls.
class _NowPlayingView extends ConsumerWidget {
  const _NowPlayingView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playbackStateProvider).value;
    final track = state?.currentTrack;
    if (state == null || track == null) {
      return const _NothingPlaying();
    }

    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < AppBreakpoints.compact;
        final coverSize = math
            .min(constraints.maxWidth * 0.7, constraints.maxHeight * 0.45)
            .clamp(140.0, 320.0);

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 24 : 48,
            vertical: 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PlayerCover(track: track, size: coverSize),
                  const SizedBox(height: 24),
                  Text(
                    track.title,
                    style: theme.textTheme.headlineSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    track.artist ?? '未知艺术家',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  _ProgressBar(state: state),
                  const SizedBox(height: 8),
                  _TransportControls(state: state),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Large rounded cover art with a tonal music-note placeholder.
class _PlayerCover extends StatelessWidget {
  const _PlayerCover({required this.track, required this.size});

  final Track track;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final coverPath = track.coverPath;
    final hasCover = coverPath != null && coverPath.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
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
      Icon(Icons.music_note, size: size * 0.4, color: scheme.onSurfaceVariant);
}

/// Seekable progress bar with `m:ss` labels on both sides.
class _ProgressBar extends ConsumerWidget {
  const _ProgressBar({required this.state});

  final PlaybackState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final durationMs = state.duration?.inMilliseconds ?? 0;
    final enabled = durationMs > 0;
    final maxValue = enabled ? durationMs.toDouble() : 1.0;
    final positionValue = enabled
        ? state.position.inMilliseconds.clamp(0, durationMs).toDouble()
        : 0.0;

    return Column(
      children: [
        Slider(
          value: positionValue,
          max: maxValue,
          onChanged: enabled ? (_) {} : null,
          onChangeEnd: enabled
              ? (value) => ref
                    .read(playbackControllerProvider)
                    .seek(Duration(milliseconds: value.round()))
              : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Text(
                formatTrackDuration(state.position),
                style: theme.textTheme.labelMedium,
              ),
              const Spacer(),
              Text(
                formatTrackDuration(state.duration),
                style: theme.textTheme.labelMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shuffle / previous / play-pause / next / repeat controls.
class _TransportControls extends ConsumerWidget {
  const _TransportControls({required this.state});

  final PlaybackState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final controller = ref.read(playbackControllerProvider);
    final repeatMode = state.repeatMode;
    final repeatActive = repeatMode != RepeatMode.off;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            onPressed: () => controller.setShuffle(!state.shuffleEnabled),
            icon: const Icon(Icons.shuffle),
            color: state.shuffleEnabled ? scheme.primary : null,
            tooltip: state.shuffleEnabled ? '随机播放：开' : '随机播放：关',
          ),
          IconButton(
            onPressed: state.hasPrevious ? controller.previous : null,
            icon: const Icon(Icons.skip_previous),
            iconSize: 36,
            tooltip: '上一首',
          ),
          IconButton.filled(
            onPressed: controller.togglePlayPause,
            icon: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow),
            iconSize: 36,
            tooltip: state.isPlaying ? '暂停' : '播放',
          ),
          IconButton(
            onPressed: state.hasNext ? controller.next : null,
            icon: const Icon(Icons.skip_next),
            iconSize: 36,
            tooltip: '下一首',
          ),
          IconButton(
            onPressed: () =>
                controller.setRepeatMode(_nextRepeatMode(repeatMode)),
            icon: Icon(
              repeatMode == RepeatMode.one ? Icons.repeat_one : Icons.repeat,
            ),
            color: repeatActive ? scheme.primary : null,
            tooltip: _repeatTooltip(repeatMode),
          ),
        ],
      ),
    );
  }
}

/// Cycles repeat mode off → all → one → off.
RepeatMode _nextRepeatMode(RepeatMode mode) => switch (mode) {
  RepeatMode.off => RepeatMode.all,
  RepeatMode.all => RepeatMode.one,
  RepeatMode.one => RepeatMode.off,
};

String _repeatTooltip(RepeatMode mode) => switch (mode) {
  RepeatMode.off => '顺序播放',
  RepeatMode.all => '列表循环',
  RepeatMode.one => '单曲循环',
};

/// Shown when nothing is loaded.
class _NothingPlaying extends StatelessWidget {
  const _NothingPlaying();

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
              Icons.play_circle_outline,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text('未在播放', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '在音乐库中选择一首歌开始播放',
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
