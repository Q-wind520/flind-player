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

import 'package:flind_player/core/models/download_task.dart';

/// Persistence for the download centre's task list.
///
/// The task table records user intent and task state; the audio cache remains
/// the source of truth for "is this file available offline". A completed task
/// normally has a pinned cache entry, but the two are intentionally separate.
abstract interface class DownloadRepository {
  /// All tasks, newest first.
  Stream<List<DownloadTask>> watchTasks();

  /// Tasks that still need work (queued/downloading/paused).
  Future<List<DownloadTask>> pending();

  /// Inserts or updates the task for [update.trackUri].
  Future<void> record(DownloadTaskUpdate update);

  /// Deletes one task row. The caller is responsible for removing the file.
  Future<void> remove(int id);

  /// Deletes completed and canceled tasks, keeping failed/active history.
  Future<void> clearFinished();

  /// Marks `downloading` rows as `queued` after a restart so they can resume.
  Future<void> markInterrupted();
}
