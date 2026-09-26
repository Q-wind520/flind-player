# 歌单/收藏收敛到单一曲目池 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让收藏/歌单成员统一收敛到 `tracks` 单一池，修复 A/B/C/E/F/H/G，并以 schema v9 删除快照列与死 schema。

**Architecture:** 行为修复先行（每步可编译可测）：新增 `promoteTrack`，写入收藏/歌单时先落池；成员读取改为 JOIN 池并用 `missing_at` 决定可用性。结构收敛最后：重建 `playlist_tracks` 为纯引用、删 `tracks.content_hash`、删 `scan_state`，并回填老数据。

**Tech Stack:** Flutter 3.47.5 / Dart、drift（SQLite）、Riverpod、flutter_test。代码生成用 `build_runner`。

**Spec:** `docs/superpowers/specs/2026-09-26-playlist-pool-convergence-design.md`

## Global Constraints

- Flutter 3.47.5 stable；使用仓库内 PATH 上的 `flutter`/`dart`。
- 完成每个任务后 `flutter analyze` 必须 0 问题。
- 每个任务结束提交一次，提交信息用中文、conventional 前缀。
- 只允许 spec 描述的行为变化；不得改动数据层骨架（`tracks` 单池、`uri` 键、软删除、迁移守卫风格）。
- 不删除 `tracks` 的 7 个元数据列（`album_artist / track_no / disc_no / year / bitrate / sample_rate / genre`）。
- `Track.id == null` 约定为“不可用”（未入池或已软删），实现中必须在 `Track.id` 文档注释里写明。
- 迁移步骤必须幂等、可重跑，延续 `_addColumnIfMissing` 的守卫风格。
- 重构后 `flutter test` 必须全绿；用例数会因增删变化。

## Review Focus

- **回填遇到空/非法快照**（老库 `playlist_tracks` 中 `title` 为空或 `source_track_id` 非法）：迁移不得因约束中断；期望跳过或补齐而非崩溃。
- **软删除成员再次收藏**（池行 `missing_at` 非空）：期望保留在收藏、显示不可用，且 promote 不复活它。
- **重复 promote 同一 `uri`**：期望池只有一行、`added_at` 不被重置、顺序不变。
- **bilibili `sourceTrackId` 往返**（`bvid:cid` 经 promote 入池再由 JOIN 读回）：期望 cid 不丢。
- **对不存在行的封面/成员操作**（未知 playlistId、未知 uri 的 `clearCover` / remove）：期望 no-op，不抛异常。

---

### Task 1: `MusicLibraryRepository.promoteTrack`

**Files:**
- Modify: `lib/core/repositories/music_library_repository.dart`（接口加方法；更新 `Track.id` 不存在于此文件，见 Task 3 注释约定）
- Modify: `lib/data/repositories/drift_music_library_repository.dart:119-143` 附近加实现
- Test: `test/drift_music_library_repository_test.dart`

**Interfaces:**
- Produces: `Future<int> promoteTrack(Track track)` — 插入曲目入池；池中已存在则完全不动（保留元数据与 `missing_at`），返回池行 id。

- [ ] **Step 1: 写失败测试**

在 `test/drift_music_library_repository_test.dart` 加组：

```dart
group('promoteTrack', () {
  test('inserts a new track into the pool', () async {
    final id = await repository.promoteTrack(
      const Track(
        source: 'bilibili',
        sourceTrackId: BiliTrackId(bvid: 'BV1', cid: 7),
        uri: 'bilibili:BV1:7',
        title: 'Online',
      ),
    );
    expect(id, greaterThan(0));
    final stored = await repository.findByUri('bilibili:BV1:7');
    expect(stored!.title, 'Online');
  });

  test('does not overwrite an existing row (pool wins)', () async {
    await insertPoolTrack(uri: 'local:/m/a.flac', title: 'Original');
    await repository.promoteTrack(
      const Track(
        source: 'local',
        sourceTrackId: LocalTrackId('/m/a.flac'),
        uri: 'local:/m/a.flac',
        title: 'Incoming',
      ),
    );
    expect((await repository.findByUri('local:/m/a.flac'))!.title, 'Original');
  });

  test('does not resurrect a soft-deleted row', () async {
    await insertPoolTrack(uri: 'local:/m/b.flac', title: 'Gone');
    await repository.markMissingExcept('local', <String>{});
    await repository.promoteTrack(
      const Track(
        source: 'local',
        sourceTrackId: LocalTrackId('/m/b.flac'),
        uri: 'local:/m/b.flac',
        title: 'Gone',
      ),
    );
    expect(await repository.allTracks(), isEmpty); // still missing
  });
});
```

