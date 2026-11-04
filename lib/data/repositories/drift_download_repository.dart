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

import 'package:flind_player/core/models/download_task.dart';
import 'package:flind_player/core/repositories/download_repository.dart';
import 'package:flind_player/data/database/app_database.dart';
import 'package:flind_player/data/database/ids.dart';
import 'package:flind_player/data/repositories/track_row_mapping.dart';

/// Drift-backed [DownloadRepository].
class DriftDownloadRepository implements DownloadRepository {
  DriftDownloadRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  @override
  Stream<List<DownloadTask>> watchTasks() {
    return _taskQuery().watch().map(
      (rows) => rows.map(_toTask).toList(growable: false),
    );
  }

  @override
  Future<List<DownloadTask>> pending() async {
    final rows =
        await (_db.select(_db.downloads).join([
              leftOuterJoin(
                _db.tracks,
                _db.tracks.uri.equalsExp(_db.downloads.trackUri),
              ),
            ])..where(
              _db.downloads.status.isIn([
                DownloadStatus.queued.name,
                DownloadStatus.downloading.name,
                DownloadStatus.paused.name,
              ]),
            ))
            .get();
    return rows.map(_toTask).toList(growable: false);
  }

  @override
  Future<void> record(DownloadTaskUpdate update) async {
    final now = _clock();
    final completedAt =
        update.completedAt ??
        (update.status == DownloadStatus.done ? now : null);

    await _db.transaction(() async {
      final existing =
          await (_db.select(_db.downloads)
                ..where((d) => d.trackUri.equals(update.trackUri))
                ..orderBy([(d) => OrderingTerm.desc(d.id)])
                ..limit(1))
              .getSingleOrNull();

      if (existing == null) {
        await _db
            .into(_db.downloads)
            .insert(
              DownloadsCompanion.insert(
                publicId: newPublicId(),
                trackUri: update.trackUri,
                status: update.status.name,
                qualityId: Value(update.qualityId),
                filePath: Value(update.filePath),
                bytesDone: Value(update.bytesDone),
                bytesTotal: Value(update.bytesTotal),
                error: Value(update.error),
                createdAt: now.millisecondsSinceEpoch,
                updatedAt: now.millisecondsSinceEpoch,
                completedAt: Value(completedAt?.millisecondsSinceEpoch),
              ),
            );
        return;
      }

      await (_db.update(
        _db.downloads,
      )..where((d) => d.id.equals(existing.id))).write(
        DownloadsCompanion(
          status: Value(update.status.name),
          qualityId: Value(update.qualityId ?? existing.qualityId),
          filePath: Value(update.filePath ?? existing.filePath),
          bytesDone: Value(update.bytesDone),
          bytesTotal: Value(update.bytesTotal ?? existing.bytesTotal),
          error: Value(update.error),
          updatedAt: Value(now.millisecondsSinceEpoch),
          completedAt: Value(
            completedAt?.millisecondsSinceEpoch ?? existing.completedAt,
          ),
        ),
      );
    });
  }

  @override
  Future<void> remove(int id) async {
    await (_db.delete(_db.downloads)..where((d) => d.id.equals(id))).go();
  }

  @override
  Future<void> clearFinished() async {
    await (_db.delete(_db.downloads)..where(
          (d) => d.status.isIn([
            DownloadStatus.done.name,
            DownloadStatus.canceled.name,
          ]),
        ))
        .go();
  }

  @override
  Future<void> markInterrupted() async {
    await (_db.update(
      _db.downloads,
    )..where((d) => d.status.equals(DownloadStatus.downloading.name))).write(
      DownloadsCompanion(
        status: Value(DownloadStatus.queued.name),
        error: const Value(null),
        updatedAt: Value(_clock().millisecondsSinceEpoch),
      ),
    );
  }

  JoinedSelectStatement<HasResultSet, dynamic> _taskQuery() {
    return _db.select(_db.downloads).join([
      leftOuterJoin(
        _db.tracks,
        _db.tracks.uri.equalsExp(_db.downloads.trackUri),
      ),
    ])..orderBy([
      OrderingTerm.desc(_db.downloads.createdAt),
      OrderingTerm.desc(_db.downloads.id),
    ]);
  }

  DownloadTask _toTask(TypedResult row) {
    final task = row.readTable(_db.downloads);
    final track = row.readTableOrNull(_db.tracks);
    return DownloadTask(
      id: task.id,
      publicId: task.publicId,
      trackUri: task.trackUri,
      track: track == null ? null : trackFromRow(track),
      status: _statusFromDb(task.status),
      qualityId: task.qualityId,
      filePath: task.filePath,
      bytesDone: task.bytesDone,
      bytesTotal: task.bytesTotal,
      error: task.error,
      createdAt: DateTime.fromMillisecondsSinceEpoch(task.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(task.updatedAt),
      completedAt: task.completedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(task.completedAt!),
    );
  }

  DownloadStatus _statusFromDb(String value) {
    return DownloadStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => DownloadStatus.failed,
    );
  }
}
