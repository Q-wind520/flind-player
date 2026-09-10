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

/// Unified music library rows (local + online sources).
///
/// Schema mirrors `docs/local-library.md` §5, M0 subset. The FTS5 virtual
/// table is deliberately omitted here and lands in M2.
@DataClassName('TrackRow')
class Tracks extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Source identifier, e.g. `local` or `bilibili`.
  TextColumn get source => text()();

  /// Source-specific identity (absolute path, or `bvid:cid`).
  TextColumn get sourceTrackId => text()();

  /// Canonical source-namespaced key; the upsert conflict target.
  TextColumn get uri => text().unique()();

  TextColumn get title => text()();
  TextColumn get artist => text().nullable()();
  TextColumn get album => text().nullable()();
  TextColumn get albumArtist => text().nullable()();
  IntColumn get trackNo => integer().nullable()();
  IntColumn get discNo => integer().nullable()();
  IntColumn get year => integer().nullable()();
  IntColumn get durationMs => integer().nullable()();
  IntColumn get bitrate => integer().nullable()();
  IntColumn get sampleRate => integer().nullable()();
  TextColumn get genre => text().nullable()();
  TextColumn get coverPath => text().nullable()();
  IntColumn get lastSeenAt => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
}

/// Configured scan roots persisted across launches.
@DataClassName('ScanRootRow')
class ScanRoots extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get path => text().unique()();

  /// Root kind, currently only `local`.
  TextColumn get kind => text()();
  IntColumn get addedAt => integer()();
}

/// Small key/value store for incremental scan bookkeeping.
@DataClassName('ScanStateRow')
class ScanState extends Table {
  TextColumn get key => text()();
  TextColumn get value => text().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}
