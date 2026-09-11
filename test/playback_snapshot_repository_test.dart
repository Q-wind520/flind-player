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

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/playback_queue.dart';
import 'package:flind_player/core/models/repeat_mode.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/repositories/playback_snapshot_repository.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/database/app_database.dart';
import 'package:flind_player/data/repositories/drift_playback_snapshot_repository.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late DriftPlaybackSnapshotRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = DriftPlaybackSnapshotRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Track track(String path) => Track(
    source: 'local',
    sourceTrackId: LocalTrackId(path),
    uri: 'local:$path',
    title: path,
  );

  test('load() returns null when nothing was saved', () async {
    expect(await repository.load(), isNull);
  });

  test('save/load round-trips queue order, index, position, repeat and '
      'shuffle', () async {
    final queue = PlaybackQueue(
      tracks: [track('/m/a.flac'), track('/m/b.flac'), track('/m/c.flac')],
      currentIndex: 1,
      // Non-identity order: proves originalOrder is persisted, not rebuilt.
      originalOrder: const [2, 0, 1],
    );
    final snapshot = PlaybackSnapshot(
      queue: queue,
      position: const Duration(milliseconds: 12345),
      repeatMode: RepeatMode.all,
      shuffleEnabled: true,
    );

    await repository.save(snapshot);
    final loaded = await repository.load();

    expect(loaded, isNotNull);
    expect(loaded, snapshot);
    expect(loaded!.queue.tracks.map((t) => t.uri), [
      'local:/m/a.flac',
      'local:/m/b.flac',
      'local:/m/c.flac',
    ]);
    expect(loaded.queue.currentIndex, 1);
    expect(loaded.queue.originalOrder, const [2, 0, 1]);
    expect(loaded.position, const Duration(milliseconds: 12345));
    expect(loaded.repeatMode, RepeatMode.all);
    expect(loaded.shuffleEnabled, isTrue);
  });

  test('save upserts the singleton row instead of appending', () async {
    final first = PlaybackSnapshot(
      queue: PlaybackQueue(
        tracks: [track('/m/a.flac')],
        currentIndex: 0,
        originalOrder: const [0],
      ),
      position: const Duration(seconds: 1),
      repeatMode: RepeatMode.off,
      shuffleEnabled: false,
    );
    final second = PlaybackSnapshot(
      queue: PlaybackQueue(
        tracks: [track('/m/b.flac'), track('/m/c.flac')],
        currentIndex: 1,
        originalOrder: const [1, 0],
      ),
      position: const Duration(seconds: 2),
      repeatMode: RepeatMode.one,
      shuffleEnabled: true,
    );

    await repository.save(first);
    await repository.save(second);

    final rows = await db.select(db.playbackStates).get();
    expect(rows, hasLength(1));
    expect(rows.single.id, DriftPlaybackSnapshotRepository.singletonId);
    expect(await repository.load(), second);
  });

  test('clear() removes the snapshot', () async {
    await repository.save(
      PlaybackSnapshot(
        queue: PlaybackQueue(
          tracks: [track('/m/a.flac')],
          currentIndex: 0,
          originalOrder: const [0],
        ),
        position: const Duration(seconds: 5),
        repeatMode: RepeatMode.off,
        shuffleEnabled: false,
      ),
    );
    expect(await repository.load(), isNotNull);

    await repository.clear();

    expect(await repository.load(), isNull);
  });

  test('a corrupt row is treated as no snapshot', () async {
    await db
        .into(db.playbackStates)
        .insert(
          PlaybackStatesCompanion.insert(
            id: const Value(DriftPlaybackSnapshotRepository.singletonId),
            queueJson: 'not json',
            currentIndex: 0,
            positionMs: 0,
            repeatMode: 'off',
            shuffleEnabled: false,
            updatedAt: 0,
          ),
        );

    expect(await repository.load(), isNull);
  });
}
