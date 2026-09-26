# 设计：歌单/收藏收敛到单一曲目池（schema v9）

- 日期：2026-09-26
- 状态：待实现
- 范围：数据模型、歌单/收藏仓储、相关 UI、迁移与测试
- 目标读者：实现者

## 1. 背景

当前数据库把“曲目身份”分散在三处：`tracks` 池用 `uri`；`playlist_tracks` 同时存 `uri` 与
一套完整元数据快照；`audio_cache` 用 `(source, source_track_id)`。歌单/收藏的读取走
`LEFT JOIN tracks ... COALESCE(池, 快照)`，形成“引用 + 快照”的双份真相。

一次独立复核（`ses_f2c8d0b0fffeSvpe1zgex0eQVM`，本仓库代码复核）确认：双份真相直接制造了
“收藏不入全部”等缺陷，且快照的存在理由（成员在曲目离库后仍可解析）实际已由 `tracks` 的软删除
`missing_at` 覆盖。因此把成员收敛为纯引用、所有写入先落池，既修缺陷又消除冗余。

## 2. 目标与非目标

### 目标
- 消灭“引用 + 快照”双真相：曲目身份只有一个集合 `tracks`。
- 修复已确认的行为缺陷：A（收藏不入“全部”）、B（歌单成员全部不可用）、C（封面创建丢失/清除无效）、
  E（“最近添加”排序空转）、F（重加重置 `added_at`）、H（B站收藏夹行缺动作集）、G（重复 provider / 死分支）。
- 清理已确认的死 schema：`scan_state`、`tracks.content_hash`、`playlist_tracks.position`。

### 非目标
- **不改**数据层骨架：`tracks` 单池、`uri` 规范键、软删除 `missing_at`、逐版本迁移守卫。
- **不删** `tracks` 的 7 个展示用元数据列（`album_artist / track_no / disc_no / year / bitrate /
  sample_rate / genre`）：本地文件本就有，未来信息页会用。可选优化（缩小队列快照）留待后续。
- 不重写 FTS5 机制、不改音频/封面缓存的配额与 LRU。
- 不改 `I`（循环 `PageView`）的设计，仅补注释。

## 3. 已确认的语义决策

1. **`tracks` = 唯一“已保存曲目”集合；“全部” = `tracks` 中 `missing_at IS NULL` 的行。**
2. **写入收藏或歌单时，先 promote 落池，再写成员引用。池只增不减。**
3. **取消收藏 / 移出歌单不动池**；“从曲库删除”仍是独立的 `deleteTrack`。
4. `playlist_tracks` 降级为**纯引用**，成员元数据/封面/来源身份全部来自 `tracks`。
5. **可用性唯一判据**：池行存在且 `missing_at IS NULL`。本地文件消失时，从“全部”隐藏，在收藏/歌单中
   标“不可用”（置灰、不可点），软删除记录保留。
6. 收藏仍是 pinned 的 `playlists` 行（`id = 1, kind = 'favorites'`），不变。
7. 未被任何收藏/歌单引用**不会**从“全部”移除；只增不减。

## 4. 目标架构与不变量

- 单一身份：`tracks.uri`。
- 成员表只存 `(playlist_id, uri, added_at)`。
- 读取成员 = `JOIN tracks`，`id = missing_at IS NULL ? t.id : null`。
- `Track.id == null` 约定为“不可用”（未在池中或已软删）。该约定须写入 `Track.id` 的文档注释，
  避免再次被误用为“未插入”。
- 所有把曲目加入收藏/歌单的入口统一走 promote，杜绝再次出现“成员不在池中”。

## 5. 数据模型（schema v9）

### 5.1 `playlist_tracks`（重建后）
保留列：
- `id`（自增主键）
- `playlist_id`
- `uri`
- `added_at`

删除列：`source, source_track_id, title, artist, album, duration_ms, cover_path, cover_url, position`。

约束与索引不变：
- `UNIQUE(playlist_id, uri)`
- 排序索引 `idx_playlist_tracks_order ON playlist_tracks (playlist_id, added_at DESC, id DESC)`

### 5.2 `tracks`
- 删除列 `content_hash`（仅 v8 建列、从未读写）。

### 5.3 `scan_state`
- 删除表及 `@DriftDatabase` 中的 `ScanState` 注册；删除 `ScanState` 表类定义。

