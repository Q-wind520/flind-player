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
import 'package:flind_player/core/repositories/playlist_repository.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/database/app_database.dart';
import 'package:flind_player/data/database/playlist_defaults.dart';
import 'package:flind_player/data/repositories/drift_music_library_repository.dart';

/// Drift-backed [PlaylistRepository].
///
/// Members are stored as pure references keyed by `(playlist_id, uri)` and read
/// through a `JOIN` on the pool, so the pool is the single source of truth and
/// a member's metadata and cover are always current.
class DriftPlaylistRepository implements PlaylistRepository {
  DriftPlaylistRepository(AppDatabase db, {MusicLibraryRepository? library})
    : _db = db,
      _library = library ?? DriftMusicLibraryRepository(db);

  final AppDatabase _db;
  final MusicLibraryRepository _library;

  @override
  Stream<List<Playlist>> watchPlaylists() {
    return (_db.select(_db.playlists)
          ..orderBy([
            // The built-in favourites playlist is pinned first; custom
            // playlists follow newest first.
            (p) => OrderingTerm.asc(p.kind.equals(playlistKindCustom)),
            (p) => OrderingTerm.desc(p.createdAt),
            (p) => OrderingTerm.desc(p.id),
          ]))
        .watch()
        .map((rows) => rows.map(_toPlaylist).toList(growable: false));
  }

