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
import 'package:flind_player/core/models/track_sort.dart';
import 'package:flind_player/core/repositories/music_library_repository.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/database/app_database.dart';
import 'package:flind_player/data/sources/local/local_library_scanner.dart';

/// Drift-backed [MusicLibraryRepository].
class DriftMusicLibraryRepository implements MusicLibraryRepository {
  DriftMusicLibraryRepository(this._db);

  final AppDatabase _db;

  @override
  Future<List<Track>> allTracks({TrackSort sort = TrackSort.title}) async {
    final rows = await _orderedQuery(sort).get();
    return rows.map(_toDomain).toList(growable: false);
  }

  @override
  Stream<List<Track>> watchTracks({TrackSort sort = TrackSort.title}) {
    return _orderedQuery(sort)
        .watch()
        .map((rows) => rows.map(_toDomain).toList(growable: false));
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
  Future<int> promoteTrack(Track track) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db
        .into(_db.tracks)
        .insert(
          _toCompanion(track, createdAt: now, updatedAt: now),
          mode: InsertMode.insertOrIgnore,
        );
    final row = await (_db.select(
      _db.tracks,
    )..where((t) => t.uri.equals(track.uri))).getSingleOrNull();
    if (row == null) {
      throw StateError('promoteTrack could not persist track ${track.uri}');
    }
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
  Future<void> upsertScannedTracks(List<ScannedTrack> tracks) async {
    if (tracks.isEmpty) return;

    await _db.transaction(() async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db.batch((batch) async {
        for (final scanned in tracks) {
          final track = scanned.track;
          final existing = await (_db.select(
            _db.tracks,
          )..where((t) => t.uri.equals(track.uri))).getSingleOrNull();
          final companion = _toCompanion(
            track,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
            file: scanned.file,
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
  Future<void> updateTrackCover(
    String uri, {
    String? coverPath,
    String? coverUrl,
  }) async {
    // Only the cover columns change; a missing row is a deliberate no-op so
    // resolving a cover cannot resurrect or create a library entry.
    await (_db.update(_db.tracks)..where((t) => t.uri.equals(uri))).write(
      TracksCompanion(
        coverPath: coverPath == null ? const Value.absent() : Value(coverPath),
        coverUrl: coverUrl == null ? const Value.absent() : Value(coverUrl),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
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
  Future<Map<String, FileFingerprint>> trackFingerprints(String source) async {
    final query = _db.selectOnly(_db.tracks)
      ..addColumns([
        _db.tracks.uri,
        _db.tracks.sizeBytes,
        _db.tracks.mtimeMs,
        _db.tracks.scanRoot,
      ])
      ..where(_db.tracks.source.equals(source));
    final rows = await query.get();
    return {
      for (final row in rows)
        row.read(_db.tracks.uri)!: FileFingerprint(
          sizeBytes: row.read(_db.tracks.sizeBytes),
          mtimeMs: row.read(_db.tracks.mtimeMs),
          scanRoot: row.read(_db.tracks.scanRoot),
        ),
    };
  }

  @override
  Future<int> markMissingExcept(
    String source,
    Set<String> seenUris, {
    Set<String>? roots,
  }) async {
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

      // Newly missing: absent from this scan and not already marked. When
      // `roots` is given, a track attributed to a root *outside* it is left
      // alone (an unmounted drive keeps its rows). Unattributed rows stay
      // eligible so individually imported files still follow disk existence.
      return (_db.update(_db.tracks)..where((t) {
            final absent =
                t.source.equals(source) &
                t.uri.isNotIn(seenUris) &
                t.missingAt.isNull();
            if (roots == null) return absent;
            if (roots.isEmpty) return absent & t.scanRoot.isNull();
            return absent & (t.scanRoot.isNull() | t.scanRoot.isIn(roots));
          }))
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
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      await (_db.delete(_db.scanRoots)..where((t) => t.path.equals(path))).go();
      // Removing a folder must actually remove its music from the library.
      // `markMissingExcept` deliberately protects roots that are not part of
      // the current scan, so without this the tracks would linger forever.
      // They are soft-deleted, so re-adding the folder and rescanning restores
      // them (and any future playlists/statistics stay intact).
      await (_db.update(_db.tracks)
            ..where((t) => t.scanRoot.equals(path) & t.missingAt.isNull()))
          .write(TracksCompanion(missingAt: Value(now)));
    });
  }

  /// Builds the visible-track select ordered by [sort].
  ///
  /// Title/artist/album compare case-insensitively and fall back to the row id
  /// for a stable order; null artist/album sort last (`IS NULL` sorts `false`
  /// before `true`).
  SimpleSelectStatement<$TracksTable, TrackRow> _orderedQuery(TrackSort sort) {
    final query = _db.select(_db.tracks)..where((t) => t.missingAt.isNull());
    return switch (sort) {
      TrackSort.title =>
        query..orderBy([
          (t) => OrderingTerm.asc(t.title.collate(Collate.noCase)),
          (t) => OrderingTerm.asc(t.id),
        ]),
      TrackSort.artist =>
        query..orderBy([
          (t) => OrderingTerm.asc(t.artist.isNull()),
          (t) => OrderingTerm.asc(t.artist.collate(Collate.noCase)),
          (t) => OrderingTerm.asc(t.id),
        ]),
      TrackSort.album =>
        query..orderBy([
          (t) => OrderingTerm.asc(t.album.isNull()),
          (t) => OrderingTerm.asc(t.album.collate(Collate.noCase)),
          (t) => OrderingTerm.asc(t.id),
        ]),
      TrackSort.recentlyAdded =>
        query..orderBy([
          (t) => OrderingTerm.desc(t.createdAt),
          (t) => OrderingTerm.desc(t.id),
        ]),
    };
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
      coverUrl: row.coverUrl,
    );
  }

  TracksCompanion _toCompanion(
    Track track, {
    required int createdAt,
    required int updatedAt,
    ScannedFile? file,
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
      coverUrl: Value(track.coverUrl),
      // `Value.absent()` leaves the fingerprint columns untouched, so a later
      // metadata-only upsert (e.g. the artwork pass) cannot erase them.
      sizeBytes: file == null ? const Value.absent() : Value(file.sizeBytes),
      mtimeMs: file == null ? const Value.absent() : Value(file.mtimeMs),
      scanRoot: file == null ? const Value.absent() : Value(file.root),
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
