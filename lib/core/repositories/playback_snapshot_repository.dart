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

import 'package:flutter/foundation.dart';

import 'package:flind_player/core/models/playback_queue.dart';
import 'package:flind_player/core/models/repeat_mode.dart';

/// A restorable snapshot of the playback session.
///
/// It captures the queue (order + current index), the playback position and the
/// repeat/shuffle toggles. Play/pause is deliberately absent: a restored
/// session always starts paused.
@immutable
class PlaybackSnapshot {
  const PlaybackSnapshot({
    required this.queue,
    required this.position,
    required this.repeatMode,
    required this.shuffleEnabled,
  });

  /// The queue at the time of the snapshot, including `originalOrder`.
  final PlaybackQueue queue;

  /// Playback position of the current track.
  final Duration position;

  final RepeatMode repeatMode;
  final bool shuffleEnabled;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaybackSnapshot &&
          other.queue == queue &&
          other.position == position &&
          other.repeatMode == repeatMode &&
          other.shuffleEnabled == shuffleEnabled;

  @override
  int get hashCode => Object.hash(queue, position, repeatMode, shuffleEnabled);

  @override
  String toString() =>
      'PlaybackSnapshot(queue: $queue, position: $position, '
      'repeat: $repeatMode, shuffle: $shuffleEnabled)';
}

/// Persists a single [PlaybackSnapshot] across launches.
abstract interface class PlaybackSnapshotRepository {
  /// The last saved snapshot, or `null` when nothing was saved (or the stored
  /// row is unreadable).
  Future<PlaybackSnapshot?> load();

  /// Upserts the singleton snapshot row.
  Future<void> save(PlaybackSnapshot snapshot);

  /// Removes the stored snapshot.
  Future<void> clear();
}
