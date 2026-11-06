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

import 'package:flind_player/core/models/track.dart';

/// One continuous listening session for a track.
///
/// The service produces these from real playback state; the repository appends
/// an event and updates the derived aggregates. [listened] is wall-clock time
/// spent playing, not the final media position, so pausing and seeking do not
/// inflate it.
@immutable
class PlaybackSession {
  const PlaybackSession({
    required this.trackUri,
    required this.startedAt,
    required this.endedAt,
    required this.listened,
    required this.completed,
    this.position,
    this.duration,
  });

  final String trackUri;
  final DateTime startedAt;
  final DateTime endedAt;

  /// Time actually spent playing during this session.
  final Duration listened;

  /// Whether the track reached its natural end (or the completion threshold).
  final bool completed;

  /// Last known playback position.
  final Duration? position;

  /// Track duration when the session began.
  final Duration? duration;

  /// The count rule shared by the UI and the repository: a session counts as
  /// one play after 30 seconds of listening, or when the track completes.
  static const Duration playCountThreshold = Duration(seconds: 30);

  /// Sessions shorter than this are not worth a recent-list row.
  static const Duration minimumRecordedListen = Duration(seconds: 5);

  /// Whether this session contributes a play count.
  bool get countsAsPlay => completed || listened >= playCountThreshold;

  /// Whether this session should be persisted at all.
  bool get isRecordable => countsAsPlay || listened >= minimumRecordedListen;

  @override
  String toString() =>
      'PlaybackSession($trackUri, listened: $listened, completed: $completed)';
}

/// A persisted playback event joined with its track metadata.
@immutable
class PlaybackEvent {
  const PlaybackEvent({
    required this.id,
    required this.track,
    required this.startedAt,
    required this.listened,
    required this.completed,
    required this.countsAsPlay,
  });

  final int id;
  final Track track;
  final DateTime startedAt;
  final Duration listened;
  final bool completed;
  final bool countsAsPlay;

  String get trackUri => track.uri;
}

/// Aggregate listening numbers for one track.
@immutable
class TrackPlayStat {
  const TrackPlayStat({
    required this.track,
    required this.playCount,
    required this.listenTime,
    this.lastPlayedAt,
  });

  final Track track;
  final int playCount;
  final Duration listenTime;
  final DateTime? lastPlayedAt;

  String get trackUri => track.uri;
}

/// The period a stats summary covers.
enum PlaybackStatsPeriod { day, week, month, year, all }

/// A read model for the stats screen.
@immutable
class PlaybackStatsSummary {
  const PlaybackStatsSummary({
    required this.period,
    required this.totalPlayCount,
    required this.totalListenTime,
    required this.trackCount,
    required this.tracks,
  });

  const PlaybackStatsSummary.empty(this.period)
    : totalPlayCount = 0,
      totalListenTime = Duration.zero,
      trackCount = 0,
      tracks = const <TrackPlayStat>[];

  final PlaybackStatsPeriod period;
  final int totalPlayCount;
  final Duration totalListenTime;
  final int trackCount;

  /// Per-track rows, normally ordered by play count then last played.
  final List<TrackPlayStat> tracks;
}
