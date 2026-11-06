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

import 'package:drift/drift.dart';

import 'package:flind_player/core/models/playback_session.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/repositories/playback_stats_repository.dart';
import 'package:flind_player/data/database/app_database.dart';
import 'package:flind_player/data/database/ids.dart';
import 'package:flind_player/data/repositories/track_row_mapping.dart';

/// Drift-backed [PlaybackStatsRepository].
///
/// Every write is one transaction over three tables:
/// `play_events` (append-only truth), `track_stats` and `daily_stats`
/// (rebuildable aggregates). Reads join the pool so display metadata is always
/// current and a deleted track can never leave a dangling title.
class DriftPlaybackStatsRepository implements PlaybackStatsRepository {
  DriftPlaybackStatsRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  @override
  Future<void> record(PlaybackSession session) async {
    if (!session.isRecordable) return;

    final now = _clock();
    final playedAt = session.startedAt.millisecondsSinceEpoch;
    final listenedMs = session.listened.inMilliseconds;
    final increment = session.countsAsPlay ? 1 : 0;
    final dayStart = _dayStart(session.startedAt).millisecondsSinceEpoch;

    await _db.transaction(() async {
      await _db
          .into(_db.playEvents)
          .insert(
            PlayEventsCompanion.insert(
              eventId: newPublicId(),
              trackUri: session.trackUri,
              startedAt: playedAt,
              endedAt: Value(session.endedAt.millisecondsSinceEpoch),
              positionMs: Value(session.position?.inMilliseconds ?? 0),
              listenedMs: Value(listenedMs),
              durationMs: Value(session.duration?.inMilliseconds),
              completed: Value(session.completed),
              createdAt: now.millisecondsSinceEpoch,
            ),
          );

      await _upsertTrackStat(
        trackUri: session.trackUri,
        playedAt: playedAt,
        listenedMs: listenedMs,
        increment: increment,
        now: now.millisecondsSinceEpoch,
      );
      await _upsertDailyStat(
        trackUri: session.trackUri,
        dayStart: dayStart,
        listenedMs: listenedMs,
        increment: increment,
      );
    });
  }

