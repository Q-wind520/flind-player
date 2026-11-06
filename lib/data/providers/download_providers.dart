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

import 'package:flind_player/core/models/download_task.dart';
import 'package:flind_player/core/repositories/download_repository.dart';
import 'package:flind_player/data/providers/cache_providers.dart';
import 'package:flind_player/data/providers/database_providers.dart';
import 'package:flind_player/data/repositories/drift_download_repository.dart';
import 'package:flind_player/data/services/download_center_service.dart';

/// Persisted download-centre tasks.
final downloadRepositoryProvider = Provider<DownloadRepository>(
  (ref) => DriftDownloadRepository(ref.watch(appDatabaseProvider)),
);

/// Persists download progress and resumes interrupted tasks.
///
/// Startup drives it via `start()` after the cache has been reconciled (see
/// `main.dart`).
final downloadCenterServiceProvider = Provider<DownloadCenterService>((ref) {
  final service = DownloadCenterService(
    manager: ref.watch(downloadManagerProvider),
    repository: ref.watch(downloadRepositoryProvider),
    cache: ref.watch(audioCacheStoreProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Reactive view of the download centre.
final downloadTasksProvider = StreamProvider<List<DownloadTask>>(
  (ref) => ref.watch(downloadRepositoryProvider).watchTasks(),
);
