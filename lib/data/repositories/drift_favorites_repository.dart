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
import 'package:flind_player/core/repositories/favorites_repository.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/database/app_database.dart';

/// Drift-backed [FavoritesRepository].
///
/// Favourites are stored independently of `tracks`, so they are unaffected by
/// library soft-deletes or rescans.
class DriftFavoritesRepository implements FavoritesRepository {
  DriftFavoritesRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Track>> watchFavorites() {
    return _orderedQuery().watch().map(
      (rows) => rows.map(_toDomain).toList(growable: false),
    );
  }

  @override
  Future<List<Track>> allFavorites() async {
    final rows = await _orderedQuery().get();
    return rows.map(_toDomain).toList(growable: false);
  }

  @override
  Future<bool> isFavorite(String uri) async {
    final row = await (_db.select(
      _db.favorites,
    )..where((f) => f.uri.equals(uri))).getSingleOrNull();
    return row != null;
  }

  @override
  Future<void> addFavorite(Track track) async {
    final companion = FavoritesCompanion(
      uri: Value(track.uri),
      source: Value(track.source),
      sourceTrackId: Value(_encodeSourceTrackId(track.sourceTrackId)),
      title: Value(track.title),
      artist: Value(track.artist),
      album: Value(track.album),
      durationMs: Value(track.duration?.inMilliseconds),
      coverPath: Value(track.coverPath),
      coverUrl: Value(track.coverUrl),
      favoritedAt: Value(DateTime.now().millisecondsSinceEpoch),
    );

    // The uniqueness key is `uri`, not the autoincrement primary key, so target
    // the unique column explicitly instead of relying on the primary-key
    // default of `insertOnConflictUpdate`.
    await _db
        .into(_db.favorites)
        .insert(
          companion,
          onConflict: DoUpdate((_) => companion, target: [_db.favorites.uri]),
        );
  }

  @override
  Future<void> removeFavorite(String uri) async {
    await (_db.delete(_db.favorites)..where((f) => f.uri.equals(uri))).go();
  }

  @override
  Future<void> updateFavoriteCover(
    String uri, {
    String? coverPath,
    String? coverUrl,
  }) async {
    // `favoritedAt` is deliberately untouched: refreshing a cover must not
    // reorder the list. A missing row is a no-op.
    await (_db.update(_db.favorites)..where((f) => f.uri.equals(uri))).write(
      FavoritesCompanion(
        coverPath: coverPath == null ? const Value.absent() : Value(coverPath),
        coverUrl: coverUrl == null ? const Value.absent() : Value(coverUrl),
      ),
    );
  }

  @override
  Future<bool> toggleFavorite(Track track) async {
    if (await isFavorite(track.uri)) {
      await removeFavorite(track.uri);
      return false;
    }
    await addFavorite(track);
    return true;
  }

  /// Newest first; the row id breaks ties between same-millisecond inserts.
  SimpleSelectStatement<$FavoritesTable, FavoriteRow> _orderedQuery() {
    return _db.select(_db.favorites)..orderBy([
      (f) => OrderingTerm.desc(f.favoritedAt),
      (f) => OrderingTerm.desc(f.id),
    ]);
  }

  Track _toDomain(FavoriteRow row) {
    return Track(
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
      duration: row.durationMs == null
          ? null
          : Duration(milliseconds: row.durationMs!),
      coverPath: row.coverPath,
      coverUrl: row.coverUrl,
    );
  }
}

String _encodeSourceTrackId(SourceTrackId id) {
  return switch (id) {
    LocalTrackId(:final path) => path,
    BiliTrackId(:final bvid, :final cid) => '$bvid:$cid',
  };
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
