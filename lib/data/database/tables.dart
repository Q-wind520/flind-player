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

  /// Unix timestamp when the user removed this track, or `null` while live
  /// (schema v11).
  ///
  /// Distinct from [missingAt]: a removed track is intentionally gone, while a
  /// missing track may return when its source comes back. Rows referenced by
  /// playlists/downloads/stats are kept as tombstones instead of hard-deleted.
  IntColumn get deletedAt => integer().nullable()();
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
@TableIndex.sql(
  'CREATE INDEX IF NOT EXISTS idx_audio_cache_track_uri '
  'ON audio_cache (track_uri)',
)
class AudioCache extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Source identifier, e.g. `bilibili`.
  TextColumn get source => text()();

  /// Source-specific identity, e.g. `BV...:cid`.
  TextColumn get sourceTrackId => text()();

  /// Canonical pool key (schema v11), backfilled from `tracks.uri`.
  ///
  /// Nullable for legacy cache rows whose pool row no longer exists; new rows
  /// always carry it. This is the shared identity for cache, downloads,
  /// lyrics and stats.
  TextColumn get trackUri => text().nullable()();

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
@TableIndex.sql(
  'CREATE UNIQUE INDEX IF NOT EXISTS idx_playlists_public_id '
  'ON playlists (public_id)',
)
class Playlists extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Stable, export-safe identifier (schema v11).
  ///
  /// The integer [id] stays the internal row id; [publicId] is what future
  /// export/import and multi-device sync use. Existing rows are backfilled in
  /// the v10 -> v11 migration. Nullable at the SQLite level only so the
  /// additive migration can run without a table rebuild; the repository always
  /// writes a value. Uniqueness is enforced by the named index above.
  TextColumn get publicId => text().nullable()();

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
@TableIndex.sql(
  'CREATE INDEX IF NOT EXISTS idx_playlist_tracks_position '
  'ON playlist_tracks (playlist_id, position ASC, id ASC)',
)
class PlaylistTracks extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Owning playlist row id.
  IntColumn get playlistId => integer()();

  /// Canonical pool key (`local:<path>` / `bilibili:<bvid>:<cid>`).
  TextColumn get uri => text()();

  /// Unix timestamp when the member was added (kept for display/audit).
  IntColumn get addedAt => integer()();

  /// Manual display order within the playlist (schema v11).
  ///
  /// Smaller sorts first. Backfilled densely (0..n-1) in the v10 -> v11
  /// migration; new additions are inserted at the front with `min - 1`, and a
  /// manual reorder rewrites the list densely.
  IntColumn get position => integer().withDefault(const Constant(0))();

  /// Unix timestamp of the last member change (schema v11).
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();

  /// Unix timestamp when the member was removed, or `null` while live
  /// (schema v11). Kept as a tombstone so future sync can distinguish
  /// "removed elsewhere" from "never existed".
  IntColumn get deletedAt => integer().nullable()();

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

/// User-visible download tasks (schema v11).
///
/// A download is the user's intent and task state; [AudioCache] is the
/// evictable file cache. A completed download normally has a pinned cache
/// entry, but the two are not the same fact and are not kept in lockstep by
/// foreign keys.
@DataClassName('DownloadRow')
@TableIndex.sql(
  'CREATE INDEX IF NOT EXISTS idx_downloads_track_status '
  'ON downloads (track_uri, status)',
)
@TableIndex.sql(
  'CREATE INDEX IF NOT EXISTS idx_downloads_status_created '
  'ON downloads (status, created_at)',
)
class Downloads extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Stable, export-safe identifier for future sync/import.
  TextColumn get publicId => text().unique()();

  /// Canonical pool key (`tracks.uri`).
  TextColumn get trackUri => text()();

  /// `queued` / `downloading` / `paused` / `done` / `failed` / `canceled`.
  TextColumn get status => text()();

  /// Source-specific quality id, when known.
  TextColumn get qualityId => text().nullable()();

  /// Absolute path of the finished audio file, or `null` while incomplete.
  TextColumn get filePath => text().nullable()();

  /// Bytes written so far.
  IntColumn get bytesDone => integer().withDefault(const Constant(0))();

  /// Total bytes when the source reports a length, else `null`.
  IntColumn get bytesTotal => integer().nullable()();

  /// Last error message for `failed`, else `null`.
  TextColumn get error => text().nullable()();

  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get completedAt => integer().nullable()();
}

