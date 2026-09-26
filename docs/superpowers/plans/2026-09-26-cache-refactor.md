# Cache Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the offline/online cache from per-asset-type quota to per-song quota: a cached song's audio and cover live and die together in layer 1, while covers for un-cached songs live in a separate session-scoped layer 2.

**Architecture:** `audio_cache` becomes a "song asset row" (audio + `cover_path`), evicted row-at-a-time under the user's `limitBytes` (pinned rows exempt). `cover_cache` is narrowed to layer 2 (un-cached songs), with a fixed 256 MiB cap and a startup wipe. Both stores sit under one `<app support>/cache/` root but in non-overlapping subtrees (`audio/` and `cover/`) so neither store's recursive cleanup can touch the other's files.

**Tech Stack:** Flutter, Dart, `drift` (SQLite), `flutter_riverpod`, `dio`, `shared_preferences`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-09-26-cache-refactor-design.md`

## Global Constraints

- Every Dart source file keeps the GPL-3.0 header comment (copy the block already at the top of the file being edited).
- Degradation discipline: cache failures are logged (`debugPrint`) and swallowed; they must never break playback, a scan, or a download.
- `flutter analyze` must report 0 errors after every task.
- `flutter test` must stay green after every task.
- Cache key convention stays `bvid:cid` for Bilibili / absolute path for local (`cacheSourceTrackId`).
- `audio_cache` table name is unchanged; add a doc comment describing it as the song asset row.
- Layer 1 quota is the user's `CacheSettings.limitBytes`; pinned rows are exempt. Layer 2 quota is the fixed constant `CoverCacheStore.ephemeralLimitBytes` (256 MiB) and is not user-configurable.
- Layer 2 is wiped on every app start.
- New storage subtrees: `<app support>/cache/audio/` (layer 1) and `<app support>/cache/cover/` (layer 2). They must never overlap.

## Review Focus

- **Subtree isolation:** layer 1's recursive `clear()` / orphan sweep must never delete a file under `cache/cover/` (layer 2), and vice versa.
- **Shared audio file:** evicting a layer-1 row whose `file_path` is shared with another row (content dedup) must not delete the shared file.
- **Dangling cover path:** after a layer-1 eviction, `tracks.cover_path` points at a deleted file; the UI/`CoverService` must treat it as absent, not crash.
- **Offline cover:** a pinned download whose cover cannot be fetched must still complete successfully (cover is best-effort).
- **Restart survival:** layer 2 is wiped on start, but a cached song's layer-1 cover must survive the restart.

---

### Task 1: Schema v10 — `cover_path` column and P3 indices

**Files:**
- Modify: `lib/data/database/tables.dart` (AudioCache ~106-144, CoverCache ~238-263)
- Modify: `lib/data/database/app_database.dart` (schemaVersion line 42; onUpgrade after the `from < 9` block)
- Regenerate: `lib/data/database/app_database.g.dart`
- Test: `test/drift_music_library_repository_test.dart` (append to the `schema migration` group, after the v8→v9 test)

**Interfaces:**
- Produces: `AudioCacheRow.coverPath` (`String?`), `AudioCacheCompanion.coverPath` (`Value<String?>`); generated `Index` fields `idxAudioCacheContentHash`, `idxAudioCacheFilePath`, `idxCoverCacheContentHash`, `idxCoverCacheFilePath`.

- [ ] **Step 1: Write the failing migration test**

Append inside the `schema migration` group in `test/drift_music_library_repository_test.dart`:

```dart
    test('v9 -> v10 adds cover_path and the cache lookup indexes', () async {
      final dir = Directory.systemTemp.createTempSync('flind_migration_v10');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      final file = File('${dir.path}/library.sqlite');

      // Build a current-schema file, then roll it back to v9 by dropping the
      // column and indexes v10 introduces.
      final before = AppDatabase(NativeDatabase(file));
      await before.customStatement(
        'INSERT INTO audio_cache '
        '(source, source_track_id, file_path, bytes, quality_id, pinned, '
        'cached_at, last_accessed_at) '
        "VALUES ('bilibili', 'BV1:1', '/tmp/x.m4a', 10, '30280', 0, 1, 1)",
      );
      await before.customStatement(
        'ALTER TABLE audio_cache DROP COLUMN cover_path',
      );
      await before.customStatement(
        'DROP INDEX IF EXISTS idx_audio_cache_content_hash',
      );
      await before.customStatement(
        'DROP INDEX IF EXISTS idx_audio_cache_file_path',
      );
      await before.customStatement(
        'DROP INDEX IF EXISTS idx_cover_cache_content_hash',
      );
      await before.customStatement(
        'DROP INDEX IF EXISTS idx_cover_cache_file_path',
      );
      await before.customStatement('PRAGMA user_version = 9');
      await before.close();

      final after = AppDatabase(NativeDatabase(file));
      addTearDown(after.close);

      // The existing row survives, defaults to a null cover, and the new
      // indexes exist.
      final row = await after
          .customSelect('SELECT cover_path FROM audio_cache')
          .getSingle();
      expect(row.data['cover_path'], isNull);

      final indexes = await after
          .customSelect("SELECT name FROM sqlite_master WHERE type='index'")
          .get();
      final names = indexes.map((r) => r.data['name']).toSet();
      expect(names, contains('idx_audio_cache_content_hash'));
      expect(names, contains('idx_audio_cache_file_path'));
      expect(names, contains('idx_cover_cache_content_hash'));
      expect(names, contains('idx_cover_cache_file_path'));

      // Re-running the migration is safe.
      await after.close();
      final again = AppDatabase(NativeDatabase(file));
      addTearDown(again.close);
      expect(
        await again.customSelect('SELECT COUNT(*) AS n FROM audio_cache').getSingle(),
        isNotNull,
      );
    });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/drift_music_library_repository_test.dart --plain-name "v9 -> v10"`
Expected: FAIL (v10 indexes/column not created; migration is a no-op).

- [ ] **Step 3: Add the column and indices to the drift tables**

In `lib/data/database/tables.dart`, update the `AudioCache` class annotations and body. Add two `@TableIndex.sql` annotations and the `coverPath` column, and update the class doc:

```dart
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
class AudioCache extends Table {
  // ... existing columns unchanged ...
  /// Absolute path of the song's companion cover, or `null` when none.
  TextColumn get coverPath => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {source, sourceTrackId},
  ];
}
```

Update the `CoverCache` class annotations:

```dart
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
  // ... unchanged ...
}
```

- [ ] **Step 4: Add the v10 migration**

In `lib/data/database/app_database.dart`, change `int get schemaVersion => 9;` to `10;` and add after the `if (from < 9) { ... }` block:

```dart
      if (from < 10) {
        // v9 had no companion-cover column nor the cache lookup indexes. The
        // column is guarded (addColumn is not idempotent); createIndex emits
        // IF NOT EXISTS.
        await _addColumnIfMissing(m, audioCache, audioCache.coverPath);
        await m.createIndex(idxAudioCacheContentHash);
        await m.createIndex(idxAudioCacheFilePath);
        await m.createIndex(idxCoverCacheContentHash);
        await m.createIndex(idxCoverCacheFilePath);
      }
