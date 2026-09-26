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
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:flind_player/core/repositories/settings_repository.dart';
import 'package:flind_player/data/database/app_database.dart';

/// A single cached audio file, as stored in the `audio_cache` index.
@immutable
class CachedAudio {
  const CachedAudio({
    required this.id,
    required this.source,
    required this.sourceTrackId,
    required this.filePath,
    required this.bytes,
    required this.qualityId,
    required this.pinned,
    required this.cachedAt,
    required this.lastAccessedAt,
    this.contentHash,
    this.coverPath,
  });

  final int id;
  final String source;
  final String sourceTrackId;
  final String filePath;
  final int bytes;
  final String qualityId;
  final bool pinned;
  final DateTime cachedAt;
  final DateTime lastAccessedAt;

  /// SHA-1 hex digest of the file's bytes, or `null` for legacy rows.
  final String? contentHash;

  /// Absolute path of the song's companion cover, or `null` when none.
  final String? coverPath;
}

/// Outcome of [AudioCacheStore.ensureSpace].
@immutable
class EvictionResult {
  const EvictionResult({
    required this.evictedCount,
    required this.freedBytes,
    required this.hasSpace,
  });

  /// Number of LRU entries evicted during the call.
  final int evictedCount;

  /// Bytes reclaimed by eviction.
  final int freedBytes;

  /// Whether `currentBytes + incomingBytes` fits within the configured limit
  /// after eviction. `false` means pinned entries alone exceed the limit.
  final bool hasSpace;
}

/// Outcome of [AudioCacheStore.checkIntegrity].
@immutable
class IntegrityReport {
  const IntegrityReport({
    required this.rowsRemoved,
    required this.orphansRemoved,
  });

  /// Rows deleted because their file had vanished.
  final int rowsRemoved;

  /// Unreferenced files deleted from the cache directory.
  final int orphansRemoved;
}

/// Offline audio cache index (docs/local-library.md §4).
///
/// Owns the database rows, the cached files, LRU eviction and the startup
/// integrity pass. It deliberately does not download: a separate downloader
/// writes the file, then calls [insert] to register it.
///
/// Files live at `<baseDir>/<source>/<sha1("$source:$sourceTrackId")>.<ext>`.
/// For a lazily-initialised store ([AudioCacheStore.lazy]), any async method
/// resolves the base directory; [fileFor] is synchronous and therefore requires
/// that resolution to have completed (the lazy constructor starts it eagerly).
class AudioCacheStore {
  /// Creates a store rooted at [baseDir] (tests use a temp directory).
  AudioCacheStore({
    required AppDatabase database,
    required Directory baseDir,
    required SettingsRepository settings,
  }) : _db = database,
       _settings = settings, // ignore: prefer_initializing_formals
       _baseDir = baseDir, // ignore: prefer_initializing_formals
       _resolveBaseDir = null;

