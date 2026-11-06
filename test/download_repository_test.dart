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

import 'package:flind_player/core/models/download_task.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/database/app_database.dart';
import 'package:flind_player/data/repositories/drift_download_repository.dart';
import 'package:flind_player/data/repositories/drift_music_library_repository.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late DriftDownloadRepository repository;
  late DriftMusicLibraryRepository library;
  late DateTime now;

  final track = Track(
    source: 'local',
    sourceTrackId: const LocalTrackId('/music/a.flac'),
    uri: 'local:/music/a.flac',
    title: 'A',
  );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    now = DateTime(2026, 11, 4, 12);
    repository = DriftDownloadRepository(db, clock: () => now);
    library = DriftMusicLibraryRepository(db);
    await library.upsertTrack(track);
  });

  tearDown(() async {
    await db.close();
  });

  test('records a task and joins its track metadata', () async {
    await repository.record(
      const DownloadTaskUpdate(
        trackUri: 'local:/music/a.flac',
        status: DownloadStatus.queued,
        qualityId: '30280',
      ),
    );

    final tasks = await repository.watchTasks().first;
    expect(tasks, hasLength(1));
    expect(tasks.single.track?.title, 'A');
    expect(tasks.single.status, DownloadStatus.queued);
    expect(tasks.single.qualityId, '30280');
  });

  test('updates the same row instead of duplicating on progress', () async {
    await repository.record(
      const DownloadTaskUpdate(
        trackUri: 'local:/music/a.flac',
        status: DownloadStatus.queued,
      ),
    );
    final first = (await repository.watchTasks().first).single;

    now = now.add(const Duration(seconds: 1));
    await repository.record(
      const DownloadTaskUpdate(
        trackUri: 'local:/music/a.flac',
        status: DownloadStatus.downloading,
        bytesDone: 50,
        bytesTotal: 100,
      ),
    );

    final tasks = await repository.watchTasks().first;
    expect(tasks, hasLength(1));
    expect(tasks.single.id, first.id);
    expect(tasks.single.publicId, first.publicId);
    expect(tasks.single.status, DownloadStatus.downloading);
    expect(tasks.single.bytesDone, 50);
    expect(tasks.single.bytesTotal, 100);
    expect(tasks.single.progress, 0.5);
  });

  test('done records completion time and file path', () async {
    await repository.record(
      const DownloadTaskUpdate(
        trackUri: 'local:/music/a.flac',
        status: DownloadStatus.done,
        filePath: '/tmp/a.m4a',
        bytesDone: 100,
        bytesTotal: 100,
      ),
    );

    final task = (await repository.watchTasks().first).single;
    expect(task.status, DownloadStatus.done);
    expect(task.filePath, '/tmp/a.m4a');
    expect(task.completedAt, now);
  });

  test(
    'pending contains only active tasks and markInterrupted re-queues',
    () async {
      await repository.record(
        const DownloadTaskUpdate(
          trackUri: 'local:/music/a.flac',
          status: DownloadStatus.downloading,
          bytesDone: 10,
          bytesTotal: 100,
        ),
      );
      await repository.record(
        const DownloadTaskUpdate(
          trackUri: 'local:/missing.flac',
          status: DownloadStatus.failed,
        ),
      );

      expect(await repository.pending(), hasLength(1));

      await repository.markInterrupted();
      final tasks = await repository.watchTasks().first;
      final task = tasks.firstWhere((t) => t.trackUri == 'local:/music/a.flac');
      expect(task.status, DownloadStatus.queued);
      expect(task.error, isNull);
    },
  );

  test(
    'a task whose track left the pool still lists with null track',
    () async {
      await repository.record(
        const DownloadTaskUpdate(
          trackUri: 'local:/music/gone.flac',
          status: DownloadStatus.done,
        ),
      );

      final task = (await repository.watchTasks().first).single;
      expect(task.track, isNull);
      expect(task.trackUri, 'local:/music/gone.flac');
    },
  );

  test('remove and clearFinished delete the expected rows', () async {
    await repository.record(
      const DownloadTaskUpdate(
        trackUri: 'local:/music/a.flac',
        status: DownloadStatus.done,
      ),
    );
    await repository.record(
      const DownloadTaskUpdate(
        trackUri: 'local:/music/b.flac',
        status: DownloadStatus.failed,
      ),
    );

    await repository.clearFinished();
    var tasks = await repository.watchTasks().first;
    expect(tasks.map((t) => t.status), [DownloadStatus.failed]);

    await repository.remove(tasks.single.id);
    tasks = await repository.watchTasks().first;
    expect(tasks, isEmpty);
  });
}
