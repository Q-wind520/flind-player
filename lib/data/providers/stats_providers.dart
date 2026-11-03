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

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flind_player/core/models/playback_session.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/data/providers/persistence_providers.dart';

/// The latest playback events, newest first.
final recentPlayEventsProvider = StreamProvider<List<PlaybackEvent>>(
  (ref) => ref.watch(playbackStatsRepositoryProvider).watchRecent(limit: 100),
);

/// Distinct tracks from [recentPlayEventsProvider], newest occurrence first.
///
/// The recent page is a "what did I listen to" list, not an event log; repeats
/// collapse to one row while the stats page keeps the real play counts.
final recentTracksProvider = Provider<List<Track>>((ref) {
  final events = ref.watch(recentPlayEventsProvider).value;
  if (events == null) return const <Track>[];

  final seen = <String>{};
  final tracks = <Track>[];
  for (final event in events) {
    if (seen.add(event.track.uri)) tracks.add(event.track);
  }
  return List<Track>.unmodifiable(tracks);
});

/// Aggregate numbers for one period.
///
/// Depends on [recentPlayEventsProvider] so a new playback event refreshes the
/// summary without a manual invalidation.
final playbackStatsSummaryProvider = FutureProvider.autoDispose
    .family<PlaybackStatsSummary, PlaybackStatsPeriod>((ref, period) {
      ref.watch(recentPlayEventsProvider);
      return ref.watch(playbackStatsRepositoryProvider).summary(period: period);
    });