  /// Creates a store whose root is resolved through `path_provider` on first
  /// use.
  ///
  /// Production wiring cannot await `path_provider` from a synchronous
  /// provider, so the directory is resolved lazily here instead (mirroring
  /// `ArtworkCache.lazy`).
  AudioCacheStore.lazy({
    required AppDatabase database,
    required SettingsRepository settings,
    required Future<Directory> Function() resolveBaseDir,
  }) : _db = database,
       _settings = settings, // ignore: prefer_initializing_formals
       _baseDir = null,
       // ignore: prefer_initializing_formals
       _resolveBaseDir = resolveBaseDir {
    final future = _resolveBaseDir!();
    _baseDirFuture = future;
    // Best-effort warm-up so `fileFor` can serve paths without an explicit
    // async call first. Errors are surfaced again by `_resolveDir`.
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
            'AudioCacheStore: base directory resolution failed: $error',
          );
        },
      ),
    );
  }

  final AppDatabase _db;
  final SettingsRepository _settings;
  final Future<Directory> Function()? _resolveBaseDir;

  Directory? _baseDir;
  Future<Directory>? _baseDirFuture;

  /// Deterministic target path for a cached file.
  ///
  /// The file name is `sha1("$source:$sourceTrackId")` so distinct tracks never
  /// collide and re-resolving the same track always yields the same path.
  File fileFor({
    required String source,
    required String sourceTrackId,
    required String extension,
  }) {
    final base = _baseDir;
    if (base == null) {
      throw StateError(
        'AudioCacheStore base directory is not resolved yet; await an async '
        'store method before calling fileFor on a lazily-initialised store.',
      );
    }
    final digest = sha1
        .convert(utf8.encode('$source:$sourceTrackId'))
        .toString();
    final normalizedExtension = extension.startsWith('.')
        ? extension.substring(1)
        : extension;
    return File(p.join(base.path, source, '$digest.$normalizedExtension'));
  }

  /// Deterministic companion-cover path for a cached song.
  ///
  /// Lives beside the audio file (`<base>/<source>/<digest>.cover.<ext>`) so a
  /// single containment guard covers both.
  File coverFileFor({
    required String source,
    required String sourceTrackId,
    required String extension,
  }) {
    final base = _baseDir;
    if (base == null) {
      throw StateError(
        'AudioCacheStore base directory is not resolved yet; await an async '
        'store method before calling coverFileFor on a lazily-initialised '
        'store.',
      );
    }
    final digest = sha1
        .convert(utf8.encode('$source:$sourceTrackId'))
        .toString();
    final normalized = extension.startsWith('.')
        ? extension.substring(1)
        : extension;
    return File(p.join(base.path, source, '$digest.cover.$normalized'));
  }

  /// Records the companion cover path for the row [id], counting [bytes]
  /// toward the layer-1 quota; clearing [path] resets the counted bytes to 0.
  Future<void> setCoverPath(int id, String? path, {int bytes = 0}) async {
    await (_db.update(_db.audioCache)..where((t) => t.id.equals(id))).write(
      AudioCacheCompanion(
        coverPath: Value(path),
        coverBytes: Value(path == null ? 0 : bytes),
      ),
    );
  }

  /// The row for [source]/[sourceTrackId], or `null` when not cached.
  Future<CachedAudio?> lookup(String source, String sourceTrackId) async {
    await _resolveDir();
    final row =
        await (_db.select(_db.audioCache)..where(
              (t) =>
                  t.source.equals(source) &
                  t.sourceTrackId.equals(sourceTrackId),
            ))
            .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  /// Records a read by bumping `lastAccessedAt`, keeping the entry recent in
  /// the LRU order.
  Future<void> touch(int id) async {
    await (_db.update(_db.audioCache)..where((t) => t.id.equals(id))).write(
      AudioCacheCompanion(
        lastAccessedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  /// Updates the pin flag of a cached entry.
  ///
  /// Pinned entries are exempt from LRU eviction, so this is how a
  /// play-through cached track gets promoted to a manual download.
  Future<void> setPinned(int id, bool pinned) async {
    await (_db.update(_db.audioCache)..where((t) => t.id.equals(id))).write(
      AudioCacheCompanion(pinned: Value(pinned)),
    );
  }

  /// Inserts or updates the index row for a cached file, returning it.
  ///
  /// [contentHash] is the SHA-1 hex digest of [filePath]'s bytes. When it is
  /// omitted it is computed from the file; when the file does not exist the
  /// hash stays `null`. If another row already indexes the same content under a
  /// different path, the freshly written duplicate is deleted and this row is
  /// pointed at the existing physical file instead, so identical audio is
  /// stored and counted once. [coverPath], when given, is recorded verbatim as
  /// the row's companion cover and [coverBytes] is its size for the layer-1
  /// quota; when [coverPath] is omitted, the row's existing cover (and its
  /// counted bytes) is left untouched. Callers attaching a cover after the
  /// fact must use `setCoverPath(id, path, bytes: file.lengthSync())` so its
  /// bytes are counted.
  Future<CachedAudio> insert({
    required String source,
    required String sourceTrackId,
    required String filePath,
    required int bytes,
    required String qualityId,
    required bool pinned,
    String? contentHash,
    String? coverPath,
    int coverBytes = 0,
  }) async {
    await _resolveDir();
    final resolvedHash = contentHash ?? await _hashFile(filePath);

    var resolvedPath = filePath;
    var resolvedBytes = bytes;
    if (resolvedHash != null) {
      final duplicate = await _findByContentHash(resolvedHash, filePath);
      if (duplicate != null) {
        // The freshly written copy is redundant: drop it and reuse the file
        // that is already on disk.
        _deleteFile(filePath);
        resolvedPath = duplicate.filePath;
        resolvedBytes = duplicate.bytes;
      }
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final companion = AudioCacheCompanion.insert(
      source: source,
      sourceTrackId: sourceTrackId,
      filePath: resolvedPath,
      bytes: resolvedBytes,
      qualityId: qualityId,
      pinned: Value(pinned),
      cachedAt: now,
      lastAccessedAt: now,
      contentHash: Value(resolvedHash),
      // Absent when no cover is given, so an upsert never nulls an existing
      // companion cover (or resets its counted bytes).
      coverPath: coverPath == null ? const Value.absent() : Value(coverPath),
      coverBytes: coverPath == null ? const Value.absent() : Value(coverBytes),
    );
    final row = await _db
        .into(_db.audioCache)
        .insertReturning(
          companion,
          onConflict: DoUpdate(
            (_) => companion,
            target: [_db.audioCache.source, _db.audioCache.sourceTrackId],
          ),
        );
    return _toDomain(row);
  }

  /// Deletes the row for [id] and its file, unless another row still shares it.
  ///
  /// The row is removed even when the file is already gone.
  Future<void> remove(int id) async {
    await _resolveDir();
    final row = await (_db.select(
      _db.audioCache,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    await (_db.delete(_db.audioCache)..where((t) => t.id.equals(id))).go();
    await _deleteFileIfUnreferenced(row.filePath);
    _deleteCoverFile(row.coverPath);
  }

  /// Deletes every row and every file under the cache root.
  Future<void> clear() async {
    final base = await _resolveDir();
    await _db.delete(_db.audioCache).go();
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
          debugPrint('AudioCacheStore: failed to delete $entity: $error');
        }
      }
    } catch (error) {
      debugPrint('AudioCacheStore: clear failed: $error');
    }
  }

  /// Total bytes under the layer-1 quota: distinct audio files plus the
  /// companion-cover bytes of every row that still has a cover.
  ///
  /// Rows that share a [CachedAudio.filePath] (identical content deduplicated
  /// across logical keys) contribute their audio size a single time; each
  /// row's cover bytes count once while its [CachedAudio.coverPath] is set.
  Future<int> totalBytes() async {
    final query = _db.customSelect(
      'SELECT (SELECT COALESCE(SUM(bytes),0) FROM '
      '(SELECT DISTINCT file_path, bytes FROM audio_cache)) + '
      '(SELECT COALESCE(SUM(cover_bytes),0) FROM audio_cache '
      'WHERE cover_path IS NOT NULL) AS total',
      readsFrom: {_db.audioCache},
    );
    final row = await query.getSingle();
    return row.read<int>('total');
  }

  /// Every cached row, oldest `lastAccessedAt` first (LRU order).
  Future<List<CachedAudio>> entries() async {
    final rows =
        await (_db.select(_db.audioCache)..orderBy([
              (t) => OrderingTerm.asc(t.lastAccessedAt),
              (t) => OrderingTerm.asc(t.id),
            ]))
            .get();
    return rows.map(_toDomain).toList(growable: false);
  }

  /// Evicts cache entries until `used + incomingBytes <= limitBytes`, where
  /// `used` is the layer-1 footprint: audio bytes plus companion-cover bytes
  /// (see [totalBytes]).
  ///
  /// Eviction is row-based: a non-pinned row is removed oldest-first together
  /// with its companion cover, and both the audio and cover bytes it freed
  /// count toward the quota. Reads the current [CacheSettings] on every
  /// call, so a settings change applies immediately. Pinned entries are never
  /// evicted; when they alone exceed the limit,
  /// [EvictionResult.hasSpace] is `false`.
  ///
  /// Only files no other row references are deleted and counted as freed, so a
  /// physical file shared by two rows survives eviction of one of them.
  ///
  /// Never throws; a failure is logged and reported as no space.
  Future<EvictionResult> ensureSpace(int incomingBytes) async {
    var evictedCount = 0;
    var freedBytes = 0;
    try {
      await _resolveDir();
      final settings = await _settings.cacheSettings();
      final used = await totalBytes();

      if (used + incomingBytes <= settings.limitBytes) {
        return const EvictionResult(
          evictedCount: 0,
          freedBytes: 0,
          hasSpace: true,
        );
      }

      final candidates =
          await (_db.select(_db.audioCache)
                ..where((t) => t.pinned.equals(false))
                ..orderBy([
                  (t) => OrderingTerm.asc(t.lastAccessedAt),
                  (t) => OrderingTerm.asc(t.id),
                ]))
              .get();

      for (final candidate in candidates) {
        if (used - freedBytes + incomingBytes <= settings.limitBytes) break;
        await (_db.delete(
          _db.audioCache,
        )..where((t) => t.id.equals(candidate.id))).go();
        evictedCount++;
        final stillReferenced = await (_db.select(
          _db.audioCache,
        )..where((t) => t.filePath.equals(candidate.filePath))).get();
        if (stillReferenced.isEmpty) {
          _deleteFile(candidate.filePath);
          freedBytes += candidate.bytes;
        }
        // The companion cover is per-row; its bytes leave the quota with it.
        final coverPath = candidate.coverPath;
        if (coverPath != null) {
          _deleteCoverFile(coverPath);
          freedBytes += candidate.coverBytes;
        }
      }

      return EvictionResult(
        evictedCount: evictedCount,
        freedBytes: freedBytes,
        hasSpace: used - freedBytes + incomingBytes <= settings.limitBytes,
      );
    } catch (error) {
      debugPrint('AudioCacheStore: ensureSpace failed: $error');
      return EvictionResult(
        evictedCount: evictedCount,
        freedBytes: freedBytes,
        hasSpace: false,
      );
    }
  }

  /// Evicts non-pinned entries oldest-first until usage fits the configured cap.
  ///
  /// Used when the user lowers the cap; equivalent to [ensureSpace] with no
  /// incoming bytes.
  Future<EvictionResult> enforceLimit() => ensureSpace(0);

  /// Absolute path of the resolved cache root directory.
  Future<String> cacheDirectoryPath() async => (await _resolveDir()).path;

  /// Best-effort one-time repair for caches written before content hashing.
  ///
  /// Every row is ensured a content hash (its file is hashed when the column is
  /// `null` and the file still exists), then rows sharing a hash are collapsed
  /// onto one physical file: all sharing rows are pointed at the first file and
  /// the redundant copies are deleted. Returns the number of duplicate files
  /// removed. Never throws; failures are logged and the repair stops.
  Future<int> deduplicateByContent() async {
    await _resolveDir();
    var removed = 0;
    try {
      final rows = await _db.select(_db.audioCache).get();
      final canonicalByHash = <String, AudioCacheRow>{};
      for (final row in rows) {
        var hash = row.contentHash;
        if (hash == null) {
          hash = await _hashFile(row.filePath);
          if (hash == null) continue; // File gone; checkIntegrity removes it.
          await (_db.update(_db.audioCache)..where((t) => t.id.equals(row.id)))
              .write(AudioCacheCompanion(contentHash: Value(hash)));
        }
        if (!File(row.filePath).existsSync()) continue;

        final canonical = canonicalByHash[hash];
        if (canonical == null) {
          canonicalByHash[hash] = row;
          continue;
        }
        if (row.filePath == canonical.filePath) continue;
        await (_db.update(_db.audioCache)..where((t) => t.id.equals(row.id)))
            .write(AudioCacheCompanion(filePath: Value(canonical.filePath)));
        _deleteFile(row.filePath);
        removed++;
      }
    } catch (error) {
      debugPrint('AudioCacheStore: deduplicateByContent failed: $error');
    }
    return removed;
  }

  /// Reconciles the index with the filesystem.
  ///
  /// Removes rows whose file vanished and deletes files under the cache root
  /// that no row references. Files outside the cache root are never touched.
  Future<IntegrityReport> checkIntegrity() async {
    final base = await _resolveDir();
    var rowsRemoved = 0;
    var orphansRemoved = 0;
    try {
      final rows = await _db.select(_db.audioCache).get();
      final referenced = <String>{};
      for (final row in rows) {
        final file = File(row.filePath);
        if (file.existsSync()) {
          referenced.add(p.canonicalize(row.filePath));
          final cover = row.coverPath;
          if (cover != null && File(cover).existsSync()) {
            referenced.add(p.canonicalize(cover));
          }
        } else {
          await (_db.delete(
            _db.audioCache,
          )..where((t) => t.id.equals(row.id))).go();
          rowsRemoved++;
        }
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
            'AudioCacheStore: failed to delete orphan $entity: $error',
          );
        }
      }
    } catch (error) {
      debugPrint('AudioCacheStore: integrity check failed: $error');
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

  /// Deletes [path] only when it is inside the cache root; never throws.
  void _deleteFile(String path) {
    try {
      final base = _baseDir;
      if (base != null && !_isUnderBaseDir(path, base)) {
        debugPrint('AudioCacheStore: refusing to delete outside cache: $path');
        return;
      }
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (error) {
      debugPrint('AudioCacheStore: failed to delete $path: $error');
    }
  }

  /// Deletes a row's companion cover, best-effort; never throws.
  void _deleteCoverFile(String? path) {
    if (path == null) return;
    _deleteFile(path);
  }

  /// Deletes [path] unless another row still points at the same file.
  Future<void> _deleteFileIfUnreferenced(String path) async {
    final remaining = await (_db.select(
      _db.audioCache,
    )..where((t) => t.filePath.equals(path))).get();
    if (remaining.isEmpty) {
      _deleteFile(path);
    }
  }

  /// The first existing row with [contentHash] whose file is not [filePath].
  Future<AudioCacheRow?> _findByContentHash(
    String contentHash,
    String filePath,
  ) async {
    final rows = await (_db.select(
      _db.audioCache,
    )..where((t) => t.contentHash.equals(contentHash))).get();
    for (final row in rows) {
      if (row.filePath == filePath) continue;
      if (File(row.filePath).existsSync()) return row;
    }
    return null;
  }

  /// SHA-1 hex digest of [path]'s bytes, or `null` when the file is missing.
  ///
  /// Hashing runs in a background isolate so large audio files never block the
  /// UI isolate; only the path string crosses the isolate boundary.
  static Future<String?> _hashFile(String path) async {
    if (!File(path).existsSync()) return null;
    return Isolate.run(() async {
      final digest = await sha1.bind(File(path).openRead()).first;
      return digest.toString();
    });
  }

  bool _isUnderBaseDir(String path, Directory base) {
    final normalized = p.canonicalize(path);
    final basePath = p.canonicalize(base.path);
    return normalized == basePath || p.isWithin(basePath, normalized);
  }

  CachedAudio _toDomain(AudioCacheRow row) {
    return CachedAudio(
      id: row.id,
      source: row.source,
      sourceTrackId: row.sourceTrackId,
      filePath: row.filePath,
      bytes: row.bytes,
      qualityId: row.qualityId,
      pinned: row.pinned,
      cachedAt: DateTime.fromMillisecondsSinceEpoch(row.cachedAt),
      lastAccessedAt: DateTime.fromMillisecondsSinceEpoch(row.lastAccessedAt),
      contentHash: row.contentHash,
      coverPath: row.coverPath,
    );
  }
}
