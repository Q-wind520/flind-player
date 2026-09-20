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

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/features/player/sleep_timer.dart';
import 'package:flind_player/l10n/app_localizations.dart';
import 'package:flind_player/shared/cover_image.dart';

/// Opens a player panel adapted to the window orientation.
///
/// In portrait (width <= height) the panel slides up from the bottom as a
/// rounded modal bottom sheet occupying [portraitFraction] of the screen
/// height. In landscape it slides in from the right as a full-height rounded
/// sheet occupying [landscapeFraction] of the screen width.
Future<T?> showPlayerPanel<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double portraitFraction = 0.66,
  double landscapeFraction = 0.34,
}) {
  final size = MediaQuery.sizeOf(context);
  final landscape = size.width > size.height;

  if (landscape) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: size.width * landscapeFraction,
            height: size.height,
            child: SafeArea(
              child: _PanelFrame(landscape: true, child: builder(context)),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return SizedBox(
        height: size.height * portraitFraction,
        child: _PanelFrame(landscape: false, child: builder(context)),
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
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: landscape
          ? const BorderRadius.horizontal(left: Radius.circular(24))
          : const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (!landscape) ...[
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Panel header: the l10n title plus a close affordance.
class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(
        children: [
          Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
          IconButton(
            tooltip: l10n.close,
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close),
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
        _PanelHeader(title: title),
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
        _PanelHeader(title: l10n.playerSleepTimer),
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
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.timer,
            size: 20,
            color: theme.colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
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
    return ListTile(
      title: Text(label),
      trailing: selected
          ? Icon(Icons.check, color: theme.colorScheme.primary)
          : null,
      selected: selected,
      selectedTileColor: theme.colorScheme.primaryContainer.withValues(
        alpha: 0.3,
      ),
      onTap: onTap,
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
        _PanelHeader(title: l10n.playerPlaylist),
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
    return InkWell(
      onTap: onTap,
      child: Container(
        color: isCurrent
            ? scheme.primaryContainer.withValues(alpha: 0.3)
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            if (isCurrent) ...[
              Icon(Icons.graphic_eq, size: 20, color: scheme.primary),
              const SizedBox(width: 8),
            ],
            _QueueCover(track: track),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: isCurrent ? scheme.primary : null,
                      fontWeight: isCurrent ? FontWeight.w600 : null,
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
    );
  }
}

/// 40×40 rounded cover with a tonal music-note placeholder.
class _QueueCover extends StatelessWidget {
  const _QueueCover({required this.track});

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
      borderRadius: BorderRadius.circular(8),
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
