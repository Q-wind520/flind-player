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

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/repositories/music_library_repository.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/database/app_database.dart';

/// Drift-backed [MusicLibraryRepository].
class DriftMusicLibraryRepository implements MusicLibraryRepository {
  DriftMusicLibraryRepository(this._db);

  final AppDatabase _db;

  @override
  Future<List<Track>> allTracks() async {
    final rows = await _orderedQuery().get();
    return rows.map(_toDomain).toList(growable: false);
  }

  @override
  Stream<List<Track>> watchTracks() {
    return _orderedQuery().watch().map(
      (rows) => rows.map(_toDomain).toList(growable: false),
    );
  }

  @override
  Future<List<Track>> searchTracks(String query, {int limit = 100}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final ftsQuery = _toFtsQuery(trimmed);
    if (ftsQuery != null) {
      try {
        final rows = await _db
            .customSelect(
              'SELECT t.* FROM tracks t '
              'JOIN tracks_fts f ON f.rowid = t.id '
              'WHERE tracks_fts MATCH ?1 AND t.missing_at IS NULL '
              'ORDER BY t.title COLLATE NOCASE '
              'LIMIT ?2',
              variables: [Variable<String>(ftsQuery), Variable<int>(limit)],
              readsFrom: {_db.tracks},
            )
            .get();
        return rows
            .map((row) => _toDomain(_db.tracks.map(row.data)))
            .toList(growable: false);
      } on Exception {
        // Malformed FTS5 expressions (or a build without FTS5) fall through to
        // the LIKE scan below instead of failing the search.
      }
    }
    return _searchWithLike(trimmed, limit);
  }

  /// Fallback search used when FTS5 cannot evaluate the query.
  ///
  /// Plain `LIKE '%query%'` over title/artist/album, case-insensitive only for
  /// ASCII, ordered the same as the FTS path.
  Future<List<Track>> _searchWithLike(String query, int limit) async {
    final pattern = '%$query%';
    final rows =
        await (_db.select(_db.tracks)
              ..where(
                (t) =>
                    t.missingAt.isNull() &
                    (t.title.like(pattern) |
                        t.artist.like(pattern) |
                        t.album.like(pattern)),
              )
              ..orderBy([
                (t) => OrderingTerm.asc(t.title.collate(Collate.noCase)),
              ])
              ..limit(limit))
            .get();
    return rows.map(_toDomain).toList(growable: false);
  }