```

- [ ] **Step 5: Regenerate drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: regenerates `lib/data/database/app_database.g.dart` with `coverPath`, `idxAudioCacheContentHash`, etc.

- [ ] **Step 6: Run the migration test and the database tests**

Run: `flutter test test/drift_music_library_repository_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/data/database/tables.dart lib/data/database/app_database.dart lib/data/database/app_database.g.dart test/drift_music_library_repository_test.dart
git commit -m "feat(cache): schema v10 adds cover_path and lookup indexes"
```

---

### Task 2: Layer 1 — `AudioCacheStore` owns the companion cover and evicts by row

**Files:**
- Modify: `lib/data/cache/audio_cache_store.dart`
- Test: `test/audio_cache_store_test.dart`

**Interfaces:**
- Consumes: `AudioCacheRow.coverPath` (Task 1).
- Produces:
  - `CachedAudio.coverPath` (`String?`).
  - `AudioCacheStore.insert({..., String? coverPath})`.
  - `AudioCacheStore.coverFileFor({required String source, required String sourceTrackId, required String extension})` → `File` at `<base>/<source>/<sha1("$source:$sourceTrackId")>.cover.<ext>`.
  - `AudioCacheStore.setCoverPath(int id, String? path)`.
  - `AudioCacheStore.remove(int id)` deletes the companion cover too.
  - `AudioCacheStore.ensureSpace(int incomingBytes)` no longer reads `cover_cache`; evicts non-pinned audio rows (with their covers).

- [ ] **Step 1: Write failing tests**

In `test/audio_cache_store_test.dart`, add to the `insert / lookup / touch` group:

```dart
    test('round-trips a companion cover path', () async {
      final file = store.fileFor(
        source: 'bilibili',
        sourceTrackId: 'BV1:1',
        extension: 'm4a',
      );
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(const [1, 2, 3]);
      final cover = store.coverFileFor(
        source: 'bilibili',
        sourceTrackId: 'BV1:1',
        extension: 'jpg',
      )..writeAsBytesSync(const [9, 9]);

      final entry = await store.insert(
        source: 'bilibili',
        sourceTrackId: 'BV1:1',
        filePath: file.path,
        bytes: 3,
        qualityId: '30280',
        pinned: false,
        coverPath: cover.path,
      );

      expect(entry.coverPath, cover.path);
      expect((await store.lookup('bilibili', 'BV1:1'))!.coverPath, cover.path);
    });
```

Add to the `remove / clear` group:

```dart
    test('remove deletes the companion cover too', () async {
      final entry = await addEntry('a', bytes: 100);
      final cover = store.coverFileFor(
        source: 'bilibili',
        sourceTrackId: 'a',
        extension: 'jpg',
      )..writeAsBytesSync(const [1]);
      await store.setCoverPath(entry.id, cover.path);

      await store.remove(entry.id);

      expect(File(cover.path).existsSync(), isFalse);
    });

    test('clear deletes companion covers too', () async {
      final entry = await addEntry('a', bytes: 100);
      final cover = store.coverFileFor(
        source: 'bilibili',
        sourceTrackId: 'a',
        extension: 'jpg',
      )..writeAsBytesSync(const [1]);
      await store.setCoverPath(entry.id, cover.path);

      await store.clear();

      expect(File(cover.path).existsSync(), isFalse);
    });
```

Add to the `ensureSpace` group:

```dart
    test('evicting a row also deletes its companion cover', () async {
      settings.current = CacheSettings.defaults.copyWith(limitBytes: 1000);
      final entry = await addEntry('a', bytes: 400, lastAccessedAt: 1000);
      final cover = store.coverFileFor(
        source: 'bilibili',
        sourceTrackId: 'a',
        extension: 'jpg',
      )..writeAsBytesSync(const [1]);
      await store.setCoverPath(entry.id, cover.path);
      await addEntry('b', bytes: 400, lastAccessedAt: 2000);

      final result = await store.ensureSpace(400);

      expect(result.hasSpace, isTrue);
      expect(File(cover.path).existsSync(), isFalse);
      expect(await store.lookup('bilibili', 'a'), isNull);
    });
