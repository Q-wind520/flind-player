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
  ///
  /// Pass [autoPlay] = false to load the queue and resolve the current track
  /// without producing sound — used when restoring a session, where playback
  /// must come up paused.
  Future<void> playQueue(
    PlaybackQueue queue, {
    int index = 0,
    bool autoPlay = true,
  });

  /// Replaces the cover pointer of the queued track identified by [uri].
  ///
  /// Covers are resolved *after* a track enters the queue, so the live
  /// in-memory queue must be patched for the player UI to show the freshly
  /// cached artwork. A no-op when no queued track carries [uri]; `null` values
  /// leave the corresponding field unchanged.
  Future<void> updateTrackCover(
    String uri, {
    String? coverPath,
    String? coverUrl,
  });

  Future<void> play();

  Future<void> pause();

  Future<void> togglePlayPause();

  Future<void> next();

  Future<void> previous();

  Future<void> seek(Duration position);

  Future<void> setRepeatMode(RepeatMode mode);

  Future<void> setShuffle(bool enabled);

  /// Sets the output volume as a linear gain.
  ///
  /// Implementations clamp [volume] to the supported `0.01`–`1.4` range and
  /// update [PlaybackState.volume] so the UI reflects the applied value.
  Future<void> setVolume(double volume);

  Future<void> dispose();
}