## 6. 迁移 v8 → v9

`AppDatabase.schemaVersion` 8 → 9；在 `onUpgrade` 增加 `if (from < 9)` 块。所有步骤幂等、可重跑。

1. **回填池**：把成员引用的曲目补进 `tracks`（尤其是老库中只在收藏/歌单、从未入池的在线曲目）。
   ```sql
   INSERT OR IGNORE INTO tracks
     (source, source_track_id, uri, title, artist, album,
      duration_ms, cover_path, cover_url, created_at, updated_at)
   SELECT source, source_track_id, uri, title, artist, album,
          duration_ms, cover_path, cover_url, :now, :now
   FROM playlist_tracks
   WHERE uri NOT IN (SELECT uri FROM tracks)
   ```
   回填行的 `missing_at`、指纹列等留空（视为已知可用）；下次本地扫描会按实际文件纠正。

2. **重建 `playlist_tracks`** 为 5.1 的四列形状：优先用 drift `TableMigration`（按新 schema
   重建、自动拷贝同名列）；若生成 API 不便，则用“新表 + `INSERT SELECT` + `DROP` + `RENAME`”。
   随后重建排序索引。

3. **删除 `tracks.content_hash`**：封装 `_dropColumnIfExists(m, tracks, tracks.contentHash)`，
   先 `PRAGMA table_info` 判断，再 `ALTER TABLE tracks DROP COLUMN content_hash`；旧 SQLite
   （< 3.35）不支持时静默跳过（列残留无害）。**不要**重建 `tracks` 表，以免波及 FTS 触发器。

4. **删除 `scan_state`**：`DROP TABLE IF EXISTS scan_state`。

5. 重新生成 `app_database.g.dart`（`dart run build_runner build --delete-conflicting-outputs`）。

## 7. 仓储接口变更

### 7.1 `MusicLibraryRepository`（核心新增）
```dart
/// Promotes [track] into the pool without touching an existing row.
///
/// INSERT ... ON CONFLICT(uri) DO NOTHING: the pool always wins, and an
/// existing soft-deleted row stays soft-deleted.
Future<int> promoteTrack(Track track);
```
- 不用现有 `upsertTrack`：它会覆盖既有池元数据。`DO NOTHING` 贴合“只增不减、池优先”。
- 实现注意：`insertReturning` 配 `DoNothing` 在冲突时不会返回行。用 `insertReturningOrNull`
  失败后回退到 `findByUri(uri)` 取 id，或先 `insert(..., onConflict: DoNothing())` 再 `findByUri`。
- 边界：本地文件已丢但池中从无该行时，会以 `missing_at = null` 插入，直到下次扫描纠正为缺失。

### 7.2 `PlaylistRepository`
- `addTrack(playlistId, track)`：先 `library.promoteTrack(track)`，再 upsert 成员
  `(playlist_id, uri, added_at)`；冲突 `DO NOTHING`（**不再刷新 `added_at`** → 修 F）。
  `DriftPlaylistRepository` 注入 `MusicLibraryRepository`（或等价的 promote 接口）。
- `watchPlaylistTracks` / `playlistTracks`：改为 `JOIN tracks`，只读池列：
  ```sql
  SELECT t.id AS pool_id, t.source, t.source_track_id, t.title, t.artist,
         t.album, t.duration_ms, t.cover_path, t.cover_url, t.missing_at
  FROM playlist_tracks pt
  JOIN tracks t ON t.uri = pt.uri
  WHERE pt.playlist_id = ?1
  ORDER BY pt.added_at DESC, pt.id DESC
  ```
  `_toDomain`：`id = missing_at == null ? pool_id : null`。
- **删除** `updateTrackCover`（成员封面列消失）。
- `createPlaylist({name, description, coverPath, coverUrl})`（修 C1）。
- `updatePlaylist(id, {name, description, coverPath, coverUrl, clearCover = false})`：
  `clearCover == true` 时对 `coverPath`/`coverUrl` 写 `Value(null)`（修 C2）。
- `_coverQuery` / `watchPlaylistCover`：成员封面列删除后，回退链改为“显式歌单封面 → 最新成员的
  池封面 → null”，去掉快照回退。
- 同步更新 `PlaylistRepository` / `FavoritesRepository` 的文档注释：删除“denormalised snapshot /
  pool-first snapshot-fallback”的过时描述，改为“成员是池的引用”。

