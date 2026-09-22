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

import 'package:flind_player/data/database/playlist_defaults.dart';
import 'package:flind_player/data/database/tables.dart';

part 'app_database.g.dart';

/// SQLite-backed application database.
@DriftDatabase(
  tables: [
    Tracks,
    ScanRoots,
    ScanState,
    AudioCache,
    CoverCache,
    PlaybackStates,
    Playlists,
    PlaylistTracks,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Opens the platform database, or uses [executor] when one is injected
  /// (unit tests pass `NativeDatabase.memory()`).
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _installFts();
      // A fresh database carries the built-in favourites playlist row too, so
      // the favourites adapter (pinned to id 1) works without an upgrade.
      await _seedFavoritesPlaylist();
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
      if (from < 4) {
        // v3 had no playback snapshot nor favourites. `createTable` emits
        // `CREATE TABLE IF NOT EXISTS`, so a fixture that already carries the
        // v4 tables upgrades cleanly. `Favorites` is no longer a drift table
        // (schema v8), so the legacy table is created with raw SQL matching
        // the exact v4 shape (no `cover_url`; that lands in v7).
        await m.createTable(playbackStates);
        await customStatement('''
CREATE TABLE IF NOT EXISTS favorites (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  uri TEXT NOT NULL UNIQUE,
  source TEXT NOT NULL,
  source_track_id TEXT NOT NULL,
  title TEXT NOT NULL,
  artist TEXT,
  album TEXT,
  duration_ms INTEGER,
  cover_path TEXT,
  favorited_at INTEGER NOT NULL
)
''');
      }
      if (from < 5) {
        // v4 had no file fingerprints nor root attribution. `addColumn` emits
        // a plain `ALTER TABLE ... ADD COLUMN`, which is *not* idempotent, so
        // guard each one: a fixture built from the current schema (see the
        // migration test) already carries these columns.
        await _addColumnIfMissing(m, tracks, tracks.sizeBytes);
        await _addColumnIfMissing(m, tracks, tracks.mtimeMs);
        await _addColumnIfMissing(m, tracks, tracks.scanRoot);
      }
      if (from < 6) {
        // v5 had no content hash, so identical audio under two logical keys
        // could not be deduplicated. Guarded for the same reason as above.
        await _addColumnIfMissing(m, audioCache, audioCache.contentHash);
      }
      if (from < 7) {
        // v6 had no remote cover URL nor a remote cover cache index. The new
        // columns are guarded like v5's; `createTable`/`createIndex` emit
        // `IF NOT EXISTS`, so a fixture already carrying them upgrades cleanly.
        await _addColumnIfMissing(m, tracks, tracks.coverUrl);
        await _addColumnIfMissingRaw('favorites', 'cover_url', 'TEXT');
        await m.createTable(coverCache);
        await m.createIndex(idxCoverCacheLru);
      }
      if (from < 8) {
        // v7 had no playlists: favourites were a standalone denormalised table
        // and there were no user playlists. The new tables/index are created
        // with `IF NOT EXISTS`, the favourites playlist is seeded with
        // `INSERT OR IGNORE`, and the legacy `favorites` rows are converted
        // into members (old `favorited_at` becomes `added_at`) only when the
        // old table actually exists. Every step is re-runnable.
        await m.createTable(playlists);
        await m.createTable(playlistTracks);
        await m.createIndex(idxPlaylistTracksOrder);
        await _addColumnIfMissing(m, tracks, tracks.contentHash);

        // 1) Seed the built-in favourites playlist (raw SQL: `Favorites` is no
        // longer in the table list, so there is no generated code for it).
        await _seedFavoritesPlaylist();

        // 2) Legacy favourites -> members (only when the old table exists; the
        // old `favorited_at` becomes `added_at`).
        final hasLegacyFavorites = await customSelect(
          "SELECT 1 FROM sqlite_master WHERE type='table' AND name='favorites'",
        ).getSingleOrNull() != null;
        if (hasLegacyFavorites) {
          await customStatement(
            'INSERT OR IGNORE INTO playlist_tracks '
            '(playlist_id, uri, source, source_track_id, title, artist, album, '
            ' duration_ms, cover_path, cover_url, added_at) '
            'SELECT 1, uri, source, source_track_id, title, artist, album, '
            '       duration_ms, cover_path, cover_url, favorited_at '
            'FROM favorites',
          );
          await customStatement('DROP TABLE IF EXISTS favorites');
        }
      }
    },
  );

  /// Creates the FTS5 virtual table and its synchronisation triggers.
  Future<void> _installFts() async {
    for (final statement in TracksFts.createStatements) {
      await customStatement(statement);
    }
  }

  /// Inserts the built-in favourites playlist row (id pinned to 1) unless it
  /// already exists.
  ///
  /// Called from both `onCreate` (fresh databases) and the v7 -> v8 upgrade,
  /// so every database carries the row exactly once.
  Future<void> _seedFavoritesPlaylist() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await customStatement(
      'INSERT OR IGNORE INTO playlists (id, name, kind, created_at, updated_at) '
      "VALUES ($favoritesPlaylistId, '$favoritesPlaylistStoredName', "
      "'$playlistKindFavorites', $now, $now)",
    );
  }

  /// Adds [column] to [table] unless the physical table already has it.
  ///
  /// Used for the v4 -> v5 and v5 -> v6 upgrades so re-running a migration over
  /// a database that already carries the column is a no-op (drift's
  /// [Migrator.addColumn] would otherwise fail with "duplicate column name").
  Future<void> _addColumnIfMissing(
    Migrator m,
    TableInfo table,
    GeneratedColumn column,
  ) async {
    final rows = await customSelect(
      'PRAGMA table_info(${table.actualTableName})',
    ).get();
    if (rows.any((row) => row.data['name'] == column.name)) return;
    await m.addColumn(table, column);
  }

  /// Raw-SQL twin of [_addColumnIfMissing] for the legacy `favorites` table,
  /// whose drift class no longer exists after schema v8.
  ///
  /// Also a no-op when [table] itself is absent: an upgrade starting from v4 or
  /// v5 never ran the `from < 4` block that creates the legacy table, so it
  /// must not try to alter it.
  Future<void> _addColumnIfMissingRaw(
    String table,
    String column,
    String type,
  ) async {
    final tableExists = await customSelect(
      "SELECT 1 FROM sqlite_master WHERE type='table' AND name='$table'",
    ).getSingleOrNull() != null;
    if (!tableExists) return;
    final rows = await customSelect('PRAGMA table_info($table)').get();
    if (rows.any((row) => row.data['name'] == column)) return;
    await customStatement('ALTER TABLE $table ADD COLUMN $column $type');
  }
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'flind_player');
}
