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
@DriftDatabase(tables: [Tracks, ScanRoots, ScanState])
class AppDatabase extends _$AppDatabase {
  /// Opens the platform database, or uses [executor] when one is injected
  /// (unit tests pass `NativeDatabase.memory()`).
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: (m) => m.createAll());
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'flind_player');
}
