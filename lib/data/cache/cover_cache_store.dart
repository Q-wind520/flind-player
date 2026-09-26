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

import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:flind_player/data/cache/audio_cache_store.dart'
    show EvictionResult, IntegrityReport;
import 'package:flind_player/data/database/app_database.dart';

/// A single cached remote cover, as stored in the `cover_cache` index.
@immutable
class CachedCover {
  const CachedCover({
    required this.id,
    required this.urlHash,
    required this.filePath,
    required this.contentHash,
    required this.bytes,
    required this.cachedAt,
    required this.lastAccessedAt,
  });

  /// Database row id.
  final int id;

  /// `sha1(normalized cover URL)`; the lookup key.
  final String urlHash;

  /// Absolute path of the cached file.
  final String filePath;

  /// `sha1` hex digest of the stored bytes; also the on-disk file name.
  final String contentHash;

  /// Size of the cached file, in bytes.
  final int bytes;

  /// When the file entered the cache.
  final DateTime cachedAt;

  /// When the file was last served; the LRU ordering key.
  final DateTime lastAccessedAt;
}

/// Layer-2 remote-cover cache: covers for un-cached songs only; wiped on
/// every app start (docs/local-library.md §3).
///
/// Owns the `cover_cache` rows, the cached files, LRU eviction and the startup
/// integrity pass. Files are content-addressed at
/// `<baseDir>/<sha1(bytes)>.jpg`, so identical images fetched under different
/// URLs share one physical file and are counted once.
///
/// The quota is the fixed [ephemeralLimitBytes] constant — independent of the
/// user's audio-cache limit — and this store only ever reads its own bytes,
/// never `audio_cache`. For a lazily-initialised store
/// ([CoverCacheStore.lazy]) any async method resolves the base directory; the
/// lazy constructor starts that resolution eagerly.
class CoverCacheStore {
  /// Fixed byte cap for the session-scoped cover cache (256 MiB).
  ///
  /// Not user-configurable; the cache is wiped on every app start.
  static const int ephemeralLimitBytes = 256 * 1024 * 1024;

  /// Creates a store rooted at [baseDir] (tests use a temp directory).
  CoverCacheStore({required AppDatabase database, required Directory baseDir})
    : _db = database,
      _baseDir = baseDir, // ignore: prefer_initializing_formals
      _resolveBaseDir = null;

  /// Creates a store whose root is resolved through `path_provider` on first
  /// use.
  ///
  /// Production wiring cannot await `path_provider` from a synchronous
  /// provider, so the directory is resolved lazily here instead (mirroring
  /// [AudioCacheStore.lazy]). The resolution is started eagerly so synchronous
  /// callers observe a populated [cacheDirectoryPath] shortly after
  /// construction.
  CoverCacheStore.lazy({
    required AppDatabase database,
    required Future<Directory> Function() resolveBaseDir,
  }) : _db = database,
       _baseDir = null,
       // ignore: prefer_initializing_formals
       _resolveBaseDir = resolveBaseDir {
    final future = _resolveBaseDir!();
    _baseDirFuture = future;
    // Best-effort warm-up so `fileFor`-style synchronous callers can serve
    // paths without an explicit async call first. Errors are surfaced again by
    // `_resolveDir`.
    unawaited(
      future.then<void>(
        (directory) {
          if (!directory.existsSync()) {
            directory.createSync(recursive: true);
          }
          _baseDir = directory;
        },
        onError: (Object error) {
          debugPrint(
            'CoverCacheStore: base directory resolution failed: $error',
          );
        },
      ),
    );
  }

  final AppDatabase _db;
  final Future<Directory> Function()? _resolveBaseDir;

  Directory? _baseDir;
  Future<Directory>? _baseDirFuture;