> 注：`insertPoolTrack` 是测试内已有或需新增的本地 helper；若不存在，用 `db.into(db.tracks).insert(TracksCompanion.insert(...))` 直接写。`markMissingExcept` 的软删保护要求 `seenUris` 非空且传 `roots`；本测试用 `markMissingExcept('local', {'local:/m/other.flac'})` 并确认 `/m/b.flac` 无 `scanRoot` 会被标记。按实际实现调整 helper。

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/drift_music_library_repository_test.dart -n promoteTrack`
Expected: 编译失败 / `promoteTrack` not defined。

- [ ] **Step 3: 实现**

接口（`music_library_repository.dart`，`upsertTrack` 之后加）：

```dart
/// Promotes [track] into the pool without touching an existing row.
///
/// `INSERT OR IGNORE` keyed on `uri`: an existing row keeps its metadata and
/// its `missingAt` (a soft-deleted track stays soft-deleted). This is the
/// write path used when a track is favourited or added to a playlist, so the
/// pool is the single source of truth for every referenced track.
Future<int> promoteTrack(Track track);
```

实现（`drift_music_library_repository.dart`，`upsertTrack` 之后加）：

```dart
@override
Future<int> promoteTrack(Track track) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  await _db.into(_db.tracks).insert(
    _toCompanion(track, createdAt: now, updatedAt: now),
    mode: InsertMode.insertOrIgnore,
  );
  final row = await (_db.select(
    _db.tracks,
  )..where((t) => t.uri.equals(track.uri))).getSingle();
  return row.id;
}
```

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/drift_music_library_repository_test.dart -n promoteTrack`
Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add lib/core/repositories/music_library_repository.dart lib/data/repositories/drift_music_library_repository.dart test/drift_music_library_repository_test.dart
git commit -m "feat(library): 新增 promoteTrack 保证成员曲目落池"
```

---

### Task 2: 收藏/歌单写入先 promote（修 A），重加不重排（修 F）

**Files:**
- Modify: `lib/data/repositories/drift_playlist_repository.dart`（构造注入 library；`addTrack` promote + `insertOrIgnore`）
- Modify: `lib/data/database/tables.dart` 无
- Test: `test/favorites_repository_test.dart`、`test/playlist_repository_test.dart`

**Interfaces:**
- Consumes: Task 1 的 `promoteTrack`。
- Produces: 构造 `DriftPlaylistRepository(AppDatabase db, {MusicLibraryRepository? library})`。

- [ ] **Step 1: 写失败测试（并改旧的“池为空”断言）**

`test/favorites_repository_test.dart`：把 `independence from the library` 组改为：

```dart
group('promotion into the pool', () {
  test('addFavorite promotes the track into tracks', () async {
    await repository.addFavorite(localTrack());
    final rows = await db.select(db.tracks).get();
    expect(rows, hasLength(1));
    expect(rows.single.uri, 'local:/music/song.flac');
    expect((await repository.allFavorites()).single.title, 'Song');
  });
});
```

`test/playlist_repository_test.dart`：把 `pool join semantics` 组的
`a member survives the track being absent from the pool` 改为：

```dart
test('addTrack promotes the track into the pool', () async {
  final playlist = await repository.createPlaylist(name: 'P');
  await repository.addTrack(playlist.id, localTrack());

  final pool = await db.select(db.tracks).get();
  expect(pool, hasLength(1));
  expect(pool.single.uri, 'local:/music/song.flac');
});
```

并在 `addTrack / removeTrack / containsTrack` 组加：

```dart
test('re-adding does not reset addedAt nor reorder', () async {
  final playlist = await repository.createPlaylist(name: 'P');
  await repository.addTrack(playlist.id, localTrack(path: '/m/a.flac'));
  await repository.addTrack(playlist.id, localTrack(path: '/m/b.flac'));
  expect(
    (await repository.playlistTracks(playlist.id)).map((t) => t.uri),
    ['local:/m/b.flac', 'local:/m/a.flac'],
  );

  await Future<void>.delayed(const Duration(milliseconds: 5));
  await repository.addTrack(playlist.id, localTrack(path: '/m/a.flac'));
  expect(
    (await repository.playlistTracks(playlist.id)).map((t) => t.uri),
    ['local:/m/b.flac', 'local:/m/a.flac'],
  );
});
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/favorites_repository_test.dart test/playlist_repository_test.dart`
Expected: `promotion into the pool` / `addTrack promotes` 失败（池为空）；`re-adding` 失败（顺序翻转）。

- [ ] **Step 3: 实现**

`drift_playlist_repository.dart`：

1. 顶部 import `music_library_repository.dart` 与 `drift_music_library_repository.dart`。
2. 构造与字段：

```dart
DriftPlaylistRepository(AppDatabase db, {MusicLibraryRepository? library})
  : _db = db,
    _library = library ?? DriftMusicLibraryRepository(db);

