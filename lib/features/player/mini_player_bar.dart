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

import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flind_player/app/theme/app_tokens.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/features/player/player_screen.dart';
import 'package:flind_player/shared/glass_surface.dart';
import 'package:flind_player/l10n/app_localizations.dart';
import 'package:flind_player/shared/cover_hero.dart';
import 'package:flind_player/shared/cover_image.dart';

/// The route that opens the full-screen player from the mini bar.
///
/// On platforms without a system back gesture the panel fades in over
/// [AppMotion.emphasized]; on Apple platforms the native [CupertinoPageRoute]
/// is kept (at the same duration) so the interactive edge-swipe-back still
/// works instead of being silently dropped.
Route<void> playerRoute(BuildContext context) {
  final duration = AppMotion.emphasized;
  final platform = Theme.of(context).platform;
  if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
    return CupertinoPageRoute<void>(
      builder: (_) => const PlayerScreen(),
    );
  }
  return PageRouteBuilder<void>(
    // Non-opaque so the dismiss drawer can dim the app behind it.
    opaque: false,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    pageBuilder: (context, animation, secondaryAnimation) =>
        const PlayerScreen(),
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: AppMotion.emphasizedCurve,
          ),
          child: child,
        ),
  );
}

/// A compact bar docked above the navigation that shows the currently playing
/// track and basic transport controls.
///
/// When nothing is playing, renders [SizedBox.shrink]. Tapping the bar opens
/// the full-screen [PlayerScreen] on every platform.
class MiniPlayerBar extends ConsumerWidget {
  const MiniPlayerBar({super.key});

  /// A well-known key so tests can tap the bar area to open the player.
  static const Key barKey = Key('mini_player_bar');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playbackStateProvider).value;
    final track = state?.currentTrack;
    if (state == null || track == null) {
      return const SizedBox.shrink();
    }

    final durationMs = state.duration?.inMilliseconds ?? 0;
    final positionMs = state.position.inMilliseconds;
    final progress = durationMs > 0
        ? (positionMs / durationMs).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        0,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: GlassSurface(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppGlass.shadow,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              child: Row(
                children: [
                  Expanded(child: _MiniLabelStrip(current: track)),
                  // Play/pause.
                  IconButton(
                    onPressed: () =>
                        ref.read(playbackControllerProvider).togglePlayPause(),
                    icon: Icon(
                      state.isPlaying ? Icons.pause : Icons.play_arrow,
                    ),
                  ),
                  // Next.
                  IconButton(
                    onPressed: state.hasNext
                        ? () => ref.read(playbackControllerProvider).next()
                        : null,
                    icon: const Icon(Icons.skip_next),
                  ),
                ],
              ),
            ),
            // Thin progress line at the very bottom, clipped by the capsule.
            if (durationMs > 0)
              LinearProgressIndicator(value: progress, minHeight: 2),
          ],
        ),
      ),
    );
  }
}

/// The swipeable cover + title/artist strip: `[previous][current][next]`,
/// following the finger, committing to the neighbour past the threshold.
class _MiniLabelStrip extends ConsumerStatefulWidget {
  const _MiniLabelStrip({required this.current});

  final Track current;

  @override
  ConsumerState<_MiniLabelStrip> createState() => _MiniLabelStripState();
}

class _MiniLabelStripState extends ConsumerState<_MiniLabelStrip>
    with SingleTickerProviderStateMixin {
  /// -1 = next shown, 0 = resting on current, +1 = previous shown.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppMotion.standard,
    lowerBound: -1,
    upperBound: 1,
    value: 0,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _commit(int direction) async {
    await _c.animateTo(direction.toDouble(), curve: AppMotion.standardCurve);
    final controller = ref.read(playbackControllerProvider);
    if (direction > 0) {
      await controller.previous();
    } else {
      await controller.next();
    }
    if (mounted) _c.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    // Re-centre when the loaded track actually changes.
    ref.listen(playbackStateProvider, (previous, next) {
      if (previous?.value?.currentTrack?.uri !=
              next.value?.currentTrack?.uri &&
          !_c.isAnimating) {
        _c.value = 0;
      }
    });
    final previousTrack = ref.watch(previousTrackProvider);
    final nextTrack = ref.watch(nextTrackProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox(
          height: 40,
          child: GestureDetector(
            key: MiniPlayerBar.barKey,
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).push(playerRoute(context)),
            onHorizontalDragUpdate: (details) {
              _c.value = (_c.value + details.delta.dx / width).clamp(-1.0, 1.0);
            },
            onHorizontalDragEnd: (details) {
              final velocity = details.velocity.pixelsPerSecond.dx;
              if ((_c.value <= -0.4 || velocity < -700) && nextTrack != null) {
                _commit(-1);
              } else if ((_c.value >= 0.4 || velocity > 700) &&
                  previousTrack != null) {
                _commit(1);
              } else {
                _c.animateTo(0, curve: AppMotion.standardCurve);
              }
            },
            child: ClipRect(
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, child) {
                  final dx = -_c.value * width;
                  return Stack(
                    fit: StackFit.expand,
                    clipBehavior: Clip.hardEdge,
                    children: [
                      _pane(previousTrack, dx - width, width, hero: false),
                      _pane(widget.current, dx, width, hero: true),
                      _pane(nextTrack, dx + width, width, hero: false),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _pane(Track? track, double left, double width, {required bool hero}) {
    final value = track;
    if (value == null) return const SizedBox.shrink();
    return Positioned(
      left: left,
      width: width,
      top: 0,
      bottom: 0,
      child: _MiniLabel(track: value, hero: hero),
    );
  }
}

/// Cover + title/artist for one carousel pane. Only the centred pane carries a
/// [CoverHero] (neighbours must not share the tag).
class _MiniLabel extends StatelessWidget {
  const _MiniLabel({required this.track, required this.hero});

  final Track track;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final cover = _MiniCover(track: track);
    return Row(
      children: [
        if (hero)
          CoverHero(
            uri: track.uri,
            coverPath: track.coverPath,
            coverUrl: track.coverUrl,
            child: cover,
          )
        else
          cover,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                track.artist ?? l10n.unknownArtist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniCover extends StatelessWidget {
  const _MiniCover({required this.track});

  final Track track;
  static const double _size = 40;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final coverPath = track.coverPath;
    final coverUrl = track.coverUrl;
    final hasCover =
        (coverPath != null && coverPath.isNotEmpty) ||
        (coverUrl != null && coverUrl.isNotEmpty);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        width: _size,
        height: _size,
        color: scheme.surfaceContainerHighest,
        child: hasCover
            ? CoverImage(
                path: coverPath,
                url: coverUrl,
                size: _size,
                errorBuilder: (context, error, stackTrace) =>
                    _placeholder(scheme),
              )
            : _placeholder(scheme),
      ),
    );
  }

  Widget _placeholder(ColorScheme scheme) =>
      Icon(Icons.music_note, size: _size * 0.5, color: scheme.onSurfaceVariant);
}