```

Add to the `checkIntegrity` group:

```dart
    test('a companion cover is not treated as an orphan', () async {
      final entry = await addEntry('a', bytes: 100);
      final cover = store.coverFileFor(
        source: 'bilibili',
        sourceTrackId: 'a',
        extension: 'jpg',
      )..writeAsBytesSync(const [1]);
      await store.setCoverPath(entry.id, cover.path);

      final report = await store.checkIntegrity();

      expect(report.orphansRemoved, 0);
      expect(File(cover.path).existsSync(), isTrue);
    });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/audio_cache_store_test.dart`
Expected: FAIL (no `coverFileFor`, `setCoverPath`, `coverPath`).

- [ ] **Step 3: Implement the store changes**

In `lib/data/cache/audio_cache_store.dart`:

1. Add `coverPath` to `CachedAudio` (constructor, field, `_toDomain`).
2. Add the constructor param and companion value in `insert`:

```dart
  Future<CachedAudio> insert({
    required String source,
    required String sourceTrackId,
    required String filePath,
    required int bytes,
    required String qualityId,
    required bool pinned,
    String? contentHash,
    String? coverPath,
  }) async {
    // ... existing dedup logic unchanged ...
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
      coverPath: Value(coverPath),
    );
    // ... unchanged ...
  }
```

3. Add `coverFileFor` and `setCoverPath`:

```dart
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

  /// Records the companion cover path for the row [id].
  Future<void> setCoverPath(int id, String? path) async {
    await (_db.update(_db.audioCache)..where((t) => t.id.equals(id))).write(
      AudioCacheCompanion(coverPath: Value(path)),
    );
  }
```

4. Delete `_coverCacheBytes()` and remove the cover-eviction loop and `_deleteCoverFile` from `ensureSpace`; the method becomes audio-only:

```dart
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
        _deleteCoverFile(candidate.coverPath);
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
```

5. In `remove`, delete the companion cover after the row is gone:

```dart
    await (_db.delete(_db.audioCache)..where((t) => t.id.equals(id))).go();
    await _deleteFileIfUnreferenced(row.filePath);
    _deleteCoverFile(row.coverPath);
```

6. In `checkIntegrity`, add cover paths to `referenced` so they are not swept as orphans:

```dart
        if (file.existsSync()) {
          referenced.add(p.canonicalize(row.filePath));
          final cover = row.coverPath;
          if (cover != null && File(cover).existsSync()) {
            referenced.add(p.canonicalize(cover));
          }
        } else {
          // row removed as before
        }
```

7. Keep `_deleteCoverFile` but simplify its doc: it now deletes a companion cover inside the audio base; change it to use `_deleteFile` (which has the containment guard) and delete the method's special-casing:

```dart
  /// Deletes a row's companion cover, best-effort; never throws.
  void _deleteCoverFile(String? path) {
    if (path == null) return;
    _deleteFile(path);
  }
```

- [ ] **Step 4: Run the store tests**

Run: `flutter test test/audio_cache_store_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/data/cache/audio_cache_store.dart test/audio_cache_store_test.dart
git commit -m "refactor(cache): layer 1 owns companion cover and evicts by row"
```

---

### Task 3: Layer 2 — `CoverCacheStore` gets an independent fixed quota

**Files:**
- Modify: `lib/data/cache/cover_cache_store.dart`
- Modify: `lib/data/providers/cover_providers.dart` (drop the `settings` argument)
- Test: `test/cover_cache_store_test.dart`

**Interfaces:**
- Consumes: `AudioCacheStore` no longer; `CoverCacheStore` no longer takes `settings`.
- Produces: `CoverCacheStore.ephemeralLimitBytes` (`static const int`, 256 MiB); `CoverCacheStore.ensureSpace` uses only its own bytes.

- [ ] **Step 1: Write failing tests**

Rewrite the `ensureSpace` group in `test/cover_cache_store_test.dart` (delete the two audio-cross-referencing tests and replace with layer-2-only tests):

```dart
  group('ensureSpace', () {
    test('evicts the oldest cover to make room', () async {
      await addCover('old', 'hash-old', bytes: 100, lastAccessedAt: 1000);
      await addCover('new', 'hash-new', bytes: 100, lastAccessedAt: 2000);

      final result = await store.ensureSpace(
        CoverCacheStore.ephemeralLimitBytes - 100,
      );

      expect(result.hasSpace, isTrue);
      expect(result.evictedCount, 1);
      expect(await store.lookup('old'), isNull);
      expect(await store.lookup('new'), isNotNull);
    });

    test('does not read the user cache limit', () async {
      // A tiny user limit must not evict layer-2 covers.
      settings.current = CacheSettings.defaults.copyWith(limitBytes: 1);
      await addCover('a', 'hash-a', bytes: 100);

      final result = await store.ensureSpace(0);

      expect(result.hasSpace, isTrue);
      expect(result.evictedCount, 0);
      expect(await store.lookup('a'), isNotNull);
    });
  });
```

Remove the `addAudio` helper and the `audio_cache_store.dart` import if now unused.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/cover_cache_store_test.dart`
Expected: FAIL (`ephemeralLimitBytes` undefined; the tiny user limit currently evicts).

- [ ] **Step 3: Implement the independent quota**

In `lib/data/cache/cover_cache_store.dart`:

1. Remove `_settings` field, the `settings` constructor parameter (both constructors), and the `SettingsRepository` import.
2. Add the constant:

```dart
  /// Fixed byte cap for the session-scoped cover cache (256 MiB).
  ///
  /// Not user-configurable; the cache is wiped on every app start.
  static const int ephemeralLimitBytes = 256 * 1024 * 1024;
```

3. Replace `_combinedBytes()` usage in `ensureSpace` with `totalBytes()` and `settings.limitBytes` with `ephemeralLimitBytes`; delete `_combinedBytes()` and `_audioCacheBytes()`.

4. Update the class doc to say "layer 2: covers for un-cached songs only; wiped on start".

In `lib/data/providers/cover_providers.dart`, drop `settings:` from the `CoverCacheStore.lazy(...)` call.

Also update every construction site of `CoverCacheStore(...)` that still passes `settings:` — at minimum the `setUp` in `test/cover_cache_store_test.dart` (drop the argument; the `settings` fake may stay for other assertions) and the `setUp` in `test/cover_service_test.dart` (Task 4 rewrites this anyway).

- [ ] **Step 4: Run the cover store tests**

Run: `flutter test test/cover_cache_store_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/data/cache/cover_cache_store.dart lib/data/providers/cover_providers.dart test/cover_cache_store_test.dart
git commit -m "refactor(cache): layer 2 cover cache gets an independent fixed quota"
```