final AppDatabase _db;
final MusicLibraryRepository _library;
```

3. `addTrack`：先 promote，成员写入改为 `insertOrIgnore`（冲突不刷新 `addedAt`）：

```dart
@override
Future<void> addTrack(int playlistId, Track track) async {
  // The pool is the single source of truth: a referenced track must exist in
  // `tracks` so it can be resolved (and shown in 全部) after being saved.
  await _library.promoteTrack(track);

  final companion = PlaylistTracksCompanion(
    playlistId: Value(playlistId),
    uri: Value(track.uri),
    source: Value(track.source),
    sourceTrackId: Value(_encodeSourceTrackId(track.sourceTrackId)),
    title: Value(track.title),
    artist: Value(track.artist),
    album: Value(track.album),
    durationMs: Value(track.duration?.inMilliseconds),
    coverPath: Value(track.coverPath),
    coverUrl: Value(track.coverUrl),
    addedAt: Value(DateTime.now().millisecondsSinceEpoch),
  );
  // Conflict on (playlist_id, uri) is ignored: re-adding never reorders.
  await _db.into(_db.playlistTracks).insert(
    companion,
    mode: InsertMode.insertOrIgnore,
  );
}
```

`DriftFavoritesRepository` 与 `playlist_providers` 无需改（默认内部构造 library）。

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/favorites_repository_test.dart test/playlist_repository_test.dart`
Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add lib/data/repositories/drift_playlist_repository.dart test/favorites_repository_test.dart test/playlist_repository_test.dart
git commit -m "fix(playlist): 收藏/歌单写入先落池，重加不重排 (A,F)"
```

---

### Task 3: 成员读取池 id 与可用性（修 B）

**Files:**
- Modify: `lib/data/repositories/drift_playlist_repository.dart:231-249` `_memberQuery`；`:288-304` `_toDomain`
- Modify: `lib/core/models/track.dart:26-27`（`Track.id` 注释）
- Test: `test/playlist_repository_test.dart`、`test/playlist_ui_test.dart`

**Interfaces:**
- Produces: 成员 `Track.id = missing_at == null ? pool_id : null`。

- [ ] **Step 1: 写失败测试**

`test/playlist_repository_test.dart` 加：

```dart
group('member availability', () {
  test('member id is the pool id when present and not missing', () async {
    final playlist = await repository.createPlaylist(name: 'P');
    await repository.addTrack(playlist.id, localTrack());
    final member = (await repository.playlistTracks(playlist.id)).single;
    expect(member.id, isNotNull);
  });

  test('member id is null when the pool row is soft-deleted', () async {
    final playlist = await repository.createPlaylist(name: 'P');
    await repository.addTrack(playlist.id, localTrack(path: '/m/a.flac'));
    await repository.markMissingExcept('local', const {'local:/m/other.flac'});
    final member = (await repository.playlistTracks(playlist.id)).single;
    expect(member.id, isNull);
  });
});
```

`test/playlist_ui_test.dart`：加一条详情页可用性：

```dart
testWidgets('playlist detail renders members as playable when id is set',
    (tester) async {
  _setSize(tester, 400, 800);
  final playable = Track(
    id: 42,
    source: 'local',
    sourceTrackId: const LocalTrackId('/m/a.mp3'),
    uri: 'local:/m/a.mp3',
    title: 'Playable',
  );
  final repo = _FakePlaylistRepository(
    playlists: [_playlist(2, 'Mix', PlaylistKind.custom)],
    tracks: {2: [playable]},
  );
  await tester.pumpWidget(_app(playlistRepo: repo));
  await tester.pumpAndSettle();
  await _openPlaylists(tester);
  await tester.tap(find.text('Mix'));
  await tester.pumpAndSettle();

  final tile = tester.widget<ListTile>(find.ancestor(
    of: find.text('Playable'),
    matching: find.byType(ListTile),
  ));
  expect(tile.enabled, isTrue);
  expect(find.text(testL10n().trackUnavailable), findsNothing);
});
```

（若 `trackUnavailable` 的 l10n key 名不同，以现有 `track_list_items.dart` 引用的 `l10n.trackUnavailable` 为准。）

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/playlist_repository_test.dart test/playlist_ui_test.dart`
Expected: `member id is the pool id` 失败（当前恒 null）。

- [ ] **Step 3: 实现**

`Track.id` 注释（`track.dart:26-27`）改为：

```dart
/// Database row id of the pool (`tracks`) row.
///
/// `null` means the track is **unavailable**: either not persisted, or its
/// pool row is soft-deleted (`missingAt` set). Playlist/favourite members are
/// resolved through the pool, so `null` here is what the UI renders as
/// "不可用".
final int? id;
```

`_memberQuery` 改为只读池（JOIN）：

```dart
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
```

`_toDomain`：

```dart
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
```

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/playlist_repository_test.dart test/playlist_ui_test.dart`
Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add lib/data/repositories/drift_playlist_repository.dart lib/core/models/track.dart test/playlist_repository_test.dart test/playlist_ui_test.dart
git commit -m "fix(playlist): 成员可用性由池 missing_at 判定 (B)"
```

---

### Task 4: 收藏页可用性 + 最近添加排序（修 E）

**Files:**
- Create: `lib/features/library/track_sorting.dart`（抽出可测的收藏排序函数）
- Modify: `lib/features/library/library_screen.dart:745-782`（`_trackList`/`_trackGrid` 传 `unavailable`）；`:787-806` `_sortTracks` 改为调用 `sortFavouriteTracks`
- Test: `test/library_sort_test.dart`、`test/favorites_ui_test.dart`

**Interfaces:**
- Consumes: Task 3 的 `Track.id` 约定。
- Produces: `List<Track> sortFavouriteTracks(List<Track> tracks, TrackSort sort)`。

- [ ] **Step 1: 写失败测试**

`test/library_sort_test.dart` 加（导入 `lib/features/library/track_sorting.dart`）：

```dart
test('recentlyAdded preserves the incoming (SQL added_at) order', () {
  final newer = Track(id: 1, source: 'local', sourceTrackId: const LocalTrackId('/m/b.mp3'), uri: 'local:/m/b.mp3', title: 'B');
  final older = Track(id: 99, source: 'local', sourceTrackId: const LocalTrackId('/m/a.mp3'), uri: 'local:/m/a.mp3', title: 'A');
  final sorted = sortFavouriteTracks([newer, older], TrackSort.recentlyAdded);
  expect(sorted.map((t) => t.title), ['B', 'A']); // NOT id order
});
```

