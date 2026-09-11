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

  /// Unix timestamp when the track disappeared from its source, or `null`
  /// while it is present.
  ///
  /// Soft delete: a transiently unplugged drive or a failed scan must not
  /// destroy rows that future playlists/stats still reference.
  IntColumn get missingAt => integer().nullable()();
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

/// Raw SQL for the FTS5 index over `tracks`.
///
/// This is not a drift table: drift has no FTS5 table type, so the virtual
/// table and its synchronisation triggers are created and kept in sync with
/// explicit statements from the migration. It uses the standard
/// external-content pattern (`content='tracks'`), where the index stores no
/// copy of the data and reads the original columns by `rowid`.
abstract final class TracksFts {
  /// Creates the external-content index over title/artist/album.
  static const String createTable = '''
CREATE VIRTUAL TABLE IF NOT EXISTS tracks_fts USING fts5(
  title, artist, album, content='tracks', content_rowid='id'
);
''';

  /// Mirrors a freshly inserted row into the index.
  static const String createInsertTrigger = '''
CREATE TRIGGER IF NOT EXISTS tracks_fts_ai AFTER INSERT ON tracks BEGIN
  INSERT INTO tracks_fts(rowid, title, artist, album)
  VALUES (new.id, new.title, new.artist, new.album);
END;
''';

  /// Removes a deleted row from the index via FTS5's `'delete'` command.
  static const String createDeleteTrigger = '''
CREATE TRIGGER IF NOT EXISTS tracks_fts_ad AFTER DELETE ON tracks BEGIN
  INSERT INTO tracks_fts(tracks_fts, rowid, title, artist, album)
  VALUES ('delete', old.id, old.title, old.artist, old.album);
END;
''';

  /// Re-indexes an updated row: delete the old entry, insert the new one.
  static const String createUpdateTrigger = '''
CREATE TRIGGER IF NOT EXISTS tracks_fts_au AFTER UPDATE ON tracks BEGIN
  INSERT INTO tracks_fts(tracks_fts, rowid, title, artist, album)
  VALUES ('delete', old.id, old.title, old.artist, old.album);
  INSERT INTO tracks_fts(rowid, title, artist, album)
  VALUES (new.id, new.title, new.artist, new.album);
END;
''';

  /// Rebuilds the whole index from the `tracks` content table.
  static const String rebuild =
      "INSERT INTO tracks_fts(tracks_fts) VALUES('rebuild');";

  /// All DDL statements needed to install the index, in execution order.
  static const List<String> createStatements = [
    createTable,
    createInsertTrigger,
    createDeleteTrigger,
    createUpdateTrigger,
  ];
}
