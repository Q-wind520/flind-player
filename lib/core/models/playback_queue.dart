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

import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:flind_player/core/models/repeat_mode.dart';
import 'package:flind_player/core/models/track.dart';

/// An immutable, engine-agnostic playback queue.
///
/// This type is pure Dart: it has no dependency on any playback engine and can
/// be unit-tested in isolation.
@immutable
class PlaybackQueue {
  /// Tracks in their current (possibly shuffled) playback order.
  final List<Track> tracks;

  /// Index of the current track in [tracks], or `-1` when idle.
  final int currentIndex;

  /// For each position in [tracks], the index it occupied in the original
  /// (pre-shuffle) order. Identity when the queue is not shuffled.
  final List<int> originalOrder;

  const PlaybackQueue({
    required this.tracks,
    required this.currentIndex,
    required this.originalOrder,
  });

  /// An empty queue with no current track.
  static const empty = PlaybackQueue(
    tracks: [],
    currentIndex: -1,
    originalOrder: [],
  );

  bool get isEmpty => tracks.isEmpty;

  int get length => tracks.length;

  /// The track at [currentIndex], or `null` when out of range.
  Track? get currentTrack => currentIndex >= 0 && currentIndex < tracks.length
      ? tracks[currentIndex]
      : null;

  PlaybackQueue copyWith({
    List<Track>? tracks,
    int? currentIndex,
    List<int>? originalOrder,
  }) {
    return PlaybackQueue(
      tracks: tracks ?? this.tracks,
      currentIndex: currentIndex ?? this.currentIndex,
      originalOrder: originalOrder ?? this.originalOrder,
    );
  }

  /// Returns a queue whose tracks are shuffled, keeping the same current track.
  ///
  /// [originalOrder] records, for each new position, the pre-shuffle index the
  /// track came from. Shuffling always starts from the canonical order, so
  /// calling this repeatedly stays coherent.
  PlaybackQueue shuffled(Random random) {
    if (tracks.length < 2) {
      return this;
    }

    final base = unshuffled();
    final permutation = List<int>.generate(tracks.length, (i) => i)
      ..shuffle(random);
    final shuffledTracks = [for (final i in permutation) base.tracks[i]];
    final shuffledIndex = base.currentIndex < 0
        ? base.currentIndex
        : permutation.indexOf(base.currentIndex);

    return PlaybackQueue(
      tracks: shuffledTracks,
      currentIndex: shuffledIndex,
      originalOrder: permutation,
    );
  }

  /// Restores [tracks] to their original (pre-shuffle) order.
  PlaybackQueue unshuffled() {
    if (tracks.isEmpty) {
      return this;
    }

    final restored = List<Track>.filled(tracks.length, tracks.first);
    for (var i = 0; i < tracks.length; i++) {
      restored[originalOrder[i]] = tracks[i];
    }

    final restoredIndex = currentIndex < 0 || currentIndex >= tracks.length
        ? currentIndex
        : originalOrder[currentIndex];

    return PlaybackQueue(
      tracks: restored,
      currentIndex: restoredIndex,
      originalOrder: List<int>.generate(tracks.length, (i) => i),
    );
  }

  /// The index to advance to, or `null` when playback should stop.
  ///
  /// * [RepeatMode.one] repeats the current index.
  /// * [RepeatMode.all] wraps from the last track to the first.
  /// * [RepeatMode.off] returns `null` at the end of the queue.
  int? nextIndex({required RepeatMode repeatMode}) {
    if (tracks.isEmpty) {
      return null;
    }
    if (repeatMode == RepeatMode.one && currentIndex >= 0) {
      return currentIndex;
    }
    if (currentIndex < 0) {
      return 0;
    }
    if (currentIndex >= tracks.length - 1) {
      return repeatMode == RepeatMode.all ? 0 : null;
    }
    return currentIndex + 1;
  }

  /// The index to move back to, or `null` when there is no previous track.
  ///
  /// * [RepeatMode.one] repeats the current index.
  /// * [RepeatMode.all] wraps from the first track to the last.
  /// * [RepeatMode.off] returns `null` at the start of the queue.
  int? previousIndex({required RepeatMode repeatMode}) {
    if (tracks.isEmpty) {
      return null;
    }
    if (repeatMode == RepeatMode.one && currentIndex >= 0) {
      return currentIndex;
    }
    if (currentIndex <= 0) {
      return repeatMode == RepeatMode.all ? tracks.length - 1 : null;
    }
    return currentIndex - 1;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaybackQueue &&
          listEquals(other.tracks, tracks) &&
          other.currentIndex == currentIndex &&
          listEquals(other.originalOrder, originalOrder);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(tracks),
    currentIndex,
    Object.hashAll(originalOrder),
  );

  @override
  String toString() =>
      'PlaybackQueue(length: $length, currentIndex: $currentIndex)';
}
