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
  Future<CachedAudio> insert({
    required String source,
    required String sourceTrackId,
    required String filePath,
    required int bytes,
    required String qualityId,
    required bool pinned,
  }) async {
    await _resolveDir();
    final now = DateTime.now().millisecondsSinceEpoch;
    final companion = AudioCacheCompanion.insert(
      source: source,
      sourceTrackId: sourceTrackId,
      filePath: filePath,
      bytes: bytes,
      qualityId: qualityId,
      pinned: Value(pinned),
      cachedAt: now,
      lastAccessedAt: now,
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

  /// Deletes the row for [id] and its file.
  ///
  /// The row is removed even when the file is already gone.
  Future<void> remove(int id) async {
    await _resolveDir();
    final row = await (_db.select(
      _db.audioCache,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row != null) {
      _deleteFile(row.filePath);
    }
    await (_db.delete(_db.audioCache)..where((t) => t.id.equals(id))).go();
  }

  /// Deletes every row and every file it references.
  Future<void> clear() async {
    await _resolveDir();
    final rows = await _db.select(_db.audioCache).get();
    for (final row in rows) {
      _deleteFile(row.filePath);
    }
    await _db.delete(_db.audioCache).go();
  }

  /// Sum of the `bytes` column across every cached row.
  Future<int> totalBytes() async {
    final sum = _db.audioCache.bytes.sum();
    final query = _db.selectOnly(_db.audioCache)..addColumns([sum]);
    final row = await query.getSingle();
    return row.read(sum) ?? 0;
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

  /// Evicts non-pinned entries (oldest `lastAccessedAt` first) until
  /// `totalBytes() + incomingBytes <= limitBytes`.
  ///
  /// Reads the current [CacheSettings] on every call, so a settings change
  /// applies immediately. Pinned entries are never evicted; when they alone
  /// exceed the limit, [EvictionResult.hasSpace] is `false`.
  ///
  /// When caching is disabled ([CacheSettings.enabled] is `false`) nothing is
  /// evicted and `hasSpace` still reports whether the configured limit would
  /// have been respected. Callers are expected to skip caching entirely in
  /// that case; `ensureSpace` does not enforce the switch by itself.
  Future<EvictionResult> ensureSpace(int incomingBytes) async {
    await _resolveDir();
    final settings = await _settings.cacheSettings();
    final used = await totalBytes();

    if (!settings.enabled) {
      return EvictionResult(
        evictedCount: 0,
        freedBytes: 0,
        hasSpace: used + incomingBytes <= settings.limitBytes,
      );
    }

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

    var evictedCount = 0;
    var freedBytes = 0;
    for (final candidate in candidates) {
      if (used - freedBytes + incomingBytes <= settings.limitBytes) break;
      _deleteFile(candidate.filePath);
      await (_db.delete(
        _db.audioCache,
      )..where((t) => t.id.equals(candidate.id))).go();
      freedBytes += candidate.bytes;
      evictedCount++;
    }

    return EvictionResult(
      evictedCount: evictedCount,
      freedBytes: freedBytes,
      hasSpace: used - freedBytes + incomingBytes <= settings.limitBytes,
    );
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
    );
  }
}
