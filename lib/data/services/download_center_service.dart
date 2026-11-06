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

import 'package:flutter/foundation.dart';

import 'package:flind_player/core/models/download_task.dart';
import 'package:flind_player/core/repositories/download_repository.dart';
import 'package:flind_player/data/cache/audio_cache_store.dart';
import 'package:flind_player/data/cache/download_manager.dart';

/// Bridges [DownloadManager]'s in-memory progress to the persisted download
/// centre, and resumes queued tasks after a restart.
class DownloadCenterService {
  DownloadCenterService({
    required DownloadManager manager,
    required DownloadRepository repository,
    required AudioCacheStore cache,
    DateTime Function() clock = DateTime.now,
  }) : _manager = manager, // ignore: prefer_initializing_formals
       _repository = repository, // ignore: prefer_initializing_formals
       _cache = cache, // ignore: prefer_initializing_formals
       _clock = clock; // ignore: prefer_initializing_formals

  final DownloadManager _manager;
  final DownloadRepository _repository;
  final AudioCacheStore _cache;
  final DateTime Function() _clock;

  StreamSubscription<DownloadProgress>? _subscription;
  bool _started = false;
  bool _disposed = false;

  /// Persists task state and requeues interrupted work. Idempotent.
  Future<void> start() async {
    if (_disposed || _started) return;
    _started = true;

    try {
      await _repository.markInterrupted();
    } catch (error, stackTrace) {
      debugPrint(
        'DownloadCenterService: markInterrupted failed: $error\n$stackTrace',
      );
    }

    _subscription = _manager.progress.listen(
      _onProgress,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint(
          'DownloadCenterService: progress error: $error\n$stackTrace',
        );
      },
    );

    await _resumePending();
  }

  Future<void> _resumePending() async {
    List<DownloadTask> tasks;
    try {
      tasks = await _repository.pending();
    } catch (error, stackTrace) {
      debugPrint(
        'DownloadCenterService: pending load failed: $error\n$stackTrace',
      );
      return;
    }

    for (final task in tasks) {
      if (_disposed) return;
      if (task.status == DownloadStatus.paused) continue;
      final track = task.track;
      if (track == null) {
        await _safeRecord(
          DownloadTaskUpdate(
            trackUri: task.trackUri,
            status: DownloadStatus.failed,
            error: 'track not found',
            bytesDone: task.bytesDone,
            bytesTotal: task.bytesTotal,
          ),
        );
        continue;
      }
      // cacheTrack emits queued immediately, so the persisted row flips back
      // to queued before progress starts.
      unawaited(_manager.cacheTrack(track, pinned: true));
    }
  }

  void _onProgress(DownloadProgress progress) {
    final status = switch (progress.phase) {
      DownloadPhase.queued => DownloadStatus.queued,
      DownloadPhase.downloading => DownloadStatus.downloading,
      DownloadPhase.done || DownloadPhase.skipped => DownloadStatus.done,
      DownloadPhase.failed => DownloadStatus.failed,
      DownloadPhase.canceled => DownloadStatus.canceled,
    };

    unawaited(
      _safeRecord(
        DownloadTaskUpdate(
          trackUri: progress.trackUri,
          status: status,
          qualityId: progress.qualityId,
          filePath: progress.filePath,
          bytesDone: progress.received,
          bytesTotal: progress.total > 0 ? progress.total : null,
          error: progress.error?.toString(),
          completedAt: status == DownloadStatus.done ? _clock() : null,
        ),
      ),
    );
  }

  Future<void> _safeRecord(DownloadTaskUpdate update) async {
    try {
      await _repository.record(update);
    } catch (error, stackTrace) {
      debugPrint('DownloadCenterService: record failed: $error\n$stackTrace');
    }
  }

  /// Cancels an active/queued task, or marks a stale task canceled.
  Future<void> cancel(DownloadTask task) async {
    if (_manager.cancel(task.trackUri)) return;
    await _safeRecord(
      DownloadTaskUpdate(
        trackUri: task.trackUri,
        status: DownloadStatus.canceled,
        bytesDone: task.bytesDone,
        bytesTotal: task.bytesTotal,
      ),
    );
  }

  /// Removes a task row and its cached file/cover. Safe when either is missing.
  Future<void> remove(DownloadTask task) async {
    final track = task.track;
    if (track != null) {
      try {
        final entry = await _cache.lookup(
          track.source,
          cacheSourceTrackId(track),
        );
        if (entry != null) await _cache.remove(entry.id);
      } catch (error, stackTrace) {
        debugPrint(
          'DownloadCenterService: cache remove failed: $error\n$stackTrace',
        );
      }
    }
    await _repository.remove(task.id);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _started = false;
    await _subscription?.cancel();
    _subscription = null;
  }
}