---

### Task 4: `CoverService` routes by cache layer

**Files:**
- Create: `lib/data/cache/cache_keys.dart`
- Modify: `lib/data/cache/download_manager.dart` (re-export `cache_keys.dart`, remove local definition)
- Modify: `lib/data/services/cover_service.dart`
- Modify: `lib/data/providers/cover_providers.dart`
- Test: `test/cover_service_test.dart`

**Interfaces:**
- Consumes: `AudioCacheStore.lookup`, `coverFileFor`, `setCoverPath` (Task 2); `CoverCacheStore` (Task 3).
- Produces: `CoverService({required CoverCacheStore store, required AudioCacheStore audioStore, ...})`.

- [ ] **Step 1: Extract the cache key helper**

Create `lib/data/cache/cache_keys.dart` with the GPL header and the existing function moved verbatim from `download_manager.dart`:

```dart
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/source_track_id.dart';

/// Canonical `audio_cache.source_track_id` value for [track].
///
/// `bvid:cid` for Bilibili and the absolute path for local files. The download
/// manager and the cache-first resolver must agree on this key or lookups miss.
String cacheSourceTrackId(Track track) {
  final id = track.sourceTrackId;
  if (id is BiliTrackId) return '${id.bvid}:${id.cid}';
  if (id is LocalTrackId) return id.path;
  return id.toString();
}
```

In `download_manager.dart`, delete the local definition and add `export 'cache_keys.dart';` near the imports so existing importers keep working.

- [ ] **Step 2: Write failing cover-service tests**

In `test/cover_service_test.dart`, extend the `setUp` to build an `AudioCacheStore` and pass it in, then add:

```dart
    test('stores a cover in layer 1 when the song is already cached', () async {
      final audio = AudioCacheStore(
        database: db,
        baseDir: root,
        settings: _FakeSettingsRepository(),
      );
      final audioFile = audio.fileFor(
        source: 'bilibili',
        sourceTrackId: 'BV1GJ411x7h7:137649199',
        extension: 'm4a',
      );
      audioFile.parent.createSync(recursive: true);
      audioFile.writeAsBytesSync(const [1, 2, 3]);
      final entry = await audio.insert(
        source: 'bilibili',
        sourceTrackId: 'BV1GJ411x7h7:137649199',
        filePath: audioFile.path,
        bytes: 3,
        qualityId: '30280',
        pinned: true,
      );
      final service = CoverService(
        store: CoverCacheStore(database: db, baseDir: root),
        audioStore: audio,
        downloader: downloader,
        library: library,
        resolveRemoteUrl: (bvid) async => '//i0.hdslb.com/bfs/resolved.jpg',
      );

      final path = await service.ensureCover(_biliTrack(coverUrl: '//i0.hdslb.com/bfs/a.jpg'));

      expect(path, isNotNull);
      expect((await audio.lookup('bilibili', 'BV1GJ411x7h7:137649199'))!.coverPath, path);
    });
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `flutter test test/cover_service_test.dart`
Expected: FAIL (`audioStore` parameter undefined).

- [ ] **Step 4: Implement the routing**

In `lib/data/services/cover_service.dart`:

1. Add `required AudioCacheStore audioStore` to the constructor and store `_audioStore`.
2. In `_downloadAndStore(url, urlHash)`, after decode-validation, branch on whether the track's audio is cached. Pass the track through:

```dart
  Future<String?> _downloadAndStore(
    String url,
    String urlHash,
    Track track,
  ) async {
    final bytes = await _downloader.download(url);
    if (bytes == null) return null;
    final decodable = await Isolate.run(() => isDecodableImage(bytes));
    if (!decodable) return null;

    final cachedAudio = await _cachedAudioFor(track);
    if (cachedAudio != null) {
      // Layer 1: the cover travels with the cached song.
      final extension = _extensionFor(bytes);
      final cover = _audioStore.coverFileFor(
        source: track.source,
        sourceTrackId: cacheSourceTrackId(track),
        extension: extension,
      );
      cover.parent.createSync(recursive: true);
      cover.writeAsBytesSync(bytes, flush: true);
      await _audioStore.setCoverPath(cachedAudio.id, cover.path);
      // The companion cover adds to layer 1's footprint; re-enforce the cap.
      await _audioStore.enforceLimit();
      return cover.path;
    }

    // Layer 2: session-scoped cover for an un-cached song.
    final eviction = await _store.ensureSpace(bytes.length);
    if (!eviction.hasSpace) return null;
    return _store.insert(
      urlHash: urlHash,
      contentHash: _sha1Bytes(bytes),
      bytes: bytes,
    );
  }

  Future<CachedAudio?> _cachedAudioFor(Track track) async {
    try {
      final entry = await _audioStore.lookup(
        track.source,
        cacheSourceTrackId(track),
      );
      if (entry == null) return null;
      return File(entry.filePath).existsSync() ? entry : null;
    } catch (error) {
      debugPrint('CoverService: audio cache lookup failed: $error');
      return null;
    }
  }

  /// Picks a file extension from the image's magic bytes; defaults to `jpg`.
  static String _extensionFor(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'png';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'webp';
    }
    return 'jpg';
  }