`test/favorites_ui_test.dart` 加：

```dart
testWidgets('a favourite without a pool id renders as unavailable',
    (tester) async {
  // `_track('Gone')` has no id, i.e. the pool row is missing.
  await tester.pumpWidget(_libraryApp(favourites: [_track('Gone')]));
  await tester.pumpAndSettle();
  await tester.tap(find.text('收藏').last); // switch to the 收藏 section
  await tester.pumpAndSettle();
  expect(find.text('不可用'), findsWidgets); // l10n.trackUnavailable (zh)
});
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/library_sort_test.dart test/favorites_ui_test.dart`
Expected: `recentlyAdded preserves` 编译失败；`unavailable` 断言失败。

- [ ] **Step 3: 实现**

新建 `lib/features/library/track_sorting.dart`，把 `_sortTracks`/`_compareNullable` 搬为顶层函数：

```dart
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/models/track_sort.dart';

List<Track> sortFavouriteTracks(List<Track> tracks, TrackSort sort) {
  final sorted = List<Track>.from(tracks);
  sorted.sort((a, b) {
    return switch (sort) {
      TrackSort.title => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      TrackSort.artist => _compareNullable(a.artist?.toLowerCase(), b.artist?.toLowerCase()),
      TrackSort.album => _compareNullable(a.album?.toLowerCase(), b.album?.toLowerCase()),
      // Repository already orders by added_at DESC; Track.id is the pool id,
      // not the favourite time, so preserve the incoming order.
      TrackSort.recentlyAdded => 0,
    };
  });
  return sorted;
}

int _compareNullable(String? a, String? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return a.compareTo(b);
}
```

`library_screen.dart` 删除私有 `_sortTracks`/`_compareNullable`，`_buildFavouritesBody` 改调 `sortFavouriteTracks`；
`_trackList`/`_trackGrid` 的 `TrackTile`/`TrackCard` 加 `unavailable: track.id == null`。

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/favorites_ui_test.dart`
Expected: `unavailable` 断言失败（当前收藏页不传该标志）。

- [ ] **Step 3: 实现**

`_trackList` / `_trackGrid` 的 `TrackTile`/`TrackCard` 加 `unavailable: track.id == null`。

`_sortTracks` 的 `recentlyAdded`：

```dart
// The repository already orders members by `added_at DESC`; `Track.id` is the
// pool row id and does NOT track when the song was favourited, so leave the
// incoming order untouched.
TrackSort.recentlyAdded => 0,
```

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/favorites_ui_test.dart test/playlist_ui_test.dart`
Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add lib/features/library/library_screen.dart test/favorites_ui_test.dart
git commit -m "fix(library): 收藏页展示不可用项并修正最近添加排序 (E)"
```

---

### Task 5: 歌单封面创建/清除（修 C1/C2）

**Files:**
- Modify: `lib/core/repositories/playlist_repository.dart:110-125`（签名）
- Modify: `lib/data/repositories/drift_playlist_repository.dart:57-108`
- Modify: `lib/features/library/widgets/playlist_editor_dialog.dart:96-133,217-225`
- Test: `test/playlist_repository_test.dart`、`test/playlist_ui_test.dart`（fake 同步）

**Interfaces:**
- Produces:
  - `Future<Playlist> createPlaylist({required String name, String? description, String? coverPath, String? coverUrl})`
  - `Future<void> updatePlaylist(int id, {String? name, String? description, String? coverPath, String? coverUrl, bool clearCover = false})`

- [ ] **Step 1: 写失败测试**

`test/playlist_repository_test.dart` 加：

```dart
test('creates a playlist with a cover', () async {
  final p = await repository.createPlaylist(
    name: 'C',
    coverPath: '/covers/c.webp',
    coverUrl: 'https://example.com/c.webp',
  );
  final stored = await repository.playlistById(p.id);
  expect(stored!.coverPath, '/covers/c.webp');
  expect(stored.coverUrl, 'https://example.com/c.webp');
});

test('clearCover clears an existing cover', () async {
  final p = await repository.createPlaylist(name: 'C');
  await repository.updatePlaylist(p.id, coverPath: '/covers/c.webp');
  await repository.updatePlaylist(p.id, clearCover: true);
  final stored = await repository.playlistById(p.id);
  expect(stored!.coverPath, isNull);
  expect(stored.coverUrl, isNull);
});
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/playlist_repository_test.dart -n "cover"`
Expected: 编译失败（无 `coverPath`/`clearCover` 参数）。

- [ ] **Step 3: 实现**

接口签名扩展 `createPlaylist` / `updatePlaylist`（同步文档注释：`clearCover` 显式清空）。

`drift_playlist_repository.dart`：
- `createPlaylist` 增加参数并写入 `PlaylistsCompanion.insert(..., coverPath: Value(coverPath), coverUrl: Value(coverUrl))`。
- `updatePlaylist` 签名加 `bool clearCover = false`，写入：

```dart
coverPath: clearCover
    ? const Value(null)
    : (coverPath == null ? const Value.absent() : Value(coverPath)),