### 7.3 `FavoritesRepository`
- `addFavorite` 不变（委托 `addTrack`，自动 promote → 修 A）。
- **删除** `updateFavoriteCover`。

### 7.4 `cover_service`
- `_persist` 只保留写池的 `_library.updateTrackCover`，删除 `_favorites.updateFavoriteCover` 调用。
- 成员封面不再单独缓存：封面存于池行，成员读取时 JOIN 得到。

## 8. UI 行为变更

| 位置 | 变更 |
|---|---|
| 歌单详情 `playlist_detail_screen.dart` | 无需改代码，`unavailable: track.id == null` 随 JOIN 自动正确（修 B） |
| 收藏页 `library_screen.dart` | `_trackList`/`_trackGrid` 传 `unavailable: track.id == null`，缺失项置灰（与歌单一致） |
| `_sortTracks` 的 `recentlyAdded` | 改为保留 SQL `added_at DESC` 顺序（比较器恒 0 + 注释）；池 id ≠ 收藏时间（修 E） |
| 歌单编辑器 `playlist_editor_dialog.dart` | 创建分支传 `coverPath/coverUrl`（修 C1）；移除封面传 `clearCover: true`（修 C2） |
| B站收藏夹行 `bilibili_favorites_screen.dart` | 裸 `IconButton` 换 `TrackActionsButton(track, showSaveToLibrary: true, onSaveToLibrary: …)`（修 H） |
| 重复收藏 provider / `_cacheTrack` 死分支 | 合并为共享 provider；删死分支（修 G） |
| `LibrarySection` | 补注释：映射依赖 `all == 索引 0`（记录 I 的脆弱点） |

## 9. 测试计划

### 新增/修改（单元）
- `MusicLibraryRepository.promoteTrack`：幂等；池已存在时不覆盖；软删行保持软删。
- `favorites_repository_test`：`addFavorite` 后池中出现该行（**反转**现有
  `independence from the library` 用例）。
- `playlist_repository_test`：`addTrack` 后池中出现该行；重复 add 不改变 `added_at` 与顺序；
  成员 `id` 在池存在且未软删时非空、软删时为 null；替换原快照相关用例与 `updateTrackCover` 组。
- `PlaylistRepository.createPlaylist` 带封面可持久化；`updatePlaylist(clearCover: true)` 生效。
- `library_sort` / `_sortTracks`：`recentlyAdded` 保持传入顺序。

### 迁移（`drift_music_library_repository_test.dart` 的 `schema migration` 组）
- 构造 v8 fixture，含只存在于 `playlist_tracks`（不在 `tracks`）的成员。
- 升级到 v9 后：成员仍在；“全部”可见（池已回填）；`playlist_tracks` 为新表形状；
  `tracks` 无 `content_hash`；`scan_state` 不存在；重复运行迁移安全。

### Widget
- 歌单详情含池内成员：可点、可用。
- 歌单成员对应池软删：置灰、显示“不可用”、不可点。
- 收藏页缺失项置灰。
- B站收藏夹行出现收藏/缓存/加入歌单菜单项。

### 基线
- `flutter analyze` 0 问题；`flutter test` 全绿（用例数会因增删变化）。

### 测试爆炸半径
删除 `PlaylistRepository.updateTrackCover` 与 `FavoritesRepository.updateFavoriteCover` 会影响
**17 个测试文件**中的 fake 实现，属机械修改。

## 10. 风险与行为变化

- **老用户可见变化**：回填会把此前“只在收藏/歌单、未入池”的在线曲目推入“全部”。这是期望语义，
  需在发布说明注明。
- **`Track.id == null` 约定**：语义从“未插入”扩展为“不可用”，必须文档化。
- **`DROP COLUMN` 兼容性**：用 `_dropColumnIfExists` 守卫，旧 SQLite 跳过而非失败。
- **FTS**：迁移不重建 `tracks` 表，触发器不受影响。

## 11. 建议执行顺序

1. schema v9：表结构、迁移、回填、迁移测试、重生成代码。
2. 仓储收敛：`promoteTrack`、成员 JOIN、删两个接口方法、封面签名、`cover_service`。
3. UI：可用性（收藏页）、E、C、H、G、注释。
4. 全量回归：analyze + test。