  Future<void> _upsertTrackStat({
    required String trackUri,
    required int playedAt,
    required int listenedMs,
    required int increment,
    required int now,
  }) async {
    final existing = await (_db.select(
      _db.trackStats,
    )..where((s) => s.trackUri.equals(trackUri))).getSingleOrNull();

    if (existing == null) {
      await _db
          .into(_db.trackStats)
          .insert(
            TrackStatsCompanion.insert(
              trackUri: trackUri,
              playCount: Value(increment),
              totalMs: Value(listenedMs),
              lastPlayedAt: Value(playedAt),
              updatedAt: now,
            ),
          );
      return;
    }

    final lastPlayed = existing.lastPlayedAt ?? 0;
    await (_db.update(
      _db.trackStats,
    )..where((s) => s.trackUri.equals(trackUri))).write(
      TrackStatsCompanion(
        playCount: Value(existing.playCount + increment),
        totalMs: Value(existing.totalMs + listenedMs),
        lastPlayedAt: Value(playedAt > lastPlayed ? playedAt : lastPlayed),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> _upsertDailyStat({
    required String trackUri,
    required int dayStart,
    required int listenedMs,
    required int increment,
  }) async {
    final existing =
        await (_db.select(_db.dailyStats)..where(
              (s) => s.dayStart.equals(dayStart) & s.trackUri.equals(trackUri),
            ))
            .getSingleOrNull();

    if (existing == null) {
      await _db
          .into(_db.dailyStats)
          .insert(
            DailyStatsCompanion.insert(
              dayStart: dayStart,
              trackUri: trackUri,
              playCount: Value(increment),
              totalMs: Value(listenedMs),
            ),
          );
      return;
    }

    await (_db.update(_db.dailyStats)..where(
          (s) => s.dayStart.equals(dayStart) & s.trackUri.equals(trackUri),
        ))
        .write(
          DailyStatsCompanion(
            playCount: Value(existing.playCount + increment),
            totalMs: Value(existing.totalMs + listenedMs),
          ),
        );
  }

  @override
  Future<List<PlaybackEvent>> recent({int limit = 50}) async {
    final rows = await _recentQuery(limit).get();
    return rows.map(_toEvent).toList(growable: false);
  }

  @override
  Stream<List<PlaybackEvent>> watchRecent({int limit = 50}) {
    return _recentQuery(limit)
        .watch()
        .map((rows) => rows.map(_toEvent).toList(growable: false));
  }

  JoinedSelectStatement<HasResultSet, dynamic> _recentQuery(int limit) {
    return _db.select(_db.playEvents).join([
        innerJoin(
          _db.tracks,
          _db.tracks.uri.equalsExp(_db.playEvents.trackUri),
        ),
      ])
      ..orderBy([
        OrderingTerm.desc(_db.playEvents.startedAt),
        OrderingTerm.desc(_db.playEvents.id),
      ])
      ..limit(limit);
  }

  PlaybackEvent _toEvent(TypedResult row) {
    final event = row.readTable(_db.playEvents);
    final track = trackFromRow(row.readTable(_db.tracks));
    return PlaybackEvent(
      id: event.id,
      track: track,
      startedAt: DateTime.fromMillisecondsSinceEpoch(event.startedAt),
      listened: Duration(milliseconds: event.listenedMs),
      completed: event.completed,
      countsAsPlay:
          event.completed ||
          event.listenedMs >= PlaybackSession.playCountThreshold.inMilliseconds,
    );
  }

  @override
  Future<PlaybackStatsSummary> summary({
    PlaybackStatsPeriod period = PlaybackStatsPeriod.all,
  }) async {
    if (period == PlaybackStatsPeriod.all) {
      return _allTimeSummary(period);
    }
    return _periodSummary(period);
  }

  Future<PlaybackStatsSummary> _allTimeSummary(
    PlaybackStatsPeriod period,
  ) async {
    final rows =
        await (_db.select(_db.trackStats).join([
              innerJoin(
                _db.tracks,
                _db.tracks.uri.equalsExp(_db.trackStats.trackUri),
              ),
            ])..orderBy([
              OrderingTerm.desc(_db.trackStats.playCount),
              OrderingTerm.desc(_db.trackStats.lastPlayedAt),
            ]))
            .get();

    final stats = <TrackPlayStat>[];
    var totalPlayCount = 0;
    var totalListenMs = 0;
    for (final row in rows) {
      final stat = row.readTable(_db.trackStats);
      final track = trackFromRow(row.readTable(_db.tracks));
      totalPlayCount += stat.playCount;
      totalListenMs += stat.totalMs;
      stats.add(
        TrackPlayStat(
          track: track,
          playCount: stat.playCount,
          listenTime: Duration(milliseconds: stat.totalMs),
          lastPlayedAt: stat.lastPlayedAt == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(stat.lastPlayedAt!),
        ),
      );
    }

    return PlaybackStatsSummary(
      period: period,
      totalPlayCount: totalPlayCount,
      totalListenTime: Duration(milliseconds: totalListenMs),
      trackCount: stats.length,
      tracks: stats,
    );
  }

  Future<PlaybackStatsSummary> _periodSummary(
    PlaybackStatsPeriod period,
  ) async {
    final start = _periodStart(period, _clock());
    if (start == null) {
      return PlaybackStatsSummary.empty(period);
    }

    final rows =
        await (_db.select(_db.dailyStats)..where(
              (d) =>
                  d.dayStart.isBiggerOrEqualValue(start.millisecondsSinceEpoch),
            ))
            .get();

    final byUri = <String, _PeriodAccumulator>{};
    for (final row in rows) {
      final acc = byUri.putIfAbsent(row.trackUri, _PeriodAccumulator.new);
      acc.playCount += row.playCount;
      acc.listenMs += row.totalMs;
      if (row.dayStart > acc.lastPlayedAt) acc.lastPlayedAt = row.dayStart;
    }
    if (byUri.isEmpty) return PlaybackStatsSummary.empty(period);

    final tracks = await (_db.select(
      _db.tracks,
    )..where((t) => t.uri.isIn(byUri.keys))).get();
    final byTrack = {
      for (final track in tracks) track.uri: trackFromRow(track),
    };

    final stats = <TrackPlayStat>[];
    var totalPlayCount = 0;
    var totalListenMs = 0;
    for (final entry in byUri.entries) {
      final track = byTrack[entry.key];
      if (track == null) continue;
      final acc = entry.value;
      totalPlayCount += acc.playCount;
      totalListenMs += acc.listenMs;
      stats.add(
        TrackPlayStat(
          track: track,
          playCount: acc.playCount,
          listenTime: Duration(milliseconds: acc.listenMs),
          lastPlayedAt: acc.lastPlayedAt == 0
              ? null
              : DateTime.fromMillisecondsSinceEpoch(acc.lastPlayedAt),
        ),
      );
    }

    stats.sort((a, b) {
      final byCount = b.playCount.compareTo(a.playCount);
      if (byCount != 0) return byCount;
      final aAt = a.lastPlayedAt?.millisecondsSinceEpoch ?? 0;
      final bAt = b.lastPlayedAt?.millisecondsSinceEpoch ?? 0;
      return bAt.compareTo(aAt);
    });

    return PlaybackStatsSummary(
      period: period,
      totalPlayCount: totalPlayCount,
      totalListenTime: Duration(milliseconds: totalListenMs),
      trackCount: stats.length,
      tracks: stats,
    );
  }

  @override
  Future<void> clear() async {
    await _db.transaction(() async {
      await _db.delete(_db.playEvents).go();
      await _db.delete(_db.trackStats).go();
      await _db.delete(_db.dailyStats).go();
    });
  }

  DateTime _dayStart(DateTime time) =>
      DateTime(time.year, time.month, time.day);

  DateTime? _periodStart(PlaybackStatsPeriod period, DateTime now) {
    final today = _dayStart(now);
    return switch (period) {
      PlaybackStatsPeriod.day => today,
      PlaybackStatsPeriod.week => today.subtract(
        Duration(days: today.weekday - DateTime.monday),
      ),
      PlaybackStatsPeriod.month => DateTime(now.year, now.month),
      PlaybackStatsPeriod.year => DateTime(now.year),
      PlaybackStatsPeriod.all => null,
    };
  }
}

class _PeriodAccumulator {
  int playCount = 0;
  int listenMs = 0;
  int lastPlayedAt = 0;
}

/// Kept for callers that want a typed track without importing drift rows.
Track trackOf(TrackPlayStat stat) => stat.track;
