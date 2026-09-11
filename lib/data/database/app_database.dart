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
import 'package:drift_flutter/drift_flutter.dart';

import 'package:flind_player/data/database/tables.dart';

part 'app_database.g.dart';

/// SQLite-backed application database.
@DriftDatabase(tables: [Tracks, ScanRoots, ScanState, AudioCache])
class AppDatabase extends _$AppDatabase {
  /// Opens the platform database, or uses [executor] when one is injected
  /// (unit tests pass `NativeDatabase.memory()`).
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _installFts();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // v1 had no `missing_at` column; add it before anything reads the
        // table through the new schema.
        await m.addColumn(tracks, tracks.missingAt);
        await _installFts();
        // Index rows that already exist in the upgraded database.
        await customStatement(TracksFts.rebuild);
      }
      if (from < 3) {
        // v2 had no offline audio cache. Both statements are idempotent, so a
        // database that already carries the table/index (e.g. a fixture built
        // from the current schema) upgrades cleanly.
        await m.createTable(audioCache);
        await m.createIndex(idxAudioCacheLru);
      }
    },
  );

  /// Creates the FTS5 virtual table and its synchronisation triggers.
  Future<void> _installFts() async {
    for (final statement in TracksFts.createStatements) {
      await customStatement(statement);
    }
  }
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'flind_player');
}