```

3. Update the `_storeDownload` call site to pass `track`, and update the doc comment to describe the two layers.

In `lib/data/providers/cover_providers.dart`, pass `audioStore: ref.watch(audioCacheStoreProvider)` into `CoverService`.

- [ ] **Step 5: Run the cover-service tests**

Run: `flutter test test/cover_service_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/data/cache/cache_keys.dart lib/data/cache/download_manager.dart lib/data/services/cover_service.dart lib/data/providers/cover_providers.dart test/cover_service_test.dart
git commit -m "feat(cache): route covers to layer 1 or layer 2 by audio cache state"
```

---

### Task 5: `DownloadManager` ensures the companion cover for offline downloads

**Files:**
- Modify: `lib/data/cache/download_manager.dart`
- Modify: `lib/data/providers/cache_providers.dart`
- Test: `test/download_manager_cover_test.dart` (create)

**Interfaces:**
- Consumes: `CoverService.ensureCover(Track)` (Task 4).
- Produces: `DownloadManager({..., Future<void> Function(Track track)? ensureCover})`.

- [ ] **Step 1: Write the failing test**

Create `test/download_manager_cover_test.dart`:

```dart
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/music_source.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/core/sources/stream_resolver.dart';
import 'package:flind_player/data/cache/audio_cache_store.dart';
import 'package:flind_player/data/cache/audio_downloader.dart';
import 'package:flind_player/data/cache/download_manager.dart';
import 'package:flind_player/data/database/app_database.dart';

import 'audio_cache_store_test.dart' show FakeSettingsRepository;

class _StubResolver implements StreamResolver {
  @override
  Future<StreamInfo> resolve(Track track) async =>
      StreamInfo(url: Uri.parse('https://cdn.example/audio.m4a'));
}

class _StubDownloader extends AudioDownloader {
  _StubDownloader() : super(sleeper: (_) async {});

  @override
  Future<int> download({
    required Uri url,
    required Map<String, String> headers,
    required File target,
    void Function(int received, int? total)? onProgress,
  }) async {
    target.parent.createSync(recursive: true);
    target.writeAsBytesSync(const [1, 2, 3, 4]);
    return 4;
  }
}

void main() {
  test('a pinned download invokes ensureCover once after success', () async {
    final root = Directory.systemTemp.createTempSync('flind_dl_cover');
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final covers = <Track>[];
    final manager = DownloadManager(
      store: AudioCacheStore(
        database: db,
        baseDir: root,
        settings: FakeSettingsRepository(),
      ),
      downloader: _StubDownloader(),
      resolver: _StubResolver(),
      ensureCover: (track) async => covers.add(track),
    );
    addTearDown(manager.dispose);

    const track = Track(
      source: 'bilibili',
      sourceTrackId: BiliTrackId(bvid: 'BV1', cid: 1),
      uri: 'bilibili:BV1:1',
      title: 'Song',
    );

    await manager.cacheTrack(track, pinned: true);

    expect(covers.single, track);
  });
}
```

> Note: `FakeSettingsRepository` does not exist yet. In Task 2 or here, rename the existing private `_FakeSettingsRepository` in `test/audio_cache_store_test.dart` to public `FakeSettingsRepository` so it can be shared. Do that in Step 3.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/download_manager_cover_test.dart`
Expected: FAIL (`ensureCover` parameter undefined).

- [ ] **Step 3: Implement and share the fake**

1. In `test/audio_cache_store_test.dart`, rename `_FakeSettingsRepository` to `FakeSettingsRepository` (and all references). Same in `test/cover_cache_store_test.dart` and `test/cover_service_test.dart` if you want to reuse it there.
2. In `lib/data/cache/download_manager.dart`, add the optional callback:

```dart
  DownloadManager({
    required AudioCacheStore store,
    required AudioDownloader downloader,
    required StreamResolver resolver,
    Future<void> Function(Track track)? ensureCover,
  }) : _store = store,
       _downloader = downloader,
       _resolver = resolver,
       _ensureCover = ensureCover;

  final Future<void> Function(Track track)? _ensureCover;
```

3. In `_run`, after the successful `insert` and before the final `_emit(task, DownloadPhase.done, ...)`, add:

```dart
    if (task.pinned) {
      // Offline downloads must carry their cover into layer 1, or the song
      // loses its artwork once layer 2 is wiped on the next start. Best-effort:
      // a missing cover never fails the download.
      try {
        await _ensureCover?.call(track);
      } catch (error) {
        debugPrint('DownloadManager: companion cover failed: $error');
      }
    }
```

4. In `lib/data/providers/cache_providers.dart`, wire it — but `downloadManagerProvider` must not depend on `coverServiceProvider` (which itself depends on `downloadManagerProvider` transitively? Check: `coverServiceProvider` depends on `audioCacheStoreProvider`, `coverCacheStoreProvider`, `musicLibraryRepositoryProvider`, `biliApiProvider` — not on `downloadManagerProvider`). So add `ensureCover: (track) => ref.read(coverServiceProvider).ensureCover(track)`, importing `cover_providers.dart`. If a provider cycle appears, instead pass the callback at the call site in `cache_action_button.dart` / `track_actions_button.dart`.

- [ ] **Step 4: Run the test**

Run: `flutter test test/download_manager_cover_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/data/cache/download_manager.dart lib/data/providers/cache_providers.dart test/download_manager_cover_test.dart test/audio_cache_store_test.dart
git commit -m "feat(cache): offline downloads materialize the companion cover"
```

---

### Task 6: Wiring — single cache root, startup wipe of layer 2, legacy relocation

**Files:**
- Modify: `lib/data/providers/cache_providers.dart`
- Modify: `lib/data/providers/cover_providers.dart`
- Modify: `lib/main.dart`
- Create: `lib/data/cache/cache_relocator.dart`
- Test: `test/cache_relocator_test.dart` (create)

**Interfaces:**
- Consumes: both stores, their `cacheDirectoryPath()`.
- Produces: `CacheRelocator.relocate()` → `Future<void>`; providers rooted at `<support>/cache/audio` and `<support>/cache/cover`.

- [ ] **Step 1: Write the failing relocator test**

Create `test/cache_relocator_test.dart`:

```dart
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/data/cache/audio_cache_store.dart';
import 'package:flind_player/data/cache/cache_relocator.dart';
import 'package:flind_player/data/database/app_database.dart';

import 'audio_cache_store_test.dart' show FakeSettingsRepository;

void main() {
  test('moves legacy audio files into the new root and rewrites paths', () async {
    final dir = Directory.systemTemp.createTempSync('flind_relocate');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final legacy = Directory('${dir.path}/audio_cache')..createSync();
    final newRoot = Directory('${dir.path}/cache/audio');
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    // A row pointing at the legacy root.
    final legacyFile = File('${legacy.path}/bilibili/abc.m4a')
      ..createSync(recursive: true)
      ..writeAsBytesSync(const [1, 2, 3]);
    await db.into(db.audioCache).insert(
      AudioCacheCompanion.insert(
        source: 'bilibili',
        sourceTrackId: 'BV1:1',
        filePath: legacyFile.path,
        bytes: 3,
        qualityId: '30280',
        cachedAt: 1,
        lastAccessedAt: 1,
      ),
    );

    final store = AudioCacheStore(
      database: db,
      baseDir: newRoot,
      settings: FakeSettingsRepository(),
    );
    await CacheRelocator(
      database: db,
      audioStore: store,
      legacyAudioRoot: legacy,
    ).relocate();

    final row = (await store.lookup('bilibili', 'BV1:1'))!;
    expect(row.filePath, startsWith(newRoot.path));
    expect(File(row.filePath).existsSync(), isTrue);
    expect(legacyFile.existsSync(), isFalse);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/cache_relocator_test.dart`
Expected: FAIL (`cache_relocator.dart` missing).

- [ ] **Step 3: Implement `CacheRelocator`**

Create `lib/data/cache/cache_relocator.dart` (GPL header included):

```dart
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
/// from its legacy path and is retried on the next start.
class CacheRelocator {
  CacheRelocator({
    required AppDatabase database,
    required AudioCacheStore audioStore,
    CoverCacheStore? coverStore,
    required Directory legacyAudioRoot,
    Directory? legacyCoverRoot,
  }) : _db = database,
       _audioStore = audioStore,
       _coverStore = coverStore,
       _legacyAudio = legacyAudioRoot,
       _legacyCover = legacyCoverRoot;

  final AppDatabase _db;
  final AudioCacheStore _audioStore;
  final CoverCacheStore? _coverStore;
  final Directory _legacyAudio;
  final Directory? _legacyCover;

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
        final relative = p.relative(row.filePath, from: _legacyAudio.path);
        final target = File(p.join((await _audioStore.cacheDirectoryPath()), relative));
        await _moveAndRewrite(row.filePath, target, row.coverPath);
        await (_db.update(_db.audioCache)..where((t) => t.id.equals(row.id)))
            .write(AudioCacheCompanion(filePath: Value(target.path)));
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
        final relative = p.relative(row.filePath, from: legacy.path);
        final target = File(p.join(await store.cacheDirectoryPath(), relative));
        await _moveAndRewrite(row.filePath, target, null);
        await (_db.update(_db.coverCache)..where((t) => t.id.equals(row.id)))
            .write(CoverCacheCompanion(filePath: Value(target.path)));
      }
    } catch (error) {
      debugPrint('CacheRelocator: cover relocation failed: $error');
    }
  }

  Future<void> _moveAndRewrite(
    String from,
    File target,
    String? companion,
  ) async {
    final source = File(from);
    if (!source.existsSync()) return;
    target.parent.createSync(recursive: true);
    try {
      await source.rename(target.path);
    } on FileSystemException {
      // Cross-device or locked: copy then delete.
      target.writeAsBytesSync(source.readAsBytesSync(), flush: true);
      source.deleteSync();
    }
    if (companion != null && p.isWithin(_legacyAudio.path, companion)) {
      final coverTarget = File(
        p.join(
          p.dirname(target.path),
          p.basename(companion),
        ),
      );
      final coverSource = File(companion);
      if (coverSource.existsSync()) {
        coverTarget.parent.createSync(recursive: true);
        coverSource.renameSync(coverTarget.path);
      }
    }
  }
}
```

- [ ] **Step 4: Rewire the providers and startup**

In `lib/data/providers/cache_providers.dart`, change the audio root:

```dart
    resolveBaseDir: () async {
      final support = await getApplicationSupportDirectory();
      return Directory(p.join(support.path, 'cache', 'audio'));
    },
```

In `lib/data/providers/cover_providers.dart`, change the cover root:

```dart
    resolveBaseDir: () async {
      final support = await getApplicationSupportDirectory();
      return Directory(p.join(support.path, 'cache', 'cover'));
    },
```

In `lib/main.dart`, replace the cover `checkIntegrity()` block with a startup wipe, and add relocation before the integrity passes:

```dart
  // One-time move of pre-v10 cache files into the unified cache/ root.
  try {
    final support = await getApplicationSupportDirectory();
    await CacheRelocator(
      database: container.read(appDatabaseProvider),
      audioStore: container.read(audioCacheStoreProvider),
      coverStore: container.read(coverCacheStoreProvider),
      legacyAudioRoot: Directory(p.join(support.path, 'audio_cache')),
      legacyCoverRoot: Directory(p.join(support.path, 'cover_cache')),
    ).relocate();
  } catch (error) {
    debugPrint('Flind Player: cache relocation failed: $error');
  }

  // Layer 2 (covers for un-cached songs) is session-scoped: wipe it on start.
  unawaited(
    coverCacheStore.clear().then<void>(
      (_) {},
      onError: (Object error) {
        debugPrint('Flind Player: cover cache wipe failed: $error');
      },
    ),
  );
```

Add the `path`/`path_provider` imports and `database_providers.dart` import as needed. Remove the now-unused cover `checkIntegrity` block.

- [ ] **Step 5: Run the relocator test and the full suite**

Run: `flutter test test/cache_relocator_test.dart test/audio_cache_store_test.dart test/cover_cache_store_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/data/providers/cache_providers.dart lib/data/providers/cover_providers.dart lib/data/cache/cache_relocator.dart lib/main.dart test/cache_relocator_test.dart
git commit -m "feat(cache): unified root, startup layer-2 wipe, legacy relocation"
```

---

### Task 7: Settings — online-only clear and offline cache management