/// Sidecar assets belonging to a download (schema v11).
///
/// Kept separate from [Downloads] so one task can own audio plus cover/lyric/
/// translation files without nullable columns multiplying.
@DataClassName('DownloadAssetRow')
@TableIndex.sql(
  'CREATE INDEX IF NOT EXISTS idx_download_assets_download '
  'ON download_assets (download_id)',
)
class DownloadAssets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get downloadId => integer()();

  /// `audio` / `cover` / `lyric` / `translation`.
  TextColumn get kind => text()();
  TextColumn get filePath => text()();
  IntColumn get bytes => integer()();
  TextColumn get contentHash => text().nullable()();
  IntColumn get updatedAt => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {downloadId, kind},
  ];
}

/// Append-only playback events (schema v11).
///
/// The event log is the source of truth for recent plays and stats; aggregate
/// rows are derived from it and can be rebuilt. Timestamps are epoch
/// milliseconds in UTC; [startedAt] is the event time used for day buckets.
@DataClassName('PlayEventRow')
@TableIndex.sql(
  'CREATE INDEX IF NOT EXISTS idx_play_events_track_started '
  'ON play_events (track_uri, started_at)',
)
@TableIndex.sql(
  'CREATE INDEX IF NOT EXISTS idx_play_events_started '
  'ON play_events (started_at)',
)
class PlayEvents extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Stable event id for export/import and future sync.
  TextColumn get eventId => text().unique()();

  /// Canonical pool key (`tracks.uri`).
  TextColumn get trackUri => text()();
  IntColumn get startedAt => integer()();
  IntColumn get endedAt => integer().nullable()();

  /// Last known playback position at the end of the session.
  IntColumn get positionMs => integer().withDefault(const Constant(0))();

  /// Wall-clock time spent listening during this session.
  IntColumn get listenedMs => integer().withDefault(const Constant(0))();

  /// Track duration at event time, when known.
  IntColumn get durationMs => integer().nullable()();

  /// Whether the track reached a natural end (or the configured threshold).
  BoolColumn get completed => boolean().withDefault(const Constant(false))();

  TextColumn get sessionId => text().nullable()();
  TextColumn get deviceId => text().nullable()();
  IntColumn get createdAt => integer()();
}

/// Derived per-track playback aggregate (schema v11).
///
/// Rebuildable from [PlayEvents]; never the only copy of a fact.
@DataClassName('TrackStatRow')
@TableIndex.sql(
  'CREATE INDEX IF NOT EXISTS idx_track_stats_last_played '
  'ON track_stats (last_played_at)',
)
class TrackStats extends Table {
  TextColumn get trackUri => text()();
  IntColumn get playCount => integer().withDefault(const Constant(0))();
  IntColumn get totalMs => integer().withDefault(const Constant(0))();
  IntColumn get lastPlayedAt => integer().nullable()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {trackUri};
}

/// Derived per-day playback aggregate (schema v11).
@DataClassName('DailyStatRow')
@TableIndex.sql(
  'CREATE INDEX IF NOT EXISTS idx_daily_stats_day '
  'ON daily_stats (day_start)',
)
class DailyStats extends Table {
  /// Local-day start in epoch milliseconds.
  IntColumn get dayStart => integer()();
  TextColumn get trackUri => text()();
  IntColumn get playCount => integer().withDefault(const Constant(0))();
  IntColumn get totalMs => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {dayStart, trackUri};
}

/// Cached lyrics payloads (schema v11).
///
/// The file/bytes themselves live outside SQLite; this row is the index and
/// the parsed payload is small text. [offsetMs] is the user's persisted
/// per-track adjustment; [expiresAt] allows stale provider responses to be
/// refreshed without losing the last good copy.
@DataClassName('LyricsCacheRow')
class LyricsCache extends Table {
  TextColumn get trackUri => text()();
  TextColumn get provider => text()();

  /// `lrc` / `yrc` / `ass` / `json`.
  TextColumn get format => text()();
  TextColumn get content => text()();
  TextColumn get translation => text().nullable()();
  IntColumn get offsetMs => integer().withDefault(const Constant(0))();
  TextColumn get contentHash => text().nullable()();
  IntColumn get fetchedAt => integer()();
  IntColumn get expiresAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {trackUri, provider};
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
