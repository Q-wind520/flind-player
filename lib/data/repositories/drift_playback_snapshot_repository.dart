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

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'package:flind_player/core/models/playback_queue.dart';
import 'package:flind_player/core/models/repeat_mode.dart';
import 'package:flind_player/core/repositories/playback_snapshot_repository.dart';
import 'package:flind_player/data/codec/track_codec.dart';
import 'package:flind_player/data/database/app_database.dart';

/// Drift-backed [PlaybackSnapshotRepository].
///
/// The snapshot lives in a single row whose id is pinned to [singletonId];
/// [save] upserts that row so repeated writes never grow the table.
class DriftPlaybackSnapshotRepository implements PlaybackSnapshotRepository {
  DriftPlaybackSnapshotRepository(this._db);

  /// Fixed primary key of the one and only snapshot row.
  static const int singletonId = 1;

  final AppDatabase _db;

  @override
  Future<PlaybackSnapshot?> load() async {
    final row = await (_db.select(
      _db.playbackStates,
    )..where((t) => t.id.equals(singletonId))).getSingleOrNull();
    if (row == null) return null;

    try {
      return _decode(row);
    } on FormatException catch (error) {
      // A corrupt row must not crash startup; treat it as "nothing saved".
      debugPrint('DriftPlaybackSnapshotRepository: corrupt snapshot: $error');
      return null;
    }
  }

  @override
  Future<void> save(PlaybackSnapshot snapshot) async {
    final companion = PlaybackStatesCompanion(
      id: const Value(singletonId),
      queueJson: Value(_encodeQueue(snapshot.queue)),
      currentIndex: Value(snapshot.queue.currentIndex),
      positionMs: Value(snapshot.position.inMilliseconds),
      repeatMode: Value(snapshot.repeatMode.name),
      shuffleEnabled: Value(snapshot.shuffleEnabled),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    );

    await _db
        .into(_db.playbackStates)
        .insert(
          companion,
          onConflict: DoUpdate(
            (_) => companion,
            target: [_db.playbackStates.id],
          ),
        );
  }

  @override
  Future<void> clear() async {
    await _db.delete(_db.playbackStates).go();
  }

  /// Serialises the queue, including `originalOrder` (not derivable from the
  /// shuffled track order alone).
  String _encodeQueue(PlaybackQueue queue) {
    return jsonEncode(<String, dynamic>{
      'tracks': encodeTracks(queue.tracks),
      'originalOrder': queue.originalOrder,
    });
  }

  PlaybackSnapshot _decode(PlaybackStateRow row) {
    final decoded = jsonDecode(row.queueJson);
    if (decoded is! Map) {
      throw FormatException('queueJson must be a JSON object, got: $decoded');
    }

    final tracks = decoded['tracks'];
    final originalOrder = decoded['originalOrder'];
    if (tracks is! List || originalOrder is! List) {
      throw const FormatException(
        'queueJson must contain a tracks list and an originalOrder list',
      );
    }

    final queue = PlaybackQueue(
      tracks: decodeTracks(tracks),
      currentIndex: row.currentIndex,
      originalOrder: originalOrder.map(_asInt).toList(growable: false),
    );

    return PlaybackSnapshot(
      queue: queue,
      position: Duration(milliseconds: row.positionMs),
      repeatMode: _repeatModeFromName(row.repeatMode),
      shuffleEnabled: row.shuffleEnabled,
    );
  }

  RepeatMode _repeatModeFromName(String name) {
    for (final mode in RepeatMode.values) {
      if (mode.name == name) return mode;
    }
    // Unknown mode from a future schema: keep playing with repeat off rather
    // than discarding the whole snapshot.
    return RepeatMode.off;
  }

  int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    throw FormatException('originalOrder entries must be integers: $value');
  }
}