coverUrl: clearCover
    ? const Value(null)
    : (coverUrl == null ? const Value.absent() : Value(coverUrl)),
```

`playlist_editor_dialog.dart`：
- 状态加 `bool _clearCover = false;`。
- `_pickCover` 里 `_clearCover = false;`。
- 移除封面按钮：`_coverPath = null; _coverUrl = null; _clearCover = true;`。
- `_save` 编辑分支传 `clearCover: _clearCover`；创建分支传 `coverPath: _coverPath, coverUrl: _coverUrl`。

同步 `test/playlist_ui_test.dart` 的 `_FakePlaylistRepository`：
- `createPlaylist` 加 `coverPath`/`coverUrl` 参数并写进 `Playlist`。
- `updatePlaylist` 加 `bool clearCover = false`，`clearCover` 时用 `Value`-like 显式清空（fake 内直接置 null；注意不要用 `copyWith` 的 null 保留语义，改为构造新 `Playlist`）。

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/playlist_repository_test.dart test/playlist_ui_test.dart`
Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add lib/core/repositories/playlist_repository.dart lib/data/repositories/drift_playlist_repository.dart lib/features/library/widgets/playlist_editor_dialog.dart test/playlist_repository_test.dart test/playlist_ui_test.dart
git commit -m "fix(playlist): 创建带封面、清除封面生效 (C)"
```

---

### Task 6: B站收藏夹行统一动作集（修 H）

**Files:**
- Modify: `lib/features/playlists/bilibili_favorites_screen.dart:508-568`
- Test: `test/bilibili_favorites_screen_test.dart`

**Interfaces:**
- Consumes: `TrackActionsButton`（`lib/features/library/widgets/track_actions_button.dart`）。

- [ ] **Step 1: 写失败测试**

`test/bilibili_favorites_screen_test.dart` 加（并 import `TrackActionsButton`）：

```dart
testWidgets('a favourite row exposes the full action menu', (tester) async {
  const track = Track(
    source: 'bilibili',
    sourceTrackId: BiliTrackId(bvid: 'BV1', cid: 7),
    uri: 'bilibili:BV1:7',
    title: 'Online',
  );
  final source = _FakeRemotePlaylistSource(
    folders: (uid) async => <RemotePlaylist>[_musicFolder],
    tracks: (playlistId, page) async => _page(<Track>[track], page: page),
  );
  await tester.pumpWidget(_app(source: source));
  await _openFolder(tester); // uses uid 17340771 + 「音乐收藏」

  expect(find.byType(TrackActionsButton), findsWidgets);
  await tester.tap(find.byType(TrackActionsButton).first);
  await tester.pumpAndSettle();
  expect(find.text('收藏'), findsWidgets);
  expect(find.text('加入歌单'), findsWidgets);
});
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/bilibili_favorites_screen_test.dart`
Expected: find `TrackActionsButton` 为 0。

- [ ] **Step 3: 实现**

`bilibili_favorites_screen.dart` 的 `_FavoriteTrackTile.trailing`：把裸 `IconButton(library_add)` 换成

```dart
TrackActionsButton(
  track: track,
  showSaveToLibrary: true,
  onSaveToLibrary: onSave,
),
```

并 import `track_actions_button.dart`。若该文件的收藏行不再需要单独 `onSave`，可保留 `_FavoriteTrackTile.onSave`。

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/bilibili_favorites_screen_test.dart`
Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add lib/features/playlists/bilibili_favorites_screen.dart test/bilibili_favorites_screen_test.dart
git commit -m "fix(bilibili): 收藏夹行统一为完整动作菜单 (H)"
```

---

### Task 7: 清理重复收藏 provider 与死分支（修 G）

**Files:**
- Modify: `lib/data/providers/persistence_providers.dart`（新增共享 `isFavoriteProvider`）
- Modify: `lib/features/library/widgets/track_actions_button.dart:69-70,196-207,224-227`
- Modify: `lib/features/player/player_screen.dart:678-681`
- Test: 现有 widget/单元测试全绿即可

**Interfaces:**
- Produces: `final isFavoriteProvider = FutureProvider.family<bool, String>(...)`（在 `persistence_providers.dart`）。

- [ ] **Step 1: 运行现有相关测试（基线）**

Run: `flutter test test/favorites_ui_test.dart test/playlist_ui_test.dart`
Expected: PASS（改动前基线）。

- [ ] **Step 2: 实现（无新增行为，属重构）**

`persistence_providers.dart` 加：

```dart
/// Whether [uri] is currently favourited. Retries disabled so errors surface.
final isFavoriteProvider = FutureProvider.family<bool, String>((ref, uri) {
  ref.watch(favoritesProvider);
  return ref.watch(favoritesRepositoryProvider).isFavorite(uri);
}, retry: (_, _) => null);
```

`track_actions_button.dart`：删除私有 `_isFavouriteProvider`，改用 `isFavoriteProvider`；
`_cacheTrack` 简化为：

```dart
void _cacheTrack() {
  ref.read(downloadManagerProvider).cacheTrack(track, pinned: true);
}
```

`_onSelected` 调用改为 `_cacheTrack()`；删除不再使用的 `cacheEntry` 参数与
`final cacheEntry = ref.watch(audioCacheEntryProvider(track)).value;`（若 `audioCacheEntryProvider`
不再用于图标，保留图标所用的读取即可——只删 `_cacheTrack` 的传参）。

`player_screen.dart`：删除 `_playerFavoriteProvider`，改用 `isFavoriteProvider`。

- [ ] **Step 3: 运行确认通过**

Run: `flutter analyze && flutter test test/favorites_ui_test.dart test/playlist_ui_test.dart test/player_transport_test.dart`
Expected: analyze 0；测试 PASS。

- [ ] **Step 4: 提交**

```bash
git add lib/data/providers/persistence_providers.dart lib/features/library/widgets/track_actions_button.dart lib/features/player/player_screen.dart
git commit -m "refactor: 合并重复收藏 provider 并删除缓存死分支 (G)"
```

---

### Task 8: 删除成员封面的独立接口（为 schema v9 铺路）

**Files:**
- Modify: `lib/core/repositories/playlist_repository.dart`（删 `updateTrackCover`）
- Modify: `lib/data/repositories/drift_playlist_repository.dart`（删实现）
- Modify: `lib/core/repositories/favorites_repository.dart`（删 `updateFavoriteCover`）
- Modify: `lib/data/repositories/drift_favorites_repository.dart:60-72`（删实现）
- Modify: `lib/data/services/cover_service.dart:68-86,211-232`（构造去掉 `favorites`；`_persist` 只写池）
- Modify: `lib/data/providers/cover_providers.dart`（`coverServiceProvider` 去掉 `favorites:` 注入）
- Test: 17 个含 fake 的测试文件；`test/cover_service_test.dart`

**Interfaces:**
- Produces: 封面只由 `MusicLibraryRepository.updateTrackCover` 写池；成员封面读取走池（Task 3 已实现）。
- `CoverService({store, downloader, library, resolveRemoteUrl})`（移除 `favorites` 参数与 `_favorites` 字段）。

- [ ] **Step 1: 删除接口与实现**

- `PlaylistRepository`：删除 `updateTrackCover` 声明与文档。
- `DriftPlaylistRepository`：删除 `updateTrackCover` 重写。
- `FavoritesRepository`：删除 `updateFavoriteCover` 声明与文档。
- `DriftFavoritesRepository`：删除 `updateFavoriteCover` 重写。
- `cover_service.dart`：`CoverService` 构造删除 `required FavoritesRepository favorites` 与 `_favorites` 字段；
  `_persist` 删除 favorites 分支，只保留 `_library.updateTrackCover`。
- `cover_providers.dart`：`coverServiceProvider` 删除 `favorites: ref.watch(favoritesRepositoryProvider)`。

- [ ] **Step 2: 清理测试 fake**

在以下文件中删除 `updateTrackCover` / `updateFavoriteCover` 的 fake 重写（编译报错会逐个指出）：
`library_screen_test.dart, mini_player_bar_test.dart, responsive_layout_test.dart, tray_service_test.dart,
audio_handler_test.dart, playback_persistence_service_test.dart, mini_settings_test.dart, playlist_ui_test.dart,
home_shell_test.dart, player_transport_test.dart, search_screen_test.dart, library_sort_test.dart,
cover_service_test.dart, settings_screen_test.dart, bilibili_favorites_screen_test.dart, favorites_ui_test.dart`
以及 `test/playlist_repository_test.dart` 的 `updateTrackCover` 组。

> 说明：这些 fake 多数实现 `MusicLibraryRepository` 或 `FavoritesRepository`。删方法后，实现类多余的重写会报错，移除即可；`MusicLibraryRepository` 的 `updateTrackCover` 保留。

`test/playlist_repository_test.dart` 删除整个 `group('updateTrackCover', ...)`；
`test/cover_service_test.dart` 改为只断言写池。

- [ ] **Step 3: 运行确认通过**

Run: `flutter analyze && flutter test`
Expected: analyze 0；测试全绿。

- [ ] **Step 4: 提交**

```bash
git add -A
git commit -m "refactor: 成员封面统一由池承载，删除重复接口"
```

---

### Task 9: schema v9 —— 纯引用成员表 + 回填 + 删死 schema

**Files:**
- Modify: `lib/data/database/tables.dart`（删 `ScanState`；`Tracks.contentHash`；`PlaylistTracks` 快照列与 `position`）
- Modify: `lib/data/database/app_database.dart`（`schemaVersion=9`；表列表去 `ScanState`；`if (from < 9)` 迁移）
- Regenerate: `lib/data/database/app_database.g.dart`
- Modify: `lib/data/repositories/drift_playlist_repository.dart`（`addTrack` 去快照列；`_memberQuery` 去 COALESCE；`_coverQuery` 去快照回退；删 `_encodeSourceTrackId`）
- Test: `test/drift_music_library_repository_test.dart`（迁移）、`test/playlist_repository_test.dart`、`test/favorites_repository_test.dart`

**Interfaces:**
- Consumes: Task 3 的 JOIN 读取、Task 8 的封面收敛。
- Produces: `playlist_tracks(id, playlist_id, uri, added_at)`；`tracks` 无 `content_hash`；无 `scan_state`。

- [ ] **Step 1: 写迁移失败测试 + 改旧快照断言**

在 `test/drift_music_library_repository_test.dart` 的 `schema migration` 组加：

```dart
test('v8 -> v9 backfills the pool and rebuilds playlist_tracks', () async {
  final dir = Directory.systemTemp.createTempSync('flind_migration_v9');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  final file = File('${dir.path}/library.sqlite');

  // Build a current (v9) file, then roll `playlist_tracks` back to its v8
  // shape (snapshot columns + position), restore the v8-only bits, pin v8.
  final before = AppDatabase(NativeDatabase(file));
  await before.customStatement('DROP TABLE playlist_tracks');
  await before.customStatement('''
CREATE TABLE playlist_tracks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  playlist_id INTEGER NOT NULL,
  uri TEXT NOT NULL,
  source TEXT NOT NULL,
  source_track_id TEXT NOT NULL,
  title TEXT NOT NULL,
  artist TEXT,
  album TEXT,
  duration_ms INTEGER,
  cover_path TEXT,
  cover_url TEXT,
  added_at INTEGER NOT NULL,
  position INTEGER,
  UNIQUE (playlist_id, uri)
)
''');
  // A member that is NOT in tracks — the v8 favourites-snapshot case.
  await before.customStatement(
    'INSERT INTO playlist_tracks '
    '(playlist_id, uri, source, source_track_id, title, artist, added_at, '
    "cover_url) VALUES (1, 'bilibili:BV1:7', 'bilibili', 'BV1:7', 'Online', "
    "'UP', 5, 'https://x/c.webp')",
  );
  await before.customStatement('ALTER TABLE tracks ADD COLUMN content_hash TEXT');
  await before.customStatement(
    'CREATE TABLE scan_state (key TEXT PRIMARY KEY, value TEXT)',
  );
  await before.customStatement('PRAGMA user_version = 8');
  await before.close();

  final after = AppDatabase(NativeDatabase(file));
  addTearDown(after.close);

  // Backfill promoted the member into the pool.
  final pool = await after.select(after.tracks).get();
  expect(pool, hasLength(1));
  expect(pool.single.uri, 'bilibili:BV1:7');
  expect(pool.single.title, 'Online');

  // tracks.content_hash removed.
  final cols = await after.customSelect('PRAGMA table_info(tracks)').get();
  expect(cols.map((r) => r.data['name']), isNot(contains('content_hash')));

  // scan_state removed.
  final tables = await after.customSelect(
    "SELECT name FROM sqlite_master WHERE type='table' AND name='scan_state'",
  ).get();
  expect(tables, isEmpty);

  // playlist_tracks is reference-only.
  final ptCols = await after
      .customSelect('PRAGMA table_info(playlist_tracks)')
      .get();
  expect(
    ptCols.map((r) => r.data['name']).toSet(),
    {'id', 'playlist_id', 'uri', 'added_at'},
  );

  // The ordering index survives the rebuild.
  final idx = await after.customSelect(
    "SELECT name FROM sqlite_master WHERE type='index' "
    "AND name='idx_playlist_tracks_order'",
  ).get();
  expect(idx, hasLength(1));

  // The member resolves through the pool.
  final repo = DriftPlaylistRepository(after);
  final members = await repo.playlistTracks(1);
  expect(members.single.title, 'Online');
  expect(members.single.id, isNotNull);
});
```

`test/playlist_repository_test.dart`：`adds a denormalised snapshot of every stored field`
改为断言“通过池解析”，删除对已删列的断言；`pool metadata wins over the snapshot` 删除或改为
“池是唯一来源”。

`test/favorites_repository_test.dart`：`adds a denormalised snapshot of every stored field`
改为通过池解析断言。

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/drift_music_library_repository_test.dart -n "v8 -> v9"`
Expected: 失败（列为旧形状）。

- [ ] **Step 3: 改 schema**

`tables.dart`：
- 删除 `Tracks.contentHash` 列及其文档。
- 删除整个 `ScanState` 类（`@DataClassName('ScanStateRow')`）。
- `PlaylistTracks` 只保留 `id, playlistId, uri, addedAt`；删除 `source, sourceTrackId, title,
  artist, album, durationMs, coverPath, coverUrl, position`，并更新类文档为“池的引用”。

`app_database.dart`：
- `tables:` 列表去掉 `ScanState`。
- `schemaVersion => 9`。
- `onUpgrade` 末尾加：

```dart
if (from < 9) {
  // 1) Backfill: promote every referenced member into the pool so the pool is
  // the single source of truth (favourites added before v9 were snapshots).
  final now = DateTime.now().millisecondsSinceEpoch;
  await customStatement('''
INSERT OR IGNORE INTO tracks
  (source, source_track_id, uri, title, artist, album,
   duration_ms, cover_path, cover_url, created_at, updated_at)
SELECT source, source_track_id, uri, title, artist, album,
       duration_ms, cover_path, cover_url, $now, $now
FROM playlist_tracks
WHERE uri NOT IN (SELECT uri FROM tracks)
''');

  // 2) Rebuild playlist_tracks as a reference-only table. A guarded raw rebuild
  // is used instead of TableMigration so the ordering index is recreated
  // deterministically.
  await _rebuildPlaylistTracksAsReferences();

  // 3) Drop tracks.content_hash (best-effort on old SQLite).
  await _dropColumnIfExists(m, tracks, tracks.contentHash);

  // 4) Drop the unused scan_state table.
  await customStatement('DROP TABLE IF EXISTS scan_state');
}
```