  @override
  Future<Playlist?> playlistById(int id) async {
    final row = await (_db.select(
      _db.playlists,
    )..where((p) => p.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toPlaylist(row);
  }

  @override
  Future<Playlist> createPlaylist({
    required String name,
    String? description,
    String? coverPath,
    String? coverUrl,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Playlist name must not be blank');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await _db.into(_db.playlists).insert(
      PlaylistsCompanion.insert(
        name: trimmed,
        kind: playlistKindCustom,
        description: Value(description),
        coverPath: Value(coverPath),
        coverUrl: Value(coverUrl),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return (await playlistById(id))!;
  }

  @override
  Future<void> updatePlaylist(
    int id, {
    String? name,
    String? description,
    String? coverPath,
    String? coverUrl,
    bool clearCover = false,
  }) async {
    final existing = await playlistById(id);
    if (existing == null) return; // A missing playlist is a no-op.
    if (existing.kind == PlaylistKind.favorites) {
      throw StateError(
        'The built-in favourites playlist cannot be renamed or re-covered',
      );
    }
    if (name != null && name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'Playlist name must not be blank');
    }
    await (_db.update(_db.playlists)..where((p) => p.id.equals(id))).write(
      PlaylistsCompanion(
        name: name == null ? const Value.absent() : Value(name.trim()),
        description: description == null
            ? const Value.absent()
            : Value(description),
        coverPath: clearCover
            ? const Value(null)
            : (coverPath == null ? const Value.absent() : Value(coverPath)),
        coverUrl: clearCover
            ? const Value(null)
            : (coverUrl == null ? const Value.absent() : Value(coverUrl)),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  @override
  Future<void> deletePlaylist(int id) async {
    final existing = await playlistById(id);
    if (existing == null) return; // A missing playlist is a no-op.
    if (existing.kind == PlaylistKind.favorites) {
      throw StateError('The built-in favourites playlist cannot be deleted');
    }
    await _db.transaction(() async {
      // Cascade: members die with their playlist; the pool rows are untouched.
      await (_db.delete(
        _db.playlistTracks,
      )..where((pt) => pt.playlistId.equals(id))).go();
      await (_db.delete(_db.playlists)..where((p) => p.id.equals(id))).go();
    });
  }

  @override
  Stream<List<Track>> watchPlaylistTracks(int id) {
    return _memberQuery(id)
        .watch()
        .map((rows) => rows.map(_toDomain).toList(growable: false));
  }

  @override
  Future<List<Track>> playlistTracks(int id) async {
    final rows = await _memberQuery(id).get();
    return rows.map(_toDomain).toList(growable: false);
  }

  @override
  Future<void> addTrack(int playlistId, Track track) async {
    // The pool is the single source of truth: a referenced track must exist in
    // `tracks` so it can be resolved (and shown in 全部) after being saved.
    await _library.promoteTrack(track);

    // Members are pure references: only the pool row (promoted above) carries
    // metadata, so no snapshot columns are written here.
    final companion = PlaylistTracksCompanion(
      playlistId: Value(playlistId),
      uri: Value(track.uri),
      addedAt: Value(DateTime.now().millisecondsSinceEpoch),
    );

    // Conflict on (playlist_id, uri) is ignored: re-adding never reorders.
    await _db.into(_db.playlistTracks).insert(
      companion,
      mode: InsertMode.insertOrIgnore,
    );
  }

  @override
  Future<void> removeTrack(int playlistId, String uri) async {
    await (_db.delete(_db.playlistTracks)
          ..where(
            (pt) => pt.playlistId.equals(playlistId) & pt.uri.equals(uri),
          ))
        .go();
  }

  @override
  Future<bool> containsTrack(int playlistId, String uri) async {
    final row = await (_db.select(_db.playlistTracks)
          ..where(
            (pt) => pt.playlistId.equals(playlistId) & pt.uri.equals(uri),
          ))
        .getSingleOrNull();
    return row != null;
  }

  @override
  Stream<PlaylistCover?> watchPlaylistCover(int id) {
    return _coverQuery(id).watch().map((rows) {
      if (rows.isEmpty) return null; // Unknown playlist.
      final row = rows.single;
      // Explicit playlist cover wins over the derived member cover.
      final playlistPath = row.read<String?>('playlist_cover_path');
      final playlistUrl = row.read<String?>('playlist_cover_url');
      if (playlistPath != null || playlistUrl != null) {
        return PlaylistCover(coverPath: playlistPath, coverUrl: playlistUrl);
      }
      // Newest member's pool cover.
      final memberPath = row.read<String?>('member_cover_path');
      final memberUrl = row.read<String?>('member_cover_url');
      if (memberPath != null || memberUrl != null) {
        return PlaylistCover(coverPath: memberPath, coverUrl: memberUrl);
      }
      return null; // Default placeholder.
    });
  }

  /// The pool-joined member query: members are pure references, so every field
  /// is read from the pool (`tracks`) and `missing_at` decides availability.
  /// Ordering is `added_at DESC, id DESC`.
  Selectable<QueryRow> _memberQuery(int playlistId) {
    return _db.customSelect(
      '''
SELECT t.id AS pool_id, pt.uri AS uri, t.source, t.source_track_id,
       t.title, t.artist, t.album, t.duration_ms,
       t.cover_path, t.cover_url, t.missing_at
FROM playlist_tracks pt
JOIN tracks t ON t.uri = pt.uri
WHERE pt.playlist_id = ?1
ORDER BY pt.added_at DESC, pt.id DESC
''',
      variables: [Variable<int>(playlistId)],
      readsFrom: {_db.playlistTracks, _db.tracks},
    );
  }

  /// One row per playlist: the explicit cover plus the newest member's pool
  /// cover. A memberless playlist still yields one row with null member covers.
  Selectable<QueryRow> _coverQuery(int playlistId) {
    return _db.customSelect(
      '''
SELECT p.cover_path AS playlist_cover_path,
       p.cover_url  AS playlist_cover_url,
       t.cover_path AS member_cover_path,
       t.cover_url  AS member_cover_url
FROM playlists p
LEFT JOIN playlist_tracks pt ON pt.playlist_id = p.id
LEFT JOIN tracks t ON t.uri = pt.uri
WHERE p.id = ?1
ORDER BY pt.added_at DESC, pt.id DESC
LIMIT 1
''',
      variables: [Variable<int>(playlistId)],
      readsFrom: {_db.playlists, _db.playlistTracks, _db.tracks},
    );
  }

  Playlist _toPlaylist(PlaylistRow row) {
    return Playlist(
      id: row.id,
      name: row.name,
      kind: row.kind == playlistKindFavorites
          ? PlaylistKind.favorites
          : PlaylistKind.custom,
      description: row.description,
      coverPath: row.coverPath,
      coverUrl: row.coverUrl,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }

  Track _toDomain(QueryRow row) {
    final poolId = row.read<int>('pool_id');
    final missingAt = row.read<int?>('missing_at');
    final source = row.read<String>('source');
    final sourceTrackId = row.read<String>('source_track_id');
    final uri = row.read<String>('uri');
    final durationMs = row.read<int?>('duration_ms');
    return Track(
      id: missingAt == null ? poolId : null,
      source: source,
      sourceTrackId: _decodeSourceTrackId(source, sourceTrackId, uri),
      uri: uri,
      title: row.read<String>('title'),
      artist: row.read<String?>('artist'),
      album: row.read<String?>('album'),
      duration: durationMs == null ? null : Duration(milliseconds: durationMs),
      coverPath: row.read<String?>('cover_path'),
      coverUrl: row.read<String?>('cover_url'),
    );
  }
}

/// Rebuilds the domain [SourceTrackId] from the persisted columns, mirroring
/// the music library's `local` path / `bilibili` `bvid:cid` convention.
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