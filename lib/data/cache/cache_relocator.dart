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

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:flind_player/data/cache/audio_cache_store.dart';
import 'package:flind_player/data/cache/cover_cache_store.dart';
import 'package:flind_player/data/database/app_database.dart';

/// One-time best-effort move of cache files from the pre-v10 roots
/// (`audio_cache/`, `cover_cache/`) into the unified `cache/` subtrees.
///
/// `file_path` is authoritative: a file that cannot be moved keeps working
/// from its legacy path and is retried on the next start. Failures are logged
/// (`debugPrint`) and swallowed — relocation must never block startup or break
/// playback.
class CacheRelocator {
  /// Creates a relocator for the two legacy roots.
  CacheRelocator({
    required AppDatabase database,
    required AudioCacheStore audioStore,
    CoverCacheStore? coverStore,
    required Directory legacyAudioRoot,
    Directory? legacyCoverRoot,
  }) : _db = database,
       _audioStore = audioStore, // ignore: prefer_initializing_formals
       _coverStore = coverStore, // ignore: prefer_initializing_formals
       _legacyAudio = legacyAudioRoot,
       _legacyCover = legacyCoverRoot;

  final AppDatabase _db;
  final AudioCacheStore _audioStore;
  final CoverCacheStore? _coverStore;
  final Directory _legacyAudio;
  final Directory? _legacyCover;

  /// Moves every DB-referenced file out of both legacy roots.
  Future<void> relocate() async {
    await _relocateAudio();
    await _relocateCovers();
  }

  Future<void> _relocateAudio() async {
    try {
      if (!_legacyAudio.existsSync()) return;
      final rows = await _db.select(_db.audioCache).get();
      for (final row in rows) {
        if (!p.isWithin(_legacyAudio.path, row.filePath)) continue;
        // One stuck row must not abort the remaining ones; `file_path` stays
        // authoritative for it and the next start retries.
        try {
          final relative = p.relative(row.filePath, from: _legacyAudio.path);
          final target = File(
            p.join(await _audioStore.cacheDirectoryPath(), relative),
          );
          final movedCover = await _moveAndRewrite(
            row.filePath,
            target,
            row.coverPath,
          );
          await (_db.update(_db.audioCache)..where((t) => t.id.equals(row.id)))
              .write(
                AudioCacheCompanion(
                  filePath: Value(target.path),
                  // Rewritten only when the companion cover actually moved;
                  // otherwise the recorded path stays valid as-is.
                  coverPath: movedCover == null
                      ? const Value.absent()
                      : Value(movedCover),
                ),
              );
        } catch (error) {
          debugPrint(
            'CacheRelocator: audio row ${row.id} relocation failed: $error',
          );
        }
      }
    } catch (error) {
      debugPrint('CacheRelocator: audio relocation failed: $error');
    }
  }

  Future<void> _relocateCovers() async {
    final legacy = _legacyCover;
    final store = _coverStore;
    if (legacy == null || store == null) return;
    try {
      if (!legacy.existsSync()) return;
      final rows = await _db.select(_db.coverCache).get();
      for (final row in rows) {
        if (!p.isWithin(legacy.path, row.filePath)) continue;
        try {
          final relative = p.relative(row.filePath, from: legacy.path);
          final target = File(p.join(await store.cacheDirectoryPath(), relative));
          await _moveAndRewrite(row.filePath, target, null);
          await (_db.update(_db.coverCache)..where((t) => t.id.equals(row.id)))
              .write(CoverCacheCompanion(filePath: Value(target.path)));
        } catch (error) {
          debugPrint(
            'CacheRelocator: cover row ${row.id} relocation failed: $error',
          );
        }
      }
    } catch (error) {
      debugPrint('CacheRelocator: cover relocation failed: $error');
    }
  }

  /// Moves [from] to [target] and, when [companion] sits under the legacy
  /// audio root, moves it beside the audio file. Returns the companion's new
  /// path when it moved (so the caller can rewrite `cover_path`), otherwise
  /// `null`.
  Future<String?> _moveAndRewrite(
    String from,
    File target,
    String? companion,
  ) async {
    final source = File(from);
    if (source.existsSync()) {
      target.parent.createSync(recursive: true);
      try {
        await source.rename(target.path);
      } on FileSystemException {
        // Cross-device or locked: copy then delete.
        target.writeAsBytesSync(source.readAsBytesSync(), flush: true);
        source.deleteSync();
      }
    }
    if (companion == null || !p.isWithin(_legacyAudio.path, companion)) {
      return null;
    }
    try {
      final coverSource = File(companion);
      final coverTarget = File(
        p.join(p.dirname(target.path), p.basename(companion)),
      );
      if (!coverSource.existsSync()) {
        // Already moved by an earlier run whose row update failed.
        return coverTarget.existsSync() ? coverTarget.path : null;
      }
      coverTarget.parent.createSync(recursive: true);
      try {
        await coverSource.rename(coverTarget.path);
      } on FileSystemException {
        coverTarget.writeAsBytesSync(coverSource.readAsBytesSync(), flush: true);
        coverSource.deleteSync();
      }
      return coverTarget.path;
    } catch (error) {
      // The audio file already moved; a stuck cover keeps its legacy path
      // (still valid) and is retried on the next start.
      debugPrint('CacheRelocator: companion cover move failed: $error');
      return null;
    }
  }
}
