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

import 'package:flind_player/core/models/repeat_mode.dart';
import 'package:flind_player/core/models/track.dart';

/// Immutable snapshot of the player's state.
@immutable
class PlaybackState {
  final bool isPlaying;
  final bool isBuffering;
  final bool isCompleted;
  final Duration position;
  final Duration? duration;
  final Track? currentTrack;
  final RepeatMode repeatMode;
  final bool shuffleEnabled;
  final bool hasNext;
  final bool hasPrevious;

  const PlaybackState({
    required this.isPlaying,
    required this.isBuffering,
    required this.isCompleted,
    required this.position,
    this.duration,
    this.currentTrack,
    this.repeatMode = RepeatMode.off,
    this.shuffleEnabled = false,
    this.hasNext = false,
    this.hasPrevious = false,
  });

  /// Nothing loaded, nothing playing.
  static const idle = PlaybackState(
    isPlaying: false,
    isBuffering: false,
    isCompleted: false,
    position: Duration.zero,
  );

  /// Returns a copy with the given fields replaced.
  ///
  /// Nullable fields keep their current value when omitted.
  PlaybackState copyWith({
    bool? isPlaying,
    bool? isBuffering,
    bool? isCompleted,
    Duration? position,
    Duration? duration,
    Track? currentTrack,
    RepeatMode? repeatMode,
    bool? shuffleEnabled,
    bool? hasNext,
    bool? hasPrevious,
  }) {
    return PlaybackState(
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      isCompleted: isCompleted ?? this.isCompleted,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      currentTrack: currentTrack ?? this.currentTrack,
      repeatMode: repeatMode ?? this.repeatMode,
      shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
      hasNext: hasNext ?? this.hasNext,
      hasPrevious: hasPrevious ?? this.hasPrevious,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaybackState &&
          other.isPlaying == isPlaying &&
          other.isBuffering == isBuffering &&
          other.isCompleted == isCompleted &&
          other.position == position &&
          other.duration == duration &&
          other.currentTrack == currentTrack &&
          other.repeatMode == repeatMode &&
          other.shuffleEnabled == shuffleEnabled &&
          other.hasNext == hasNext &&
          other.hasPrevious == hasPrevious;

  @override
  int get hashCode => Object.hash(
    isPlaying,
    isBuffering,
    isCompleted,
    position,
    duration,
    currentTrack,
    repeatMode,
    shuffleEnabled,
    hasNext,
    hasPrevious,
  );

  @override
  String toString() =>
      'PlaybackState(isPlaying: $isPlaying, position: $position, '
      'track: $currentTrack)';
}