  /// The row for [urlHash] and bumps its `lastAccessedAt`, or `null`.
  Future<CachedCover?> lookup(String urlHash) async {
    await _resolveDir();
    final row = await (_db.select(
      _db.coverCache,
    )..where((t) => t.urlHash.equals(urlHash))).getSingleOrNull();
    if (row == null) return null;
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.coverCache)..where((t) => t.id.equals(row.id))).write(
      CoverCacheCompanion(lastAccessedAt: Value(now)),
    );
    return _toDomain(row.copyWith(lastAccessedAt: now));
  }

  /// The cached file path for [urlHash] when both the row and file exist.
  ///
  /// Does not touch the LRU order; use [lookup] when serving a hit.
  Future<String?> lookupPath(String urlHash) async {
    await _resolveDir();
    final row = await (_db.select(
      _db.coverCache,
    )..where((t) => t.urlHash.equals(urlHash))).getSingleOrNull();
    if (row == null) return null;
    return File(row.filePath).existsSync() ? row.filePath : null;
  }

  /// Stores [bytes] under [urlHash], returning the resolved file path.
  ///
  /// The file is content-addressed at `<baseDir>/<contentHash>.jpg`; an
  /// existing file is reused instead of rewritten. Identical content already
  /// indexed under another URL is deduplicated: this row is pointed at the
  /// existing file and the redundant copy is removed. The row is upserted on
  /// the unique [urlHash].
  Future<String> insert({
    required String urlHash,
    required String contentHash,
    required Uint8List bytes,
  }) async {
    final base = await _resolveDir();
    final target = File(p.join(base.path, '$contentHash.jpg'));

    var resolvedPath = target.path;
    final duplicate = await _findExistingContentPath(contentHash, target.path);
    if (duplicate != null) {
      // Another row already owns this content under a different path: reuse it
      // and drop our redundant copy, if any.
      resolvedPath = duplicate;
      if (target.existsSync()) {
        await _deleteFileIfUnreferenced(target.path);
      }
    } else if (target.existsSync()) {
      // Content-addressed name already on disk: reuse it without rewriting.
    } else {
      target.parent.createSync(recursive: true);
      target.writeAsBytesSync(bytes, flush: true);
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final companion = CoverCacheCompanion.insert(
      urlHash: urlHash,
      filePath: resolvedPath,
      contentHash: contentHash,
      bytes: bytes.length,
      cachedAt: now,
      lastAccessedAt: now,
    );
    final row = await _db
        .into(_db.coverCache)
        .insertReturning(
          companion,
          onConflict: DoUpdate(
            (_) => companion,
            target: [_db.coverCache.urlHash],
          ),
        );
    return row.filePath;
  }

  /// Deletes the row for [id] and its file, unless another row still shares it.
  ///
  /// The row is removed even when the file is already gone.
  Future<void> remove(int id) async {
    await _resolveDir();
    final row = await (_db.select(
      _db.coverCache,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    await (_db.delete(_db.coverCache)..where((t) => t.id.equals(id))).go();
    await _deleteFileIfUnreferenced(row.filePath);
  }

  /// Deletes every row and every file under the cover cache root.
  ///
  /// Never throws; failures are logged and skipped.
  Future<void> clear() async {
    Directory? base;
    try {
      base = await _resolveDir();
    } catch (error) {
      debugPrint('CoverCacheStore: clear failed to resolve root: $error');
    }
    try {
      await _db.delete(_db.coverCache).go();
    } catch (error) {
      debugPrint('CoverCacheStore: clear failed to drop rows: $error');
    }
    if (base == null) return;
    try {
      await for (final entity in base.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        if (!_isUnderBaseDir(entity.path, base)) continue;
        try {
          entity.deleteSync();
        } catch (error) {
          debugPrint('CoverCacheStore: failed to delete $entity: $error');
        }
      }
    } catch (error) {
      debugPrint('CoverCacheStore: clear failed: $error');
    }
  }

  /// Total cover bytes occupied on disk, counting each physical file once.
  ///
  /// Rows that share a [CachedCover.filePath] (identical content deduplicated
  /// across URLs) contribute their size a single time.
  Future<int> totalBytes() async {
    final query = _db.customSelect(
      'SELECT COALESCE(SUM(bytes), 0) AS total FROM ('
      'SELECT DISTINCT file_path, bytes FROM cover_cache)',
      readsFrom: {_db.coverCache},
    );
    final row = await query.getSingle();
    return row.read<int>('total');
  }

  /// Every cached row, oldest `lastAccessedAt` first (LRU order).
  Future<List<CachedCover>> entries() async {
    final rows =
        await (_db.select(_db.coverCache)..orderBy([
              (t) => OrderingTerm.asc(t.lastAccessedAt),
              (t) => OrderingTerm.asc(t.id),
            ]))
            .get();
    return rows.map(_toDomain).toList(growable: false);
  }

  /// Evicts cover rows (oldest `lastAccessedAt` first) until
  /// `used + incomingBytes <= ephemeralLimitBytes`, where `used` is this
  /// store's own byte footprint.
  ///
  /// The layer-2 quota is fixed and independent of the user's audio-cache
  /// limit; this method never reads settings nor `audio_cache`.
  /// [EvictionResult.hasSpace] is `false` when even evicting every cover still
  /// does not fit.
  ///
  /// Never throws; a failure is logged and reported as no space.
  Future<EvictionResult> ensureSpace(int incomingBytes) async {
    var evictedCount = 0;
    var freedBytes = 0;
    try {
      // Resolve the root first so `_deleteFile`'s containment guard is active
      // even if the lazy warm-up has not completed yet.
      await _resolveDir();
      final used = await totalBytes();

      if (used + incomingBytes <= ephemeralLimitBytes) {
        return const EvictionResult(
          evictedCount: 0,
          freedBytes: 0,
          hasSpace: true,
        );
      }

      final candidates =
          await (_db.select(_db.coverCache)..orderBy([
                (t) => OrderingTerm.asc(t.lastAccessedAt),
                (t) => OrderingTerm.asc(t.id),
              ]))
              .get();

      for (final candidate in candidates) {
        if (used - freedBytes + incomingBytes <= ephemeralLimitBytes) break;
        await (_db.delete(
          _db.coverCache,
        )..where((t) => t.id.equals(candidate.id))).go();
        evictedCount++;
        final stillReferenced = await (_db.select(
          _db.coverCache,
        )..where((t) => t.filePath.equals(candidate.filePath))).get();
        if (stillReferenced.isEmpty) {
          _deleteFile(candidate.filePath);
          freedBytes += candidate.bytes;
        }
      }

      return EvictionResult(
        evictedCount: evictedCount,
        freedBytes: freedBytes,
        hasSpace: used - freedBytes + incomingBytes <= ephemeralLimitBytes,
      );
    } catch (error) {
      debugPrint('CoverCacheStore: ensureSpace failed: $error');
      return EvictionResult(
        evictedCount: evictedCount,
        freedBytes: freedBytes,
        hasSpace: false,
      );
    }
  }

  /// Evicts covers oldest-first until usage fits [ephemeralLimitBytes];
  /// equivalent to [ensureSpace] with no incoming bytes.
  Future<EvictionResult> enforceLimit() => ensureSpace(0);

  /// Absolute path of the resolved cover cache root directory.
  Future<String> cacheDirectoryPath() async => (await _resolveDir()).path;

  /// Reconciles the index with the filesystem.
  ///
  /// Removes rows whose file vanished and deletes files under the cover root
  /// that no row references. Files outside the cover root are never touched.
  /// Never throws; failures are logged and counted where known.
  Future<IntegrityReport> checkIntegrity() async {
    Directory? base;
    try {
      base = await _resolveDir();
    } catch (error) {
      debugPrint('CoverCacheStore: integrity resolve failed: $error');
    }
    var rowsRemoved = 0;
    var orphansRemoved = 0;
    try {
      final rows = await _db.select(_db.coverCache).get();
      final referenced = <String>{};
      for (final row in rows) {
        final file = File(row.filePath);
        if (file.existsSync()) {
          referenced.add(p.canonicalize(row.filePath));
        } else {
          await (_db.delete(
            _db.coverCache,
          )..where((t) => t.id.equals(row.id))).go();
          rowsRemoved++;
        }
      }

      if (base == null) {
        return IntegrityReport(
          rowsRemoved: rowsRemoved,
          orphansRemoved: orphansRemoved,
        );
      }

      await for (final entity in base.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        if (!_isUnderBaseDir(entity.path, base)) continue;
        if (referenced.contains(p.canonicalize(entity.path))) continue;
        try {
          entity.deleteSync();
          orphansRemoved++;
        } catch (error) {
          debugPrint(
            'CoverCacheStore: failed to delete orphan $entity: $error',
          );
        }
      }
    } catch (error) {
      debugPrint('CoverCacheStore: integrity check failed: $error');
    }
    return IntegrityReport(
      rowsRemoved: rowsRemoved,
      orphansRemoved: orphansRemoved,
    );
  }

  Future<Directory> _resolveDir() async {
    final existing = _baseDir;
    if (existing != null) return existing;

    final future = _baseDirFuture ??= _resolveBaseDir!();
    final directory = await future;
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    _baseDir = directory;
    return directory;
  }

  /// Deletes [path] only when it is inside the cover cache root; never throws.
  void _deleteFile(String path) {
    try {
      final base = _baseDir;
      if (base != null && !_isUnderBaseDir(path, base)) {
        debugPrint('CoverCacheStore: refusing to delete outside cache: $path');
        return;
      }
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (error) {
      debugPrint('CoverCacheStore: failed to delete $path: $error');
    }
  }

  /// Deletes [path] unless another row still points at the same file.
  Future<void> _deleteFileIfUnreferenced(String path) async {
    final remaining = await (_db.select(
      _db.coverCache,
    )..where((t) => t.filePath.equals(path))).get();
    if (remaining.isEmpty) {
      _deleteFile(path);
    }
  }

  /// The first existing row with [contentHash] whose file is not [filePath].
  Future<String?> _findExistingContentPath(
    String contentHash,
    String filePath,
  ) async {
    final rows = await (_db.select(
      _db.coverCache,
    )..where((t) => t.contentHash.equals(contentHash))).get();
    for (final row in rows) {
      if (row.filePath == filePath) continue;
      if (File(row.filePath).existsSync()) return row.filePath;
    }
    return null;
  }

  bool _isUnderBaseDir(String path, Directory base) {
    final normalized = p.canonicalize(path);
    final basePath = p.canonicalize(base.path);
    return normalized == basePath || p.isWithin(basePath, normalized);
  }

  CachedCover _toDomain(CoverCacheRow row) {
    return CachedCover(
      id: row.id,
      urlHash: row.urlHash,
      filePath: row.filePath,
      contentHash: row.contentHash,
      bytes: row.bytes,
      cachedAt: DateTime.fromMillisecondsSinceEpoch(row.cachedAt),
      lastAccessedAt: DateTime.fromMillisecondsSinceEpoch(row.lastAccessedAt),
    );
  }
}
