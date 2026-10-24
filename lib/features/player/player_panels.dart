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
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flind_player/app/theme/app_icons.dart';
import 'package:flind_player/app/theme/app_theme.dart';
import 'package:flind_player/app/theme/app_tokens.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/services/playback_controller.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/features/library/widgets/playlist_picker_sheet.dart';
import 'package:flind_player/features/player/sleep_timer.dart';
import 'package:flind_player/l10n/app_localizations.dart';
import 'package:flind_player/shared/cover_image.dart';

/// Opens a player panel adapted to the window orientation.
///
/// In portrait (width <= height) the panel slides up from the bottom as a
/// floating rounded card occupying [portraitFraction] of the screen height.
/// In landscape it fades/slides in from the right as a floating card whose
/// width comes from [landscapeFraction] and whose height is [landscapeHeight]
/// (or 680 px by default).
Future<T?> showPlayerPanel<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double portraitFraction = 0.66,
  double landscapeFraction = 0.34,
  double? landscapeHeight,
}) {
  final size = MediaQuery.sizeOf(context);
  final landscape = size.width > size.height;

  if (landscape) {
    final panelWidth = (size.width * landscapeFraction).clamp(320.0, 420.0);
    final panelHeight = math.max(
      240.0,
      math.min(size.height - 32, landscapeHeight ?? 680.0),
    );
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.38),
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, secondaryAnimation) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: panelWidth,
                height: panelHeight,
                child: _PanelFrame(landscape: true, child: builder(context)),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.12, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.38),
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: SizedBox(
          height: size.height * portraitFraction,
          child: _PanelFrame(landscape: false, child: builder(context)),
        ),
      );
    },
  );
}

