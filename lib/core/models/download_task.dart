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

import 'package:flutter/foundation.dart';

import 'package:flind_player/core/models/track.dart';

/// Lifecycle of a user-visible download task.
enum DownloadStatus { queued, downloading, paused, done, failed, canceled }

/// A persisted download task plus its current pool metadata.
@immutable
class DownloadTask {
  const DownloadTask({
    required this.id,
    required this.publicId,
    required this.trackUri,
    required this.status,
    required this.bytesDone,
    required this.createdAt,
    required this.updatedAt,
    this.track,
    this.qualityId,
    this.filePath,
    this.bytesTotal,
    this.error,
    this.completedAt,
  });

  final int id;
  final String publicId;
  final String trackUri;

  /// Pool metadata, or `null` when the track has been removed from the pool.
  final Track? track;

  final DownloadStatus status;
  final String? qualityId;
  final String? filePath;
  final int bytesDone;
  final int? bytesTotal;
  final String? error;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  bool get isActive =>
      status == DownloadStatus.queued ||
      status == DownloadStatus.downloading ||
      status == DownloadStatus.paused;

  bool get isDone => status == DownloadStatus.done;

  double? get progress {
    final total = bytesTotal;
    if (total == null || total <= 0) return null;
    return (bytesDone / total).clamp(0.0, 1.0);
  }
}

/// A progress update produced by the download manager.
@immutable
class DownloadTaskUpdate {
  const DownloadTaskUpdate({
    required this.trackUri,
    required this.status,
    this.qualityId,
    this.filePath,
    this.bytesDone = 0,
    this.bytesTotal,
    this.error,
    this.completedAt,
  });

  final String trackUri;
  final DownloadStatus status;
  final String? qualityId;
  final String? filePath;
  final int bytesDone;
  final int? bytesTotal;
  final String? error;
  final DateTime? completedAt;
}
