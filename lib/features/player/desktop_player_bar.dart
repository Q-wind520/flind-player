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

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flind_player/app/theme/app_icons.dart';
import 'package:flind_player/app/theme/app_tokens.dart';
import 'package:flind_player/core/models/playback_state.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/features/player/favorite_button.dart';
import 'package:flind_player/features/player/mini_player_bar.dart';
import 'package:flind_player/features/player/player_panels.dart';
import 'package:flind_player/features/player/play_mode_button.dart';
import 'package:flind_player/l10n/app_localizations.dart';
import 'package:flind_player/shared/cover_hero.dart';
import 'package:flind_player/shared/cover_image.dart';
import 'package:flind_player/shared/duration_format.dart';

/// The expanded-window now-playing bar.
///
/// Unlike the compact floating capsule, this is a full-width dock with the
/// transport in the middle and the queue/expand actions on the right. It sits
/// below the content instead of covering it, so no height measurement is
/// needed.
class DesktopPlayerBar extends ConsumerWidget {
  const DesktopPlayerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playbackStateProvider).value;
    final track = state?.currentTrack;
    if (state == null || track == null) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(playbackControllerProvider);
    final durationMs = state.duration?.inMilliseconds ?? 0;
    final progress = durationMs > 0
        ? (state.position.inMilliseconds / durationMs).clamp(0.0, 1.0)
        : 0.0;
    // Narrow desktop windows cannot afford the time readout; the transport
    // and the queue/expand actions keep their tap targets.
    final showTime = MediaQuery.sizeOf(context).width >= 900;

    return Material(
      color: scheme.surfaceContainerLow,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: progress, minHeight: 2),
            SizedBox(
              height: 72,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: InkWell(
                          key: MiniPlayerBar.barKey,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          onTap: () =>
                              Navigator.of(context).push(playerRoute(context)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                              vertical: AppSpacing.xs,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CoverHero(
                                  uri: track.uri,
                                  coverPath: track.coverPath,
                                  coverUrl: track.coverUrl,
                                  child: _BarCover(state: state),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Flexible(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        track.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      Text(
                                        track.artist ?? l10n.unknownArtist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const PlayModeButton(),
                        IconButton(
                          onPressed: state.hasPrevious
                              ? controller.previous
                              : null,
                          icon: const Icon(AppIcons.skipPrevious),
                          iconSize: 24,
                          constraints: const BoxConstraints.tightFor(
                            width: 40,
                            height: 40,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        const SizedBox(width: 4),
                        IconButton.filled(
                          onPressed: controller.togglePlayPause,
                          icon: Icon(
                            state.isPlaying
                                ? AppIcons.pause
                                : AppIcons.playArrow,
                          ),
                          iconSize: 26,
                          style: IconButton.styleFrom(
                            backgroundColor: scheme.primary,
                            foregroundColor: scheme.onPrimary,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          constraints: const BoxConstraints.tightFor(
                            width: 44,
                            height: 44,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: state.hasNext ? controller.next : null,
                          icon: const Icon(AppIcons.skipNext),
                          iconSize: 24,
                          constraints: const BoxConstraints.tightFor(
                            width: 40,
                            height: 40,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    Expanded(
                      flex: 3,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (showTime) ...[
                              Text(
                                '${formatTrackDuration(state.position)} / '
                                '${formatTrackDuration(state.duration)}',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                            ],
                            FavoriteButton(
                              track: track,
                              size: 40,
                              iconSize: 20,
                            ),
                            IconButton(
                              onPressed: () => showPlayerPanel<void>(
                                context,
                                builder: (_) => const PlaylistPanel(),
                              ),
                              icon: const Icon(AppIcons.queueMusic),
                              iconSize: 20,
                              tooltip: l10n.playerQueue,
                              constraints: const BoxConstraints.tightFor(
                                width: 40,
                                height: 40,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarCover extends StatelessWidget {
  const _BarCover({required this.state});

  final PlaybackState state;

  @override
  Widget build(BuildContext context) {
    final track = state.currentTrack!;
    final scheme = Theme.of(context).colorScheme;
    final coverPath = track.coverPath;
    final coverUrl = track.coverUrl;
    final hasCover =
        (coverPath != null && coverPath.isNotEmpty) ||
        (coverUrl != null && coverUrl.isNotEmpty);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        width: 44,
        height: 44,
        color: scheme.surfaceContainerHighest,
        child: hasCover
            ? CoverImage(
                path: coverPath,
                url: coverUrl,
                size: 44,
                errorBuilder: (context, error, stackTrace) =>
                    Icon(AppIcons.musicNote, color: scheme.onSurfaceVariant),
              )
            : Icon(AppIcons.musicNote, color: scheme.onSurfaceVariant),
      ),
    );
  }
}