加 helper：

```dart
Future<void> _dropColumnIfExists(
  Migrator m,
  TableInfo table,
  GeneratedColumn column,
) async {
  final rows = await customSelect(
    'PRAGMA table_info(${table.actualTableName})',
  ).get();
  if (!rows.any((row) => row.data['name'] == column.name)) return;
  try {
    await m.dropColumn(table, column);
  } on Exception {
    // SQLite < 3.35 has no DROP COLUMN; leaving the column is harmless.
  }
}
```

加重建 helper（与 `_dropColumnIfExists` 并列）：

```dart
/// Rebuilds `playlist_tracks` to the reference-only v9 shape, preserving
/// `(id, playlist_id, uri, added_at)` and recreating the ordering index.
///
/// Idempotent: a re-run over an already-v9 table is a no-op.
Future<void> _rebuildPlaylistTracksAsReferences() async {
  final cols = await customSelect('PRAGMA table_info(playlist_tracks)').get();
  final names = cols.map((r) => r.data['name']).toSet();
  if (names.contains('added_at') &&
      !names.contains('source') &&
      !names.contains('position')) {
    return; // Already reference-only.
  }
  await customStatement('''
CREATE TABLE playlist_tracks_v9 (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  playlist_id INTEGER NOT NULL,
  uri TEXT NOT NULL,
  added_at INTEGER NOT NULL,
  UNIQUE (playlist_id, uri)
)
''');
  await customStatement('''
INSERT INTO playlist_tracks_v9 (id, playlist_id, uri, added_at)
SELECT id, playlist_id, uri, added_at FROM playlist_tracks
''');
  await customStatement('DROP TABLE playlist_tracks');
  await customStatement(
    'ALTER TABLE playlist_tracks_v9 RENAME TO playlist_tracks',
  );
  await customStatement(
    'CREATE INDEX IF NOT EXISTS idx_playlist_tracks_order '
    'ON playlist_tracks (playlist_id, added_at DESC, id DESC)',
  );
}
```

