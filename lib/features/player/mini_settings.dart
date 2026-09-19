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

import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/features/player/player_panels.dart';
import 'package:flind_player/features/player/player_surface.dart';
import 'package:flind_player/features/player/sleep_timer.dart';
import 'package:flind_player/l10n/app_localizations.dart';

/// Height of the docked settings bar, reserved by the player layout so the
/// volume overlay and the scrim can cover exactly the same slot.
const double kMiniSettingsHeight = 56;

/// The docked bottom control bar of the now-playing screen.
///
/// Five compact icon buttons: 更多, 调节, 定时关闭, 音量 and 播放列表. The sleep
/// timer button reflects the armed state (tinted icon plus a live countdown
/// label); the volume button delegates to [onVolumeTap] so the parent can swap
/// the bar for a [VolumeBar].
class MiniSettings extends ConsumerWidget {
  const MiniSettings({super.key, required this.onVolumeTap});

  /// Called when the volume button is tapped; the parent opens the volume
  /// overlay instead of a panel.
  final VoidCallback onVolumeTap;

  /// Stable keys so tests can target each button.
  static const Key moreKey = Key('mini_settings_more');
  static const Key tuneKey = Key('mini_settings_tune');
  static const Key sleepTimerKey = Key('mini_settings_sleep_timer');
  static const Key volumeKey = Key('mini_settings_volume');
  static const Key playlistKey = Key('mini_settings_playlist');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final volume = ref.watch(playbackStateProvider).value?.volume ?? 1.0;
    final sleepState = ref.watch(sleepTimerProvider);

    return PlayerSurface(
      child: SizedBox(
        height: kMiniSettingsHeight,
        child: Row(
          children: [
            Expanded(
              child: Center(
                child: _barButton(
                  key: moreKey,
                  icon: Icons.more_vert,
                  tooltip: l10n.playerMore,
                  onTap: () => _openPanel(
                    context,
                    EmptyPanel(icon: Icons.more_vert, title: l10n.playerMore),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: _barButton(
                  key: tuneKey,
                  icon: Icons.tune,
                  tooltip: l10n.playerTune,
                  onTap: () => _openPanel(
                    context,
                    EmptyPanel(icon: Icons.tune, title: l10n.playerTune),
                    portraitFraction: 0.8,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: _sleepTimerButton(context, l10n, sleepState),
              ),
            ),
            Expanded(
              child: Center(
                child: _barButton(
                  key: volumeKey,
                  icon: _volumeIcon(volume),
                  tooltip: l10n.playerVolume,
                  onTap: onVolumeTap,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: _barButton(
                  key: playlistKey,
                  icon: Icons.queue_music,
                  tooltip: l10n.playerPlaylist,
                  onTap: () => _openPanel(context, const PlaylistPanel()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A compact icon button sized to survive a 280 px-wide bar.
  Widget _barButton({
    required Key key,
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        key: key,
        onPressed: onTap,
        icon: Icon(icon),
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      ),
    );
  }

  /// The sleep-timer button: tinted when armed, with a live countdown label
  /// (or a dot for end-of-track mode) under the icon.
  Widget _sleepTimerButton(
    BuildContext context,
    AppLocalizations l10n,
    SleepTimerState state,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final active = state.isActive;
    final color = active ? scheme.primary : null;

    return Tooltip(
      message: l10n.playerSleepTimer,
      child: InkWell(
        key: MiniSettings.sleepTimerKey,
        onTap: () => _openPanel(
          context,
          const SleepTimerPanel(),
          portraitFraction: 0.5,
          landscapeFraction: 0.5,
        ),
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          width: 56,
          height: kMiniSettingsHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                active ? Icons.bedtime : Icons.bedtime_outlined,
                size: 24,
                color: color,
              ),
              if (state.mode == SleepTimerMode.duration &&
                  state.remaining != null)
                Text(
                  formatSleepTimerCountdown(state.remaining!),
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.0,
                    color: color ?? scheme.onSurfaceVariant,
                  ),
                )
              else if (state.isEndOfTrack)
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color ?? scheme.onSurfaceVariant,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The volume overlay that replaces [MiniSettings] while open.
///
/// Watches [playbackStateProvider] and drives [PlaybackController.setVolume]
/// directly from the slider; the controller clamps to the `0.01`–`1.4` range.
class VolumeBar extends ConsumerWidget {
  const VolumeBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final volume = ref.watch(playbackStateProvider).value?.volume ?? 1.0;
    final controller = ref.read(playbackControllerProvider);
    final percent = (volume * 100).round();

    return PlayerSurface(
      child: SizedBox(
        height: kMiniSettingsHeight,
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(_volumeIcon(volume), color: scheme.onSurfaceVariant),
            Expanded(
              child: Slider(
                value: volume.clamp(0.01, 1.4).toDouble(),
                min: 0.01,
                max: 1.4,
                onChanged: (value) => controller.setVolume(value),
              ),
            ),
            Text(
              l10n.volumePercent(percent),
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}

/// Opens [panel] through [showPlayerPanel] with the given fractions.
Future<void> _openPanel(
  BuildContext context,
  Widget panel, {
  double portraitFraction = 0.66,
  double landscapeFraction = 0.34,
}) {
  return showPlayerPanel<void>(
    context,
    portraitFraction: portraitFraction,
    landscapeFraction: landscapeFraction,
    builder: (_) => panel,
  );
}

/// The speaker icon for a linear-gain [volume].
IconData _volumeIcon(double volume) {
  if (volume <= 0.01) {
    return Icons.volume_off;
  }
  if (volume < 0.5) {
    return Icons.volume_down;
  }
  return Icons.volume_up;
}
