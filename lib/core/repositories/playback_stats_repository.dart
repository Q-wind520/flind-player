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

import 'package:flind_player/core/models/playback_session.dart';

/// Append-only playback history plus its derived aggregates.
///
/// The event log is the source of truth; [summary] is computed from it (or
/// from the rebuildable aggregate tables) and must never invent data.
abstract interface class PlaybackStatsRepository {
  /// Appends [session] and updates the per-track/per-day aggregates in the same
  /// transaction. A session below [PlaybackSession.minimumRecordedListen] is
  /// ignored.
  Future<void> record(PlaybackSession session);

  /// Most recent sessions, newest first.
  Future<List<PlaybackEvent>> recent({int limit = 50});

  /// Emits [recent] whenever playback history changes.
  Stream<List<PlaybackEvent>> watchRecent({int limit = 50});

  /// Aggregate numbers for [period]. Ordered by play count, then last played.
  Future<PlaybackStatsSummary> summary({
    PlaybackStatsPeriod period = PlaybackStatsPeriod.all,
  });

  /// Removes all events and aggregates. Intended for an explicit user action.
  Future<void> clear();
}