**Files:**
- Modify: `lib/data/cache/audio_cache_store.dart` (add `clearUnpinned()`)
- Modify: `lib/data/providers/cover_providers.dart` (`CacheMaintenance.onClearAll` → online only)
- Create: `lib/data/providers/offline_cache_providers.dart`
- Modify: `lib/features/settings/settings_screen.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`, regenerate `lib/l10n/app_localizations*.dart`
- Test: `test/settings_screen_test.dart`

**Interfaces:**
- Consumes: `AudioCacheStore.entries()`, `remove(id)`.
- Produces: `offlineCacheEntriesProvider` (`FutureProvider<List<CachedAudio>>`), `offlineCacheUsageProvider` (`FutureProvider<int>`), `offlineCacheMaintenanceProvider` with `onRemove(int id)` and `onClearAll()`.

- [ ] **Step 1: Add `clearUnpinned` and write a failing store test**

In `test/audio_cache_store_test.dart`, add to `remove / clear`:

```dart
    test('clearUnpinned keeps pinned rows and deletes the rest', () async {
      await addEntry('auto', bytes: 100, lastAccessedAt: 1000);
      final pinned = await addEntry(
        'saved',
        bytes: 100,
        pinned: true,
        lastAccessedAt: 2000,
      );

      await store.clearUnpinned();

      expect(await store.lookup('bilibili', 'auto'), isNull);
      expect((await store.lookup('bilibili', 'saved'))!.id, pinned.id);
      expect(File(pathFor('auto')).existsSync(), isFalse);
      expect(File(pathFor('saved')).existsSync(), isTrue);
    });
```

Run: `flutter test test/audio_cache_store_test.dart --plain-name clearUnpinned`
Expected: FAIL (`clearUnpinned` missing).

In `lib/data/cache/audio_cache_store.dart`, add:

```dart
  /// Deletes every non-pinned row (and its files), keeping pinned downloads.
  Future<void> clearUnpinned() async {
    await _resolveDir();
    final rows = await (_db.select(
      _db.audioCache,
    )..where((t) => t.pinned.equals(false))).get();
    for (final row in rows) {
      await (_db.delete(
        _db.audioCache,
      )..where((t) => t.id.equals(row.id))).go();
      await _deleteFileIfUnreferenced(row.filePath);
      _deleteCoverFile(row.coverPath);
    }
  }
```

Run again; Expected: PASS.

- [ ] **Step 2: Update the clear semantics and add offline providers**

In `lib/data/providers/cover_providers.dart`, change `onClearAll`:

```dart
    onClearAll: () async {
      await audio.clearUnpinned();
      await covers.clear();
    },
```

Create `lib/data/providers/offline_cache_providers.dart` (GPL header included):

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flind_player/data/cache/audio_cache_store.dart';
import 'package:flind_player/data/providers/cache_providers.dart';

/// Every pinned (offline) download, oldest access first.
final offlineCacheEntriesProvider = FutureProvider<List<CachedAudio>>((ref) async {
  final entries = await ref.watch(audioCacheStoreProvider).entries();
  return entries.where((e) => e.pinned).toList(growable: false);
});

/// Bytes occupied by pinned downloads.
final offlineCacheUsageProvider = FutureProvider<int>((ref) async {
  final entries = await ref.watch(offlineCacheEntriesProvider.future);
  return entries.fold<int>(0, (sum, e) => sum + e.bytes);
});

/// Delete actions for the offline cache entry.
@immutable
class OfflineCacheMaintenance {
  const OfflineCacheMaintenance({required this.onRemove, required this.onClearAll});
  final Future<void> Function(int id) onRemove;
  final Future<void> Function() onClearAll;
}

final offlineCacheMaintenanceProvider = Provider<OfflineCacheMaintenance>((ref) {
  final store = ref.watch(audioCacheStoreProvider);
  return OfflineCacheMaintenance(
    onRemove: (id) async {
      final entry = (await store.entries()).firstWhere((e) => e.id == id);
      if (entry.pinned) await store.remove(id);
    },
    onClearAll: () async {
      final entries = await store.entries();
      for (final entry in entries.where((e) => e.pinned)) {
        await store.remove(entry.id);
      }
    },
  );
});
```

(Include the `flutter/foundation.dart` import for `@immutable`.)

- [ ] **Step 3: Add l10n keys**

In `lib/l10n/app_en.arb` add:

```json
  "offlineCache": "Offline cache",
  "offlineCacheEmpty": "No downloaded songs",
  "offlineCacheCount": "{count, plural, =0{No downloads} =1{1 download} other{{count} downloads}}",
  "@offlineCacheCount": {"placeholders": {"count": {"type": "int"}}},
  "offlineCacheUsage": "{usage} used",
  "@offlineCacheUsage": {"placeholders": {"usage": {"type": "String"}}},
  "removeDownloadTitle": "Remove download?",
  "removeDownloadBody": "\"{title}\" will be removed from offline storage.",
  "@removeDownloadBody": {"placeholders": {"title": {"type": "String"}}},
  "clearOfflineTitle": "Clear offline cache?",
  "clearOfflineBody": "Every downloaded song will be removed.",
  "clearOfflineCache": "Clear offline cache",
  "offlineCacheCleared": "Freed {size}",
  "@offlineCacheCleared": {"placeholders": {"size": {"type": "String"}}}
```

In `lib/l10n/app_zh.arb` add the matching keys:

```json
  "offlineCache": "离线缓存",
  "offlineCacheEmpty": "暂无已下载歌曲",
  "offlineCacheCount": "{count, plural, =0{无下载} other{{count} 首}}",
  "@offlineCacheCount": {"placeholders": {"count": {"type": "int"}}},
  "offlineCacheUsage": "已用 {usage}",
  "@offlineCacheUsage": {"placeholders": {"usage": {"type": "String"}}},
  "removeDownloadTitle": "移除下载？",
  "removeDownloadBody": "将从离线存储中移除“{title}”。",
  "@removeDownloadBody": {"placeholders": {"title": {"type": "String"}}},
  "clearOfflineTitle": "清空离线缓存？",
  "clearOfflineBody": "所有已下载歌曲都将被移除。",
  "clearOfflineCache": "清空离线缓存",
  "offlineCacheCleared": "已释放 {size}",
  "@offlineCacheCleared": {"placeholders": {"size": {"type": "String"}}}
