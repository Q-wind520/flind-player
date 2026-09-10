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

import 'package:flind_player/core/models/playback_queue.dart';
import 'package:flind_player/core/models/playback_state.dart';
import 'package:flind_player/core/models/repeat_mode.dart';

/// Controls playback of a [PlaybackQueue] and exposes its [PlaybackState].
///
/// UI code must depend on this interface, never on a concrete engine.
abstract interface class PlaybackController {
  /// Broadcasts state updates.
  Stream<PlaybackState> get state;

  /// The most recently emitted state.
  PlaybackState get currentState;

  /// The queue currently loaded into the player.
  PlaybackQueue get queue;

  /// Loads [queue] and starts playing its track at [index].
  Future<void> playQueue(PlaybackQueue queue, {int index = 0});

  Future<void> play();

  Future<void> pause();

  Future<void> togglePlayPause();

  Future<void> next();

  Future<void> previous();

  Future<void> seek(Duration position);

  Future<void> setRepeatMode(RepeatMode mode);

  Future<void> setShuffle(bool enabled);

  Future<void> dispose();
}