  /// Converts a raw user query into an FTS5 `MATCH` expression.
  ///
  /// Each whitespace-separated token is wrapped in double quotes (embedded `"`
  /// doubled) so FTS5 operators such as `NEAR(`, `-` or `*` are treated as
  /// literal text; the final token gets a trailing `*` for prefix matching.
  /// Returns `null` when the query contains no tokens.
  String? _toFtsQuery(String query) {
    final tokens = query
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    if (tokens.isEmpty) return null;

    final buffer = StringBuffer();
    for (var i = 0; i < tokens.length; i++) {
      if (i > 0) buffer.write(' ');
      buffer.write('"${tokens[i].replaceAll('"', '""')}"');
      if (i == tokens.length - 1) buffer.write('*');
    }
    return buffer.toString();
  }

  @override
  Future<int> upsertTrack(Track track) async {
    final existing = await (_db.select(
      _db.tracks,
    )..where((t) => t.uri.equals(track.uri))).getSingleOrNull();
    final now = DateTime.now().millisecondsSinceEpoch;

    // `createdAt` is only written on first insert; `updatedAt` on every write.
    final companion = _toCompanion(
      track,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    // The table's uniqueness key is `uri`, not the autoincrement primary key,
    // so target the unique column explicitly instead of relying on the
    // primary-key default of `insertOnConflictUpdate`.
    final row = await _db
        .into(_db.tracks)
        .insertReturning(
          companion,
          onConflict: DoUpdate((_) => companion, target: [_db.tracks.uri]),
        );
    return row.id;
  }

  @override
  Future<void> upsertTracks(List<Track> tracks) async {
    if (tracks.isEmpty) return;

    await _db.transaction(() async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db.batch((batch) async {
        for (final track in tracks) {
          // Reuse the singular upsert's companion logic so `createdAt` is only
          // written on first insert and `updatedAt` on every write.
          final existing = await (_db.select(
            _db.tracks,
          )..where((t) => t.uri.equals(track.uri))).getSingleOrNull();
          final companion = _toCompanion(
            track,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
          );
          batch.insert(
            _db.tracks,
            companion,
            onConflict: DoUpdate((_) => companion, target: [_db.tracks.uri]),
          );
        }
      });
    });
  }

  @override
  Future<void> deleteTrack(int id) async {
    await (_db.delete(_db.tracks)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<Track?> findByUri(String uri) async {
    final row = await (_db.select(
      _db.tracks,
    )..where((t) => t.uri.equals(uri))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<Set<String>> trackUrisForSource(String source) async {
    final query = _db.selectOnly(_db.tracks)
      ..addColumns([_db.tracks.uri])
      ..where(_db.tracks.source.equals(source));
    final rows = await query.get();
    return rows.map((row) => row.read(_db.tracks.uri)!).toSet();
  }

  @override
  Future<int> markMissingExcept(String source, Set<String> seenUris) async {
    // Guard: a failed or empty scan must never mark the whole library missing.
    if (seenUris.isEmpty) return 0;

    final now = DateTime.now().millisecondsSinceEpoch;
    return _db.transaction(() async {
      // Restored: seen again, so clear the soft-delete marker and record the
      // fresh sighting.
      await (_db.update(
        _db.tracks,
      )..where((t) => t.source.equals(source) & t.uri.isIn(seenUris))).write(
        TracksCompanion(
          missingAt: const Value<int?>(null),
          lastSeenAt: Value(now),
        ),
      );

      // Newly missing: absent from this scan and not already marked.
      return (_db.update(_db.tracks)..where(
            (t) =>
                t.source.equals(source) &
                t.uri.isNotIn(seenUris) &
                t.missingAt.isNull(),
          ))
          .write(TracksCompanion(missingAt: Value(now)));
    });
  }

  @override
  Future<List<String>> scanRoots() async {
    final query = _db.select(_db.scanRoots)
      ..orderBy([(t) => OrderingTerm.asc(t.path)]);
    final rows = await query.get();
    return rows.map((row) => row.path).toList(growable: false);
  }

  @override
  Future<void> addScanRoot(String path) async {
    await _db
        .into(_db.scanRoots)
        .insert(
          ScanRootsCompanion.insert(
            path: path,
            kind: 'local',
            addedAt: DateTime.now().millisecondsSinceEpoch,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  @override
  Future<void> removeScanRoot(String path) async {
    await (_db.delete(_db.scanRoots)..where((t) => t.path.equals(path))).go();
  }

  SimpleSelectStatement<$TracksTable, TrackRow> _orderedQuery() {
    return _db.select(_db.tracks)
      ..where((t) => t.missingAt.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.title.collate(Collate.noCase))]);
  }

  Track _toDomain(TrackRow row) {
    return Track(
      id: row.id,
      source: row.source,
      sourceTrackId: _decodeSourceTrackId(
        row.source,
        row.sourceTrackId,
        row.uri,
      ),
      uri: row.uri,
      title: row.title,
      artist: row.artist,
      album: row.album,
      albumArtist: row.albumArtist,
      trackNo: row.trackNo,
      discNo: row.discNo,
      year: row.year,
      duration: row.durationMs == null
          ? null
          : Duration(milliseconds: row.durationMs!),
      bitrate: row.bitrate,
      sampleRate: row.sampleRate,
      genre: row.genre,
      coverPath: row.coverPath,
    );
  }

  TracksCompanion _toCompanion(
    Track track, {
    required int createdAt,
    required int updatedAt,
  }) {
    return TracksCompanion(
      source: Value(track.source),
      sourceTrackId: Value(_encodeSourceTrackId(track.sourceTrackId)),
      uri: Value(track.uri),
      title: Value(track.title),
      artist: Value(track.artist),
      album: Value(track.album),
      albumArtist: Value(track.albumArtist),
      trackNo: Value(track.trackNo),
      discNo: Value(track.discNo),
      year: Value(track.year),
      durationMs: Value(track.duration?.inMilliseconds),
      bitrate: Value(track.bitrate),
      sampleRate: Value(track.sampleRate),
      genre: Value(track.genre),
      coverPath: Value(track.coverPath),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }
}

String _encodeSourceTrackId(SourceTrackId id) {
  return switch (id) {
    LocalTrackId(:final path) => path,
    BiliTrackId(:final bvid, :final cid) => '$bvid:$cid',
  };
}

/// Rebuilds the domain [SourceTrackId] from the persisted columns.
///
/// `local` rows store the absolute path in `sourceTrackId`; `bilibili` rows
/// store `<bvid>:<cid>`. Any other source, or a malformed bilibili value, falls
/// back to a local identity keyed by the canonical [uri] so the row stays
/// usable.
SourceTrackId _decodeSourceTrackId(String source, String raw, String uri) {
  if (source == 'local') {
    return LocalTrackId(raw);
  }
  if (source == 'bilibili') {
    final separator = raw.lastIndexOf(':');
    if (separator > 0) {
      final cid = int.tryParse(raw.substring(separator + 1));
      if (cid != null) {
        return BiliTrackId(bvid: raw.substring(0, separator), cid: cid);
      }
    }
  }
  return LocalTrackId(uri);
}