```

Run: `flutter gen-l10n`
Expected: regenerates `lib/l10n/app_localizations*.dart`.

- [ ] **Step 4: Add the settings entry and screen**

In `lib/features/settings/settings_screen.dart`, add a `_SectionHeader(l10n.offlineCache)` + `const _OfflineCacheSection()` after the playback section. Implement `_OfflineCacheSection` as a `ConsumerWidget` that watches `offlineCacheEntriesProvider` and `offlineCacheUsageProvider`:

```dart
class _OfflineCacheSection extends ConsumerWidget {
  const _OfflineCacheSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final entries = ref.watch(offlineCacheEntriesProvider).value ?? const <CachedAudio>[];
    final usage = ref.watch(offlineCacheUsageProvider).value ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(Icons.download_done_outlined),
          title: Text(l10n.offlineCache),
          subtitle: Text(
            '${l10n.offlineCacheCount(entries.length)} · ${l10n.offlineCacheUsage(formatMegabytes(usage))}',
          ),
          trailing: entries.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined),
                  onPressed: () => _confirmClearOffline(context, ref),
                ),
        ),
        if (entries.isEmpty)
          ListTile(
            dense: true,
            title: Text(
              l10n.offlineCacheEmpty,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else
          for (final entry in entries)
            ListTile(
              dense: true,
              title: Text(entry.sourceTrackId),
              subtitle: Text(formatMegabytes(entry.bytes)),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  await ref.read(offlineCacheMaintenanceProvider).onRemove(entry.id);
                  ref.invalidate(offlineCacheEntriesProvider);
                  ref.invalidate(offlineCacheUsageProvider);
                },
              ),
            ),
      ],
    );
  }

  /// Confirms, then removes every pinned download.
  Future<void> _confirmClearOffline(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.clearOfflineTitle),
        content: Text(l10n.clearOfflineBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.clear),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final freed = ref.read(offlineCacheUsageProvider).value ?? 0;
    await ref.read(offlineCacheMaintenanceProvider).onClearAll();
    ref.invalidate(offlineCacheEntriesProvider);
    ref.invalidate(offlineCacheUsageProvider);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.offlineCacheCleared(formatMegabytes(freed)))),
    );
  }
}
```

Add the needed imports (`offline_cache_providers.dart`, `audio_cache_store.dart`). The list shows `sourceTrackId` as the title because a settings screen has no pool row loaded; acceptable for v1 of the entry.

- [ ] **Step 5: Update widget tests**

In `test/settings_screen_test.dart`, the fake `AudioCacheStore` (`enforceLimitCalls` etc.) must gain `clearUnpinned()` and `entries()` overrides; add a test that the offline section renders an entry and that the existing "clear cache" no longer clears pinned rows.

Run: `flutter test test/settings_screen_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/data/cache/audio_cache_store.dart lib/data/providers/cover_providers.dart lib/data/providers/offline_cache_providers.dart lib/features/settings/settings_screen.dart lib/l10n test/settings_screen_test.dart
git commit -m "feat(settings): online-only clear and offline cache management entry"
```

---

### Task 8: Full regression and docs

**Files:**
- Modify: `docs/缓存TODO.md` (mark P1/P3/P4 addressed; note P2/P5 deferred)
- Modify: `docs/local-library.md` §3.1/§4 (align with the new model)

- [ ] **Step 1: Run analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 2: Run the full test suite**

Run: `flutter test`
Expected: all green.

- [ ] **Step 3: Update docs**

Update `docs/缓存TODO.md` to mark P1/P3/P4 resolved by this refactor and record P2/P5 as still deferred. Update `docs/local-library.md` §4.4/§4.5 to describe layer 1 vs layer 2 and the per-song quota.

- [ ] **Step 4: Commit**

```bash
git add docs/缓存TODO.md docs/local-library.md
git commit -m "docs: record cache refactor (per-song quota, layer 1/2)"
```

---

## Self-Review

**Spec coverage:**
- §3.1 pinned exempt → Tasks 2/3 (quotas ignore pinned) ✔
- §3.2 layer 2 256 MiB + LRU + startup wipe → Task 3 + Task 6 ✔
- §3.3 table name unchanged → Task 1 (comment) ✔
- §3.4 settings display unchanged + online-only clear + offline entry → Task 7 ✔
- §3.5 layer 1 cover one per row → Task 4 (writes `coverFileFor`) ✔
- §3.6 offline download ensures companion cover → Task 5 ✔
- §4/§5 single root, subtrees, guard → Tasks 2/3/6 ✔
- §6 cover_path + 4 indices → Task 1 ✔
- §7 quota/eviction → Tasks 2/3 ✔
- §8 lifecycle/routing → Tasks 4/5 ✔
- §9 migration → Task 1 + relocation Task 6 ✔
- §10 settings → Task 7 ✔
- §11 tests → each task + Task 8 ✔

**Type consistency:** `cacheSourceTrackId` extracted in Task 4 and re-exported so Tasks 5/7 imports keep resolving. `CachedAudio.coverPath` defined Task 2, consumed Task 4/7. `CoverCacheStore.ephemeralLimitBytes` defined Task 3, consumed Task 3 tests. `ensureCover` callback defined Task 5, wired from `CoverService.ensureCover` (Task 4).

**Review Focus coverage:** subtree isolation (Task 2 `clear`/`checkIntegrity` tests + Task 3 no cross-reads); shared audio file (existing Task 2 content-dedup tests remain); dangling cover (Task 4 `_cachedAudioFor` existence check); offline cover best-effort (Task 5 try/catch test); restart survival (Task 3 wipe is layer 2 only; Task 2 covers live under layer 1).
