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
import 'package:flind_player/data/providers/persistence_providers.dart';
import 'package:flind_player/shared/cover_image.dart';
import 'package:flind_player/shared/duration_format.dart';
import 'package:flind_player/shared/responsive_center.dart';

/// The "now playing" screen: artwork, progress and transport controls.
///
/// Shown full-screen on every platform, wrapped in a [Scaffold] with an
/// [AppBar] whose leading button collapses back to the previous route.
class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('正在播放'),
      ),
      body: const PlayerView(),
    );
  }
}

/// The core now-playing content: artwork, progress and transport controls.
///
/// Embedded by [PlayerScreen] as the full-screen body without duplicating the
/// layout in the route that opens it.
class PlayerView extends ConsumerWidget {
  const PlayerView({super.key});

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
        final compact = AppBreakpoints.isCompact(constraints.biggest);
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
            ? CoverImage(
                path: coverPath,
                size: size,
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
///
/// The slider tracks the drag locally so the thumb follows the finger while
/// dragging; the seek is issued once on release.
class _ProgressBar extends ConsumerStatefulWidget {
  const _ProgressBar({required this.state});

  final PlaybackState state;

  @override
  ConsumerState<_ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends ConsumerState<_ProgressBar> {
  /// In-flight drag position in milliseconds, or `null` when not dragging.
  double? _dragMs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = widget.state;
    final durationMs = state.duration?.inMilliseconds ?? 0;
    final enabled = durationMs > 0;
    final maxValue = enabled ? durationMs.toDouble() : 1.0;
    final positionValue = enabled
        ? state.position.inMilliseconds.clamp(0, durationMs).toDouble()
        : 0.0;
    final dragMs = _dragMs;
    final shownPosition = dragMs == null
        ? state.position
        : Duration(milliseconds: dragMs.round());

    return Column(
      children: [
        Slider(
          value: dragMs ?? positionValue,
          max: maxValue,
          onChanged: enabled
              ? (value) => setState(() => _dragMs = value)
              : null,
          onChangeEnd: enabled
              ? (value) {
                  setState(() => _dragMs = null);
                  ref
                      .read(playbackControllerProvider)
                      .seek(Duration(milliseconds: value.round()));
                }
              : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Text(
                formatTrackDuration(shownPosition),
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

/// Favourite / previous / play-pause / next / play-mode controls.
class _TransportControls extends ConsumerWidget {
  const _TransportControls({required this.state});

  final PlaybackState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final controller = ref.read(playbackControllerProvider);
    final track = state.currentTrack;
    final mode = _PlayMode.fromState(state);

    // Five icon buttons never fit a 280 px-wide content column, so the row is
    // allowed to scale down as a whole instead of overflowing. Above its
    // intrinsic width the controls stay at full size.
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (track != null) _FavoriteButton(track: track),
            IconButton(
              onPressed: state.hasPrevious ? controller.previous : null,
              icon: const Icon(Icons.skip_previous),
              iconSize: 36,
            ),
            IconButton.filled(
              onPressed: controller.togglePlayPause,
              icon: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow),
              iconSize: 36,
            ),
            IconButton(
              onPressed: state.hasNext ? controller.next : null,
              icon: const Icon(Icons.skip_next),
              iconSize: 36,
            ),
            IconButton(
              onPressed: () {
                final next = mode.next;
                // Shuffle first so the queue is (un)shuffled before the
                // controller applies the new repeat mode.
                controller.setShuffle(next.shuffle);
                controller.setRepeatMode(next.repeat);
              },
              icon: Icon(mode.icon),
              color: mode.isActive ? scheme.primary : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Heart toggle for the current track in the player transport area.
///
/// Hidden when nothing is playing (no track).
class _FavoriteButton extends ConsumerWidget {
  const _FavoriteButton({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavourite =
        ref.watch(_playerFavoriteProvider(track.uri)).value ?? false;
    final scheme = Theme.of(context).colorScheme;

    return IconButton(
      onPressed: () async {
        final repo = ref.read(favoritesRepositoryProvider);
        final isNowFavourite = await repo.toggleFavorite(track);
        if (context.mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(isNowFavourite ? '已收藏' : '已取消收藏'),
                duration: const Duration(seconds: 1),
              ),
            );
        }
      },
      icon: Icon(isFavourite ? Icons.favorite : Icons.favorite_border),
      color: isFavourite ? scheme.primary : null,
    );
  }
}

/// Whether the track is favourited. Retries are disabled so errors surface
/// immediately.
final _playerFavoriteProvider = FutureProvider.family<bool, String>((ref, uri) {
  ref.watch(favoritesProvider);
  return ref.watch(favoritesRepositoryProvider).isFavorite(uri);
}, retry: (_, _) => null);

/// The playback modes cycled by the transport's single mode button.
///
/// Each mode maps to one `(repeatMode, shuffle)` pair on the controller.
enum _PlayMode {
  /// Plays through the queue once, in order.
  sequential(icon: Icons.playlist_play, repeat: RepeatMode.off, shuffle: false),

  /// Loops the whole queue.
  repeatAll(icon: Icons.repeat, repeat: RepeatMode.all, shuffle: false),

  /// Repeats the current track.
  repeatOne(icon: Icons.repeat_one, repeat: RepeatMode.one, shuffle: false),

  /// Shuffles the queue without repeating.
  shufflePlay(icon: Icons.shuffle, repeat: RepeatMode.off, shuffle: true);

  const _PlayMode({
    required this.icon,
    required this.repeat,
    required this.shuffle,
  });

  /// Icon shown on the button.
  final IconData icon;

  /// Repeat mode the controller is put into for this mode.
  final RepeatMode repeat;

  /// Whether the queue is shuffled in this mode.
  final bool shuffle;

  /// Whether this mode differs from plain sequential playback.
  bool get isActive => this != _PlayMode.sequential;

  /// The mode reached by the next tap, wrapping 随机 → 顺序.
  _PlayMode get next => switch (this) {
    _PlayMode.sequential => _PlayMode.repeatAll,
    _PlayMode.repeatAll => _PlayMode.repeatOne,
    _PlayMode.repeatOne => _PlayMode.shufflePlay,
    _PlayMode.shufflePlay => _PlayMode.sequential,
  };

  /// Derives the mode from [state]; shuffle takes precedence over repeat.
  static _PlayMode fromState(PlaybackState state) {
    if (state.shuffleEnabled) {
      return _PlayMode.shufflePlay;
    }
    return switch (state.repeatMode) {
      RepeatMode.off => _PlayMode.sequential,
      RepeatMode.all => _PlayMode.repeatAll,
      RepeatMode.one => _PlayMode.repeatOne,
    };
  }
}

/// Shown when nothing is loaded.
class _NothingPlaying extends StatelessWidget {
  const _NothingPlaying();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ResponsiveCenter(
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