/// Formats a countdown [duration] as `mm:ss`.
String formatSleepTimerCountdown(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

/// Shared chrome for every player panel: rounded surface, a drag handle in
/// portrait, and the panel body below it.
class _PanelFrame extends StatelessWidget {
  const _PanelFrame({required this.landscape, required this.child});

  final bool landscape;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppRadius.lg);
    return Material(
      color: scheme.surfaceContainerHigh,
      elevation: 24,
      shadowColor: Colors.black.withValues(alpha: 0.55),
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.65),
          ),
        ),
        child: Column(
          children: [
            if (!landscape) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ],
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// Panel header: the l10n title plus a close affordance.
class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, size: 20, color: scheme.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: '',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(AppIcons.close, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: scheme.surfaceContainerLow,
              foregroundColor: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// A panel with no content yet: a muted icon and the "暂无内容" placeholder.
///
/// Used for the 更多 and 调节 panels until their features land.
class EmptyPanel extends StatelessWidget {
  const EmptyPanel({super.key, required this.icon, required this.title});

  /// Icon echoed from the MiniSettings button that opened the panel.
  final IconData icon;

  /// Header title (the l10n label of the opening button).
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        _PanelHeader(title: title, icon: icon),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 12),
                Text(
                  l10n.playerPanelEmpty,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Playback-tuning panel: the playback-speed slider.
///
/// Watches [playbackStateProvider] so the slider and the percentage label
/// reflect the applied speed, and drives [PlaybackController.setSpeed] live.
class PlayerTunePanel extends ConsumerWidget {
  const PlayerTunePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final speed = ref.watch(playbackStateProvider).value?.speed ?? 1.0;
    final controller = ref.read(playbackControllerProvider);
    final percent = (speed * 100).round();

    return Column(
      children: [
        _PanelHeader(title: l10n.playerTune, icon: AppIcons.tune),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Icon(
                      AppIcons.speed,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Text(l10n.playerSpeed, style: theme.textTheme.titleSmall),
                    const Spacer(),
                    Text(
                      l10n.volumePercent(percent),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Slider(
                value: speed.clamp(
                  PlaybackController.minSpeed,
                  PlaybackController.maxSpeed,
                ),
                min: PlaybackController.minSpeed,
                max: PlaybackController.maxSpeed,
                onChanged: (value) => unawaited(controller.setSpeed(value)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatSpeed(PlaybackController.minSpeed),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      _formatSpeed(PlaybackController.maxSpeed),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Formats a playback rate as `1.0×`, `1.5×`, ...
String _formatSpeed(double speed) => '${speed.toStringAsFixed(1)}×';

/// Sleep-timer panel: off, minute presets, and end-of-track.
///
/// Watches [sleepTimerProvider] so the armed option stays highlighted and the
/// live countdown updates while the panel is open.
class SleepTimerPanel extends ConsumerWidget {
  const SleepTimerPanel({super.key});

  /// Preset durations offered by the panel, in minutes.
  static const List<int> presets = <int>[10, 20, 30, 45, 60];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(sleepTimerProvider);
    final notifier = ref.read(sleepTimerProvider.notifier);
    final selectedPreset = _selectedPreset(state);

    return Column(
      children: [
        _PanelHeader(title: l10n.playerSleepTimer, icon: AppIcons.timer),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              if (state.isActive) _ActiveBanner(state: state, l10n: l10n),
              _OptionRow(
                label: l10n.sleepTimerOff,
                selected: state.mode == SleepTimerMode.off,
                onTap: notifier.cancel,
              ),
              for (final minutes in presets)
                _OptionRow(
                  label: l10n.sleepTimerMinutes(minutes),
                  selected: selectedPreset == minutes,
                  onTap: () => notifier.start(Duration(minutes: minutes)),
                ),
              _OptionRow(
                label: l10n.sleepTimerEndOfTrack,
                selected: state.isEndOfTrack,
                onTap: notifier.startEndOfTrack,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The preset whose duration is the smallest one still covering the armed
  /// countdown, so the highlight stays on the tapped preset as it ticks down.
  static int? _selectedPreset(SleepTimerState state) {
    if (state.mode != SleepTimerMode.duration) {
      return null;
    }
    final remaining = state.remaining;
    if (remaining == null) {
      return null;
    }
    final minutes = remaining.inMinutes;
    for (final preset in presets) {
      if (preset >= minutes) {
        return preset;
      }
    }
    return presets.last;
  }
}

/// Live status banner shown while a timer is armed.
class _ActiveBanner extends StatelessWidget {
  const _ActiveBanner({required this.state, required this.l10n});

  final SleepTimerState state;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = state.isEndOfTrack
        ? l10n.sleepTimerEndOfTrack
        : l10n.sleepTimerRemaining(
            formatSleepTimerCountdown(state.remaining ?? Duration.zero),
          );
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(AppIcons.timer, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A selectable sleep-timer option row.
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = BorderRadius.circular(AppRadius.md);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      child: Material(
        color: selected
            ? scheme.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: selected ? scheme.primary : scheme.onSurface,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                AnimatedOpacity(
                  opacity: selected ? 1 : 0,
                  duration: AppMotion.fast,
                  child: Icon(AppIcons.check, size: 18, color: scheme.primary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The current playback queue with a highlighted current row.
///
/// Tapping a row jumps the queue to that index and closes the panel.
class PlaylistPanel extends ConsumerWidget {
  const PlaylistPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(playbackControllerProvider);
    final queue = controller.queue;

    return Column(
      children: [
        _PanelHeader(title: l10n.playerPlaylist, icon: AppIcons.queueMusic),
        if (!queue.isEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _saveCurrentTrack(context, ref),
              icon: const Icon(AppIcons.playlistAdd, size: 18),
              label: Text(l10n.addToPlaylist),
            ),
          ),
        Expanded(
          child: queue.isEmpty
              ? Center(
                  child: Text(
                    l10n.playlistEmpty,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: queue.tracks.length,
                  itemBuilder: (context, index) {
                    final track = queue.tracks[index];
                    return _QueueRow(
                      track: track,
                      isCurrent: index == queue.currentIndex,
                      onTap: () {
                        ref
                            .read(playbackControllerProvider)
                            .playQueue(
                              queue.copyWith(currentIndex: index),
                              index: index,
                            );
                        Navigator.of(context).maybePop();
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// Opens the playlist picker for the currently playing track.
  Future<void> _saveCurrentTrack(BuildContext context, WidgetRef ref) async {
    final queue = ref.read(playbackControllerProvider).queue;
    final index = queue.currentIndex;
    if (queue.tracks.isEmpty || index < 0 || index >= queue.tracks.length) {
      return;
    }
    await showPlaylistPickerSheet(context, track: queue.tracks[index]);
  }
}

/// One queue row: equalizer indicator (current), 40×40 cover, title, artist.
class _QueueRow extends StatelessWidget {
  const _QueueRow({
    required this.track,
    required this.isCurrent,
    required this.onTap,
  });

  final Track track;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final radius = BorderRadius.circular(AppRadius.sm);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      child: Material(
        color: isCurrent ? AppTheme.playingRowTint(scheme) : Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                if (isCurrent) ...[
                  Icon(AppIcons.graphicEq, size: 18, color: scheme.primary),
                  const SizedBox(width: AppSpacing.sm),
                ],
                _QueueCover(track: track),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: isCurrent
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                      Text(
                        track.artist ?? l10n.unknownArtist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
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
    );
  }
}

/// 40×40 rounded cover with a tonal music-note placeholder.
class _QueueCover extends StatelessWidget {
  const _QueueCover({required this.track});

  final Track track;
  static const double _size = 44;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final coverPath = track.coverPath;
    final coverUrl = track.coverUrl;
    final hasCover =
        (coverPath != null && coverPath.isNotEmpty) ||
        (coverUrl != null && coverUrl.isNotEmpty);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
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

  Widget _placeholder(ColorScheme scheme) => Icon(
    AppIcons.musicNote,
    size: _size * 0.5,
    color: scheme.onSurfaceVariant,
  );
}
