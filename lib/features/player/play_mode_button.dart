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

// Flutter 3.47 exports its own `RepeatMode` (for `RepeatingAnimationBuilder`),
// which collides with the playback model of the same name.
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flind_player/core/models/playback_state.dart';
import 'package:flind_player/core/models/repeat_mode.dart';
import 'package:flind_player/data/providers/playback_providers.dart';

/// The playback modes cycled by the play-mode button.
///
/// Each mode maps to one `(repeatMode, shuffle)` pair on the controller.
enum PlayMode {
  /// Plays through the queue once, in order.
  sequential(icon: Icons.playlist_play, repeat: RepeatMode.off, shuffle: false),

  /// Loops the whole queue.
  repeatAll(icon: Icons.repeat, repeat: RepeatMode.all, shuffle: false),

  /// Repeats the current track.
  repeatOne(icon: Icons.repeat_one, repeat: RepeatMode.one, shuffle: false),

  /// Shuffles the queue without repeating.
  shufflePlay(icon: Icons.shuffle, repeat: RepeatMode.off, shuffle: true);

  const PlayMode({
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
  bool get isActive => this != PlayMode.sequential;

  /// The mode reached by the next tap, wrapping 随机 → 顺序.
  PlayMode get next => switch (this) {
    PlayMode.sequential => PlayMode.repeatAll,
    PlayMode.repeatAll => PlayMode.repeatOne,
    PlayMode.repeatOne => PlayMode.shufflePlay,
    PlayMode.shufflePlay => PlayMode.sequential,
  };

  /// Derives the mode from [state]; shuffle takes precedence over repeat.
  static PlayMode fromState(PlaybackState state) {
    if (state.shuffleEnabled) {
      return PlayMode.shufflePlay;
    }
    return switch (state.repeatMode) {
      RepeatMode.off => PlayMode.sequential,
      RepeatMode.all => PlayMode.repeatAll,
      RepeatMode.one => PlayMode.repeatOne,
    };
  }
}

/// The shuffle / repeat / sequential cycler shared by the transport and
/// [MiniSettings].
///
/// Watches [playbackStateProvider] for the current mode and drives
/// [PlaybackController.setShuffle] / [setRepeatMode] on tap — shuffle first so
/// the queue is (un)shuffled before the new repeat mode is applied.
class PlayModeButton extends ConsumerWidget {
  const PlayModeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(playbackStateProvider).value;
    final controller = ref.read(playbackControllerProvider);
    final mode = state == null
        ? PlayMode.sequential
        : PlayMode.fromState(state);

    return IconButton(
      onPressed: () {
        final next = mode.next;
        // Shuffle first so the queue is (un)shuffled before the controller
        // applies the new repeat mode.
        controller.setShuffle(next.shuffle);
        controller.setRepeatMode(next.repeat);
      },
      icon: Icon(mode.icon),
      color: mode.isActive ? scheme.primary : null,
    );
  }
}
