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

  /// Remote cover URL (e.g. a Bilibili `pic` link), or `null` (schema v7).
  ///
  /// Persisted so a cover can be re-resolved from the cache index — or fetched
  /// again after LRU eviction — without another `view` API round-trip.
  TextColumn get coverUrl => text().nullable()();
  IntColumn get lastSeenAt => integer().nullable()();

  /// Size of the source file in bytes at the last scan (schema v5).
  ///
  /// Together with [mtimeMs] this is the `(mtime, size)` freshness key that
  /// lets a rescan skip files whose content has not changed
  /// (docs/local-library.md §2.4, §6). `null` for online tracks and for rows
  /// written before the fingerprint columns existed.
  IntColumn get sizeBytes => integer().nullable()();

  /// Last-modified time of the source file, in milliseconds since epoch
  /// (schema v5). See [sizeBytes].
  IntColumn get mtimeMs => integer().nullable()();

  /// Scan root this track was discovered under, or `null` for individually
  /// imported files and pre-v5 rows (schema v5).
  ///
  /// Scopes soft-deletes: a root that is temporarily offline (e.g. an
  /// unplugged drive) must not lose its tracks
  /// (docs/local-library.md §2.4 rule 3).
  TextColumn get scanRoot => text().nullable()();

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

/// Song asset rows (schema v10): one cached song's audio file plus its
/// companion cover.
///
/// `pinned` marks a manual/offline download, exempt from all quotas. The row is
/// the eviction unit: audio and companion cover are removed together.
@DataClassName('AudioCacheRow')
@TableIndex.sql(
  'CREATE INDEX IF NOT EXISTS idx_audio_cache_lru '
  'ON audio_cache (pinned, last_accessed_at)',
)
@TableIndex.sql(
  'CREATE INDEX IF NOT EXISTS idx_audio_cache_content_hash '
  'ON audio_cache (content_hash)',
)
@TableIndex.sql(
  'CREATE INDEX IF NOT EXISTS idx_audio_cache_file_path '
  'ON audio_cache (file_path)',
)
class AudioCache extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Source identifier, e.g. `bilibili`.
  TextColumn get source => text()();

  /// Source-specific identity, e.g. `BV...:cid`.
  TextColumn get sourceTrackId => text()();

  /// Absolute path of the cached file.
  TextColumn get filePath => text()();

  /// Size of the cached file, in bytes.
  IntColumn get bytes => integer()();

  /// Stream quality the file was downloaded at, e.g. `30280`.
  TextColumn get qualityId => text()();

  /// Manual downloads are pinned and excluded from LRU eviction.
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();

  /// Unix timestamp when the file entered the cache.
  IntColumn get cachedAt => integer()();

  /// Unix timestamp of the last read; the LRU ordering key.
  IntColumn get lastAccessedAt => integer()();

  /// SHA-1 hex digest of the cached file's bytes (schema v6).
  ///
  /// Identical content written under two logical keys shares one physical
  /// file; this column is how those rows are grouped. `null` for legacy rows
  /// written before v6 and for rows whose file could not be hashed.
  TextColumn get contentHash => text().nullable()();

  /// Absolute path of the song's companion cover, or `null` when none.
  TextColumn get coverPath => text().nullable()();

  /// Bytes of the companion cover, counted in the layer-1 quota.
  IntColumn get coverBytes => integer().withDefault(const Constant(0))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {source, sourceTrackId},
  ];
}

/// Single-row snapshot of the playback session (schema v4).
///
/// The row id is pinned to `1`: there is exactly one live snapshot at a time,
/// and the snapshot repository upserts that row. `queueJson` holds the
/// serialised queue (tracks plus the pre-shuffle `originalOrder`).
@DataClassName('PlaybackStateRow')
class PlaybackStates extends Table {
  @override
  String get tableName => 'playback_state';

  IntColumn get id => integer()();

  /// Serialised playback queue (tracks + originalOrder), see the codec.
  TextColumn get queueJson => text()();

  /// Index of the current track within the serialised queue.
  IntColumn get currentIndex => integer()();

  /// Playback position, in milliseconds.
  IntColumn get positionMs => integer()();

  /// Persisted repeat mode name (`off` / `all` / `one`).
  TextColumn get repeatMode => text()();

  BoolColumn get shuffleEnabled => boolean()();

  /// Unix timestamp of the last write.
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Playlists: the built-in favourites playlist (`kind='favorites'`, id pinned
/// to 1) plus user-created playlists (`kind='custom'`). The "all" pool is the
/// `tracks` table itself and is not represented here.
@DataClassName('PlaylistRow')
class Playlists extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Display name; required and non-blank.
  TextColumn get name => text()();

  /// `favorites` (built-in, id 1) or `custom` (user-created).
  TextColumn get kind => text()();

  TextColumn get description => text().nullable()();

  /// Explicit cover (overrides the derived fallback chain).
  TextColumn get coverPath => text().nullable()();

  /// Remote cover URL, mirroring [Tracks.coverUrl].
  TextColumn get coverUrl => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
}

/// Playlist members: one row per (playlist, track).
///
/// `uri` is a pure reference into the `tracks` pool (schema v9); a member
/// carries no metadata of its own and resolves entirely through the pool.
@DataClassName('PlaylistTrackRow')
@TableIndex.sql(
  'CREATE INDEX IF NOT EXISTS idx_playlist_tracks_order '
  'ON playlist_tracks (playlist_id, added_at DESC, id DESC)',
)
class PlaylistTracks extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Owning playlist row id.
  IntColumn get playlistId => integer()();

  /// Canonical pool key (`local:<path>` / `bilibili:<bvid>:<cid>`).
  TextColumn get uri => text()();

  /// Unix timestamp when the member was added; the ordering key
  /// (= the old favourites `favorited_at`).
  IntColumn get addedAt => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {playlistId, uri}, // the same song can be in several playlists
  ];
}

/// Remote cover cache index (schema v7).
///
/// One row per cached remote cover. `url_hash` is `sha1(normalized url)` and is
/// the lookup key; the file on disk is named after `content_hash`, so identical
/// images fetched under different URLs share a single physical file. Cover
/// bytes form layer 2 of the cache: they count against the fixed 256 MiB
/// layer-2 cap, never against the user's audio quota, and audio is never
/// evicted on a cover's behalf.
@DataClassName('CoverCacheRow')
@TableIndex.sql(
  'CREATE INDEX IF NOT EXISTS idx_cover_cache_lru '
  'ON cover_cache (last_accessed_at)',
)
@TableIndex.sql(
  'CREATE INDEX IF NOT EXISTS idx_cover_cache_content_hash '
  'ON cover_cache (content_hash)',
)
@TableIndex.sql(
  'CREATE INDEX IF NOT EXISTS idx_cover_cache_file_path '
  'ON cover_cache (file_path)',
)
class CoverCache extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// `sha1(normalized cover URL)`; the lookup key.
  TextColumn get urlHash => text().unique()();

  /// Absolute path of the cached file.
  TextColumn get filePath => text()();

  /// `sha1` hex digest of the stored bytes; also the on-disk file name.
  TextColumn get contentHash => text()();

  /// Size of the cached file, in bytes.
  IntColumn get bytes => integer()();

  /// Unix timestamp when the file entered the cache.
  IntColumn get cachedAt => integer()();

  /// Unix timestamp of the last read; the LRU ordering key.
  IntColumn get lastAccessedAt => integer()();
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
