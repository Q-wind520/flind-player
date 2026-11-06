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

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/playback_session.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/database/app_database.dart';
import 'package:flind_player/data/repositories/drift_music_library_repository.dart';
import 'package:flind_player/data/repositories/drift_playback_stats_repository.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late DriftMusicLibraryRepository library;
  late DriftPlaybackStatsRepository stats;
  final now = DateTime(2026, 11, 4, 12);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    library = DriftMusicLibraryRepository(db);
    stats = DriftPlaybackStatsRepository(db, clock: () => now);
  });

  tearDown(() async {
    await db.close();
  });

  Track track(String path, {String? title}) => Track(
    source: 'local',
    sourceTrackId: LocalTrackId(path),
    uri: 'local:$path',
    title: title ?? path.split('/').last,
    artist: 'Artist',
  );

  Future<void> seed(Track value) => library.upsertTrack(value);

  PlaybackSession session(
    Track value, {
    Duration listened = const Duration(seconds: 31),
    bool completed = false,
    DateTime? startedAt,
  }) {
    final start = startedAt ?? now.subtract(listened);
    return PlaybackSession(
      trackUri: value.uri,
      startedAt: start,
      endedAt: start.add(listened),
      listened: listened,
      completed: completed,
      position: listened,
      duration: const Duration(minutes: 3),
    );
  }

  test('ignores sessions below the recording threshold', () async {
    final a = track('/music/a.flac');
    await seed(a);

    await stats.record(session(a, listened: const Duration(seconds: 4)));

    expect(await stats.recent(), isEmpty);
    final summary = await stats.summary();
    expect(summary.totalPlayCount, 0);
    expect(summary.totalListenTime, Duration.zero);
  });

  test('records listening time below 30s without counting a play', () async {
    final a = track('/music/a.flac');
    await seed(a);

    await stats.record(session(a, listened: const Duration(seconds: 10)));

    final recent = await stats.recent();
    expect(recent, hasLength(1));
    expect(recent.single.track.title, 'a.flac');
    expect(recent.single.listened, const Duration(seconds: 10));
    expect(recent.single.countsAsPlay, isFalse);

    final summary = await stats.summary();
    expect(summary.totalPlayCount, 0);
    expect(summary.totalListenTime, const Duration(seconds: 10));
    expect(summary.tracks.single.playCount, 0);
    expect(summary.tracks.single.listenTime, const Duration(seconds: 10));
  });

  test('counts a play after 30s and accumulates totals', () async {
    final a = track('/music/a.flac');
    await seed(a);

    await stats.record(session(a));
    await stats.record(session(a, listened: const Duration(seconds: 12)));

    final summary = await stats.summary();
    expect(summary.totalPlayCount, 1);
    expect(summary.totalListenTime, const Duration(seconds: 43));
    expect(summary.trackCount, 1);
    expect(summary.tracks.single.playCount, 1);
    expect(summary.tracks.single.listenTime, const Duration(seconds: 43));
  });

  test('a completed short session counts as a play', () async {
    final a = track('/music/a.flac');
    await seed(a);

    await stats.record(
      session(a, listened: const Duration(seconds: 8), completed: true),
    );

    final summary = await stats.summary();
    expect(summary.totalPlayCount, 1);
    expect(summary.tracks.single.playCount, 1);
  });

  test('recent is newest first and watch emits updates', () async {
    final a = track('/music/a.flac', title: 'A');
    final b = track('/music/b.flac', title: 'B');
    await seed(a);
    await seed(b);

    final emissions = <List<PlaybackEvent>>[];
    final sub = stats.watchRecent(limit: 10).listen(emissions.add);
    addTearDown(sub.cancel);

    await stats.record(session(a, listened: const Duration(seconds: 31)));
    await stats.record(
      session(
        b,
        listened: const Duration(seconds: 31),
        startedAt: now.add(const Duration(minutes: 1)),
      ),
    );

    final recent = await stats.recent();
    expect(recent.map((e) => e.track.title), ['B', 'A']);
    expect(emissions, isNotEmpty);
    expect(emissions.last.map((e) => e.track.title), ['B', 'A']);
  });

  test('summary periods restrict rows to the current day/week/month', () async {
    final old = track('/music/old.flac', title: 'Old');
    final today = track('/music/today.flac', title: 'Today');
    await seed(old);
    await seed(today);

    await stats.record(
      session(
        old,
        listened: const Duration(seconds: 31),
        startedAt: now.subtract(const Duration(days: 40)),
      ),
    );
    await stats.record(session(today));

    final day = await stats.summary(period: PlaybackStatsPeriod.day);
    expect(day.tracks.map((t) => t.track.title), ['Today']);
    expect(day.totalPlayCount, 1);

    final all = await stats.summary();
    expect(all.tracks.map((t) => t.track.title).toSet(), {'Old', 'Today'});
    expect(all.totalPlayCount, 2);
  });

  test('clear removes events and aggregates', () async {
    final a = track('/music/a.flac');
    await seed(a);
    await stats.record(session(a));

    await stats.clear();

    expect(await stats.recent(), isEmpty);
    final summary = await stats.summary();
    expect(summary.totalPlayCount, 0);
    expect(summary.totalListenTime, Duration.zero);
  });
}