- [ ] **Step 4: 重新生成 drift 代码**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `app_database.g.dart` 更新，无错误。

- [ ] **Step 5: 改仓储去掉快照列**

`drift_playlist_repository.dart`：
- `addTrack` 的 companion 只保留 `playlistId/uri/addedAt`（promote 已在 Task 2）。
- `_memberQuery` 去掉 `COALESCE`（已是池读取；确保 SELECT 不含快照列）。
- `_coverQuery` 成员封面改为只取 `t.cover_path/t.cover_url`（删 `COALESCE(..., pt.*)`）。
- 删除不再使用的 `_encodeSourceTrackId`。

- [ ] **Step 6: 运行确认通过**

Run: `flutter analyze && flutter test`
Expected: analyze 0；迁移测试与全量测试 PASS。

- [ ] **Step 7: 提交**

```bash
git add -A
git commit -m "feat(db): schema v9 成员表纯引用、回填池、删死 schema"
```

---

### Task 10: 文档与脆弱点注释

**Files:**
- Modify: `docs/architecture.md`（§7.3 “引用视图” → “成员是池的引用”）
- Modify: `docs/local-library.md`（若有快照描述）
- Modify: `lib/features/library/library_screen.dart:65-66`（`LibrarySection` 注释）
- Modify: `lib/core/repositories/favorites_repository.dart` / `playlist_repository.dart` 文档（若 Task 8 未完全清理）

- [ ] **Step 1: 更新文档**

- `architecture.md`：把歌单/收藏描述改为“成员是 `tracks` 池的引用；写入收藏/歌单会先 promote 入池；
  ‘全部’ = `tracks` 中未软删的行”。
- `LibrarySection` 加注释：映射 `(_initialPageIndex - pageIndex) % 3` 依赖 `all` 是枚举索引 0。

- [ ] **Step 2: 全量验证**

Run: `flutter analyze && flutter test`
Expected: analyze 0；`flutter test` 全绿。

- [ ] **Step 3: 提交**

```bash
git add -A
git commit -m "docs: 对齐池/成员语义并标注分页脆弱点"
```

---

## 自审记录

- **Spec 覆盖**：A→Task 2；B→Task 3；C1/C2→Task 5；E→Task 4（含新文件 `track_sorting.dart`）；F→Task 2；G→Task 7；H→Task 6；
  v9/回填/删死 schema→Task 9；封面收敛→Task 8（含 `CoverService` 构造与 provider）；文档与 I 注释→Task 10；`Track.id` 约定→Task 3。
- **占位符**：无 TBD/TODO；每个代码步骤含可执行代码或明确命令。
- **类型一致性**：`promoteTrack(Track) -> Future<int>` 全计划一致；`createPlaylist`/`updatePlaylist`
  签名在 Task 5 定义并被 fake 同步；`isFavoriteProvider` 在 Task 7 定义并使用。
- **Review Focus 对应测试**：软删不复活→Task 1 Step 1；重复 promote 不重排→Task 2 Step 1；
  bilibili 往返→Task 9 迁移测试；空/非法快照回填→Task 9 迁移测试（可再加一条空 title 用例）；
  未知行操作为 no-op→Task 5/8（`clearCover` 与删除方法）。
