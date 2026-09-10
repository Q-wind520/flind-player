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

SourceTrackId _decodeSourceTrackId(String source, String raw, String uri) {
  // M0 only persists local rows. `SourceTrackId` is a sealed type, so a local
  // row reconstructs its path; any other (not-yet-written) source falls back
  // to a local identity keyed by the canonical uri so the row stays usable.
  if (source == 'local') {
    return LocalTrackId(raw);
  }
  return LocalTrackId(uri);
}
