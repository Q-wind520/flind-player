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

import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/playback_queue.dart';
import 'package:flind_player/core/models/playback_state.dart';
import 'package:flind_player/core/models/repeat_mode.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/services/playback_controller.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/database/app_database.dart';
import 'package:flind_player/data/repositories/drift_music_library_repository.dart';
import 'package:flind_player/data/repositories/drift_playback_stats_repository.dart';
import 'package:flind_player/data/services/playback_stats_tracker.dart';

class _FakePlayback implements PlaybackController {
  final _controller = StreamController<PlaybackState>.broadcast(sync: true);
  PlaybackState _state = PlaybackState.idle;

  @override
  Stream<PlaybackState> get state => _controller.stream;

  @override
  PlaybackState get currentState => _state;

  @override
  PlaybackQueue get queue => PlaybackQueue.empty;

  void emit(PlaybackState state) {
    _state = state;
    _controller.add(state);
  }

  @override
  Future<void> playQueue(
    PlaybackQueue queue, {
    int index = 0,
    bool autoPlay = true,
  }) async {}

  @override
  Future<void> updateTrackCover(
    String uri, {
    String? coverPath,
    String? coverUrl,
  }) async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> togglePlayPause() async {}

  @override
  Future<void> next() async {}

  @override
  Future<void> previous() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setRepeatMode(RepeatMode mode) async {}

  @override
  Future<void> setShuffle(bool enabled) async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late _FakePlayback playback;
  late DriftPlaybackStatsRepository repository;
  late PlaybackStatsTracker tracker;
  late DateTime now;

  final a = Track(
    source: 'local',
    sourceTrackId: const LocalTrackId('/music/a.flac'),
    uri: 'local:/music/a.flac',
    title: 'A',
    duration: const Duration(minutes: 3),
  );
  final b = Track(
    source: 'local',
    sourceTrackId: const LocalTrackId('/music/b.flac'),
    uri: 'local:/music/b.flac',
    title: 'B',
    duration: const Duration(minutes: 3),
  );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    playback = _FakePlayback();
    repository = DriftPlaybackStatsRepository(db, clock: () => now);
    now = DateTime(2026, 11, 4, 12);
    final library = DriftMusicLibraryRepository(db);
    await library.upsertTrack(a);
    await library.upsertTrack(b);

    tracker = PlaybackStatsTracker(
      playback: playback,
      repository: repository,
      // Most tests use large synthetic gaps; the production 2s cap is covered
      // by its own test below.
      tickCap: const Duration(minutes: 5),
      clock: () => now,
    );
  });

  tearDown(() async {
    await tracker.dispose();
    await playback.dispose();
    await db.close();
  });

  PlaybackState state(
    Track track, {
    bool playing = true,
    Duration position = Duration.zero,
    bool completed = false,
  }) {
    return PlaybackState(
      isPlaying: playing,
      isBuffering: false,
      isCompleted: completed,
      position: position,
      duration: track.duration,
      currentTrack: track,
    );
  }

  Future<void> advance(Duration duration) async {
    now = now.add(duration);
    await Future<void>.delayed(Duration.zero);
  }

  test('counts a play after 30s of real playing time', () async {
    tracker.start();
    playback.emit(state(a));
    await advance(const Duration(seconds: 10));
    playback.emit(state(a, position: const Duration(seconds: 10)));
    await advance(const Duration(seconds: 21));
    playback.emit(state(a, position: const Duration(seconds: 31)));
    await tracker.dispose();

    final summary = await repository.summary();
    expect(summary.totalPlayCount, 1);
    expect(summary.totalListenTime, const Duration(seconds: 31));
  });

  test('paused time is not counted', () async {
    tracker.start();
    playback.emit(state(a));
    await advance(const Duration(seconds: 10));
    playback.emit(state(a, position: const Duration(seconds: 10)));
    playback.emit(
      state(a, playing: false, position: const Duration(seconds: 10)),
    );
    await advance(const Duration(minutes: 5));
    playback.emit(state(a, position: const Duration(seconds: 10)));
    await advance(const Duration(seconds: 10));
    playback.emit(state(a, position: const Duration(seconds: 20)));
    await tracker.dispose();

    final summary = await repository.summary();
    expect(summary.totalListenTime, const Duration(seconds: 20));
  });

  test('switching tracks flushes the previous session', () async {
    tracker.start();
    playback.emit(state(a));
    await advance(const Duration(seconds: 31));
    playback.emit(state(a, position: const Duration(seconds: 31)));
    playback.emit(state(b));
    await advance(const Duration(seconds: 31));
    playback.emit(state(b, position: const Duration(seconds: 31)));
    await tracker.dispose();

    final recent = await repository.recent();
    expect(recent.map((e) => e.track.title), ['B', 'A']);
    expect((await repository.summary()).totalPlayCount, 2);
  });

  test('a completed track counts immediately', () async {
    tracker.start();
    playback.emit(state(a));
    await advance(const Duration(seconds: 5));
    playback.emit(
      state(a, position: const Duration(seconds: 5), completed: true),
    );
    await tracker.dispose();

    final summary = await repository.summary();
    expect(summary.totalPlayCount, 1);
    expect((await repository.recent()).single.completed, isTrue);
  });

  test('a long event-loop gap is capped instead of inflating time', () async {
    final capped = PlaybackStatsTracker(
      playback: playback,
      repository: repository,
      // A 5s cap stays above the recording threshold, so the assertion can
      // observe the capped value instead of a dropped session.
      tickCap: const Duration(seconds: 5),
      clock: () => now,
    );
    capped.start();
    playback.emit(state(a));
    await advance(const Duration(seconds: 60));
    playback.emit(state(a, position: const Duration(seconds: 60)));
    await capped.dispose();

    final summary = await repository.summary();
    expect(summary.totalListenTime, const Duration(seconds: 5));
    expect(summary.totalPlayCount, 0);
  });

  test('short sessions are dropped', () async {
    tracker.start();
    playback.emit(state(a));
    await advance(const Duration(seconds: 2));
    playback.emit(state(a, position: const Duration(seconds: 2)));
    await tracker.dispose();

    expect(await repository.recent(), isEmpty);
  });
}
