# 本地曲库与离线缓存设计

> 关联：[`architecture.md`](architecture.md) §7
> 调研日期：2026-09-10

---

## 1. 目标

1. **本地曲库**：扫描用户目录，解析元数据与封面，与在线曲库混合呈现。
2. **离线缓存**：把 Bilibili 音频缓存到本地，默认上限 **1 GiB**，可配置，支持离线播放。

---

## 2. 本地扫描

### 2.1 平台差异

| 平台 | 发现方式 | 权限 |
|---|---|---|
| Android 13+ | MediaStore（`MediaStore.Audio`） | `READ_MEDIA_AUDIO`（`permission_handler` 的 `Permission.audio`） |
| Android ≤12 | MediaStore / 直接路径 | `READ_EXTERNAL_STORAGE` |
| Linux | `dart:io` 递归遍历用户选择的根目录 | 无（Flatpak/Snap 需声明文件系统权限） |

**关键事实：**

- Android 14 的"部分授权"（`READ_MEDIA_VISUAL_USER_SELECTED`）**只影响图片/视频**，音频仍是全有或全无。
- Android 11+ 恢复了媒体文件的**直接路径访问**，性能与 MediaStore 相当 → 可用真实路径喂给纯 Dart 解析器。
- **禁止使用 `MANAGE_EXTERNAL_STORAGE`**（Play 政策不允许音乐播放器滥用）。
- **Android 的"任选文件夹"是 SAF 问题，不是路径问题**：`file_picker.getDirectoryPath()` 返回 `content://` tree URI，`dart:io` 无法遍历。MVP 不做任意目录选择，直接用 MediaStore。

### 2.2 MediaStore 绑定

- 优先：`on_audio_query_pluse` ^3.0.7（维护中的 fork）
- **必须包一层薄适配器** `MediaStoreAdapter`，以便日后替换为 ~40 行 Kotlin MethodChannel
- 原 `on_audio_query` 已 3 年未更新，不使用
- 增量：`MediaStore.getVersion()` 未变化则跳过整轮重扫

### 2.3 元数据解析

**选型：`audio_metadata_reader` ^1.8.0**（纯 Dart）

| 项 | 说明 |
|---|---|
| 平台 | Android / iOS / Linux / macOS / Windows（零原生依赖） |
| 格式 | MP3（ID3v1/v2）、MP4/M4A、FLAC/OGG/Opus、WebM/Matroska、WAV、AIFF、APE |
| 字段 | title / artist / album / albumArtist / trackNo / discNo / year / duration / bitrate / sampleRate / genres / lyrics / pictures |
| 性能 | 3392 首 < 200ms（不含封面），约 400ms（含封面） |

- 快速路径：`readMetadata(file, getImage: false)`
- 逃生舱：`flutter_taglib` ^1.5.2（TagLib FFI、批量读、多 isolate、支持写标签），仅在遇到不支持的格式或需要编辑标签时引入
- **不使用** `metadata_god`（需 Rust 工具链，且 12 个月未更新）

### 2.4 扫描管线

```
根目录
 ├─ Linux:   file_picker.getDirectoryPath() → 持久化到 DB
 └─ Android: READ_MEDIA_AUDIO → MediaStore.Audio 查询
                    │
                    ▼
      发现适配器 → 候选 {path, size, mtime, mediaStoreId}
      （Android: MediaStore.getVersion() 未变 → 整轮跳过）
                    │
                    ▼
      与 drift tracks 做 diff（path + size + mtime 为新鲜度键）
                    │ 仅新增/变更
                    ▼
      提取池（N = 核数-1 个 isolate）
        audio_metadata_reader.readMetadata(File(path), getImage: false)
        → 归一化字段
                    │
                    ▼
      批量 upsert（~500 行/事务）→ tracks + tracks_fts
                    │
                    ▼
      延迟封面 worker（低优先级）
        pictures → 缩放 → covers/<sha1>.webp → tracks.cover_hash
                    │
                    ▼
      UI：drift watch() 流；搜索走 FTS5 MATCH
      维护：本轮未见到的文件 → 软删除（保留播放列表/统计）
```

**鲁棒性规则（必须有）：**

1. 单个不可读目录/子树**绝不**导致整个库清空
2. 空扫描结果**绝不**覆盖已有好数据
3. 临时离线的根目录（如拔出的 SD 卡）保留原有记录，仅标记 `last_seen_at`

> **M2 实现现状与推迟项**
>
> 已实现：目录递归遍历、`isolate` 并行元数据提取（N = 核数-1）、批量入库、软删除（`missing_at`）、
> 封面内容哈希缓存、节流进度流、FTS5 全文检索。
>
> 推迟到后续里程碑：
> 1. **`(mtime, size)` 增量检测** —— 当前按 uri 是否已知来跳过重解析；已入库文件的内容/标签变化不会被发现。需要给 `tracks` 增加 `size`/`mtime_ms` 列（schema v3）。
> 2. **按根目录的软删除保护** —— 当前"空扫描保护"是全局的，且 schema 没有根目录归属列。某个根目录临时离线时，其曲目仍会被软删除（下次成功扫描会恢复）。规则 3 目前只部分满足。
> 3. **封面缩放** 已实现（512px JPEG），但**未做**多尺寸/懒加载缩略图。

---

## 3. 封面策略

- 内嵌封面：`audio_metadata_reader` 的 `pictures`
- Android 系统封面兜底：`on_audio_query_pluse.queryArtwork()`
- **两遍法**：第一遍不取图（快）；第二遍低优先级按需提取
- **内容寻址缓存**：图片字节 SHA-1 → `covers/<hash>.webp`（缩放到 256–512px）
  - 存在 `<app support>/covers/`（**不要用临时目录**，系统会清理）
  - 专辑封面天然去重（同专辑多曲共享 hash）
- 解码/缩放必须在非 UI isolate

### 3.1 在线（Bilibili）远程封面

内嵌封面只覆盖本地文件；B 站音源需要单独抓取视频封面（`pic` / 收藏夹 `cover`）：

- **来源**：搜索/详情/收藏夹 DTO 已带封面 URL，`bili_mappers` 透传并归一化；
  `searchItemToTrack` / `favoriteResourceToTrack` / `videoPageToTrack` 写入
  `Track.coverUrl`。缺失时用 `bvid` 调 `/x/web-interface/view` 兜底。
- **归一化**：`normalizeCoverUrl` 把 `//host/...` 与 `http://` 升到 `https://`，
  并剥掉既有 CDN 处理后缀（`@672w_...`），保证同一图片的缓存键稳定。
- **缓存**：`CoverCacheStore` 以 `sha1(归一化 URL)` 为键索引、以 `sha1(图片字节)`
  命名文件（`cache/cover/<contentHash>.jpg`）。**图片字节原样落盘，不缩放、不重编码**
  （文件扩展名固定为 `.jpg`，内容按原始字节存储）。相同图片在不同 URL 下只占一份磁盘。
- **层 1 / 层 2 路由**：歌曲**已在音频缓存中**时，封面存入**层 1**（随行封面，
  写回 `audio_cache.cover_path`，见 §4）；**未缓存**时存入**层 2**。
  `tracks.cover_path` 是唯一对外引用，可指向任一层，悬空由 `File.existsSync()` 兜底回落。
- **独立配额**：层 2 固定 256 MiB 且每次启动整体清空，**不计入**音频缓存上限
  （见 §4.4/§4.5）。
- **触发**：`CoverPrefetchCoordinator` 监听播放队列，**进队即拉**；命中本地文件即跳过，
  失败按 10 分钟退避重试，最多 4 个并发。解析成功后只写回池行 `tracks.cover_url` /
  `tracks.cover_path`（经 `updateTrackCover`，不触碰 `added_at`，不会重排）；歌单成员是池的
  纯引用，封面随池行自动更新，无需另写成员列。
- **多 P 视频**：`pic` 是视频级封面，各分 P 共用同一张（预期行为）。

---

## 4. 离线音频缓存（D9）

### 4.1 目标

Bilibili 音频缓存到本地，实现：

- 播放即缓存（边听边存）
- 手动标记下载（离线可用）
- 默认上限 **1 GiB**，设置中可调
- 超限自动淘汰，**手动下载的条目不淘汰**

### 4.2 存储布局

单一缓存根 `<app support>/cache/`，**两个缓存各占一个互不重叠的子树**（否则一方的
递归清理/孤儿清理会误删另一方文件）：

```
<app support>/
├── covers/                                 # 本地内嵌封面缓存（ArtworkCache，不入配额）
└── cache/                                  # 唯一缓存根
    ├── audio/                              # 层 1 根（AudioCacheStore.baseDir）
    │   └── <source>/
    │       ├── <sha1(source:trackId)>.<ext>          # 层 1 音频
    │       └── <sha1(source:trackId)>.cover.<ext>    # 层 1 随行封面（扩展名按图片魔数）
    └── cover/                              # 层 2 根（CoverCacheStore.baseDir）
        └── <sha1(图片字节)>.jpg                        # 层 2 临时封面
```

- 层 1 音频沿用 `sha1(source:trackId)` 的确定性命名；内容去重仍在 `insert` 时通过
  指向既有 canonical 文件实现（`file_path` 可被多行共享），**文件名不改成内容哈希**。
- 层 2 保持内容寻址（`sha1(字节)` 文件名），保留 URL→内容去重。
- 层 1 的两个路径（音频与随行封面）都落在同一子树内，因此删除统一由一个
  containment guard 覆盖，不需要跨目录特例。
- 旧根 `<app support>/audio_cache/` 与 `<app support>/cover_cache/` 在**启动自愈**时
  一次性搬入新根（`CacheRelocator`）并改写 `file_path`；搬迁失败时旧路径仍可用
  （`file_path` 是权威），下次启动重试。

### 4.3 两种模式

| 模式 | 触发 | pinned | 参与淘汰 |
|---|---|---|---|
| **播放缓存**（stream） | 播放时自动写入 | 否 | 是（LRU） |
| **手动下载**（download） | 用户显式操作 | 是 | 否 |

### 4.4 数据模型

```sql
CREATE TABLE audio_cache (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  source           TEXT    NOT NULL,       -- 'bilibili'
  source_track_id  TEXT    NOT NULL,       -- 'BV...:cid'
  file_path        TEXT    NOT NULL,
  bytes            INTEGER NOT NULL,
  quality_id       TEXT    NOT NULL,       -- '30280' 等
  pinned           INTEGER NOT NULL DEFAULT 0,
  cached_at        INTEGER NOT NULL,
  last_accessed_at INTEGER NOT NULL,
  content_hash     TEXT,                   -- v6: 文件字节的 SHA-1，去重键（旧行为 NULL）
  cover_path       TEXT,                   -- v10: 层 1 随行封面路径（NULL = 无封面）
  cover_bytes      INTEGER NOT NULL DEFAULT 0,  -- v10: 随行封面字节数，计入层 1 配额
  UNIQUE(source, source_track_id)
);
CREATE INDEX idx_audio_cache_lru ON audio_cache(pinned, last_accessed_at);

-- v10：补齐热路径索引（去重查找 / 驱逐引用检查，消除全表扫描与 N+1）
CREATE INDEX idx_audio_cache_content_hash ON audio_cache(content_hash);
CREATE INDEX idx_audio_cache_file_path    ON audio_cache(file_path);

-- v7：远程封面缓存（v10 起语义收窄为**层 2**：仅未缓存歌曲的临时封面）
CREATE TABLE cover_cache (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  url_hash         TEXT    NOT NULL UNIQUE,  -- sha1(归一化封面 URL)，查找键
  file_path        TEXT    NOT NULL,
  content_hash     TEXT    NOT NULL,         -- sha1(图片字节)，同时是文件名
  bytes            INTEGER NOT NULL,
  cached_at        INTEGER NOT NULL,
  last_accessed_at INTEGER NOT NULL
);
CREATE INDEX idx_cover_cache_lru ON cover_cache(last_accessed_at);
CREATE INDEX idx_cover_cache_content_hash ON cover_cache(content_hash);
CREATE INDEX idx_cover_cache_file_path    ON cover_cache(file_path);

-- v7：封面 URL 随轨道持久化，淘汰后无需再请求 view 接口
ALTER TABLE tracks ADD COLUMN cover_url TEXT;
```

> **v10 变更**：`audio_cache` 即「歌曲资产行」——一行 = 一个已缓存歌曲的音频 + 可选的
> 随行封面，**行级同生共死**（表名不变）。`cover_cache` 收窄为层 2，独立配额。
> `audio_cache.last_accessed_at` 已由 `idx_audio_cache_lru` 覆盖，不重复建索引。
>
> **v8 变更**：`favorites` 表已移除。收藏改为内置歌单（`playlists` 行 `kind='favorites'`，id=1），
> 旧收藏数据在 v7→v8 迁移中并入 `playlist_tracks`（`favorited_at` → `added_at`），随后删除
> `favorites` 表；v9 再把 `playlist_tracks` 收敛为对池的纯引用（见 §5）。

设置项（`SettingsRepository`）：缓存只有一个可配置项——上限。

| 键 | 默认 | 说明 |
|---|---|---|
| `cache.limitBytes` | `1073741824`（1 GiB） | **层 1 非 pinned 行**的字节上限（音频 + 随行封面），设置页以 **MB** 为单位编辑（无 MB/GB 选择器）；层 2 用固定 256 MiB，无需设置项 |

> 缓存始终开启（在线音频播放时后台写入）；旧版本写入的 `cache_enabled` /
> `cache_auto_on_play` 键不再读取。

### 4.5 配额与淘汰（按歌曲 · LRU）

配额是**按歌曲**分配的：已缓存歌曲的音频与它的封面同属**一条记录**，因此不存在
「封面永远先让路」，两个缓存也互不协调。

| 配额 | 约束对象 | 可配 |
|---|---|---|
| `limitBytes`（1 GiB 默认） | 层 1 **非 pinned** 行（音频字节 + `cover_bytes`） | 是（设置页现有项，显示不变） |
| 固定 **256 MiB**（`CoverCacheStore.ephemeralLimitBytes`） | 层 2 临时封面 | 否 → 无需新增配额 UI |
| — | **pinned / 离线** | **不占任何配额** |

```
层 1 写入前检查（AudioCacheStore.ensureSpace）:
  used = SUM(bytes) over DISTINCT file_path(audio_cache)   -- 共享音频只计一次
       + SUM(cover_bytes) where cover_path IS NOT NULL     -- 每行封面各计一次
  if used + new_bytes > limitBytes:
      -- 按行淘汰最旧：非 pinned 行，连同其随行封面一起删
      candidates = SELECT * FROM audio_cache
                   WHERE pinned = 0 ORDER BY last_accessed_at ASC
      逐行删除：先删行；音频文件仅在没有其他行引用同一 file_path 时才删并计入释放量；
                随行封面每行独占，随行删除并计入释放量
      if 仍不足:
          hasSpace = false → 拒绝新的播放缓存（不驱逐 pinned）

层 2 写入前检查（CoverCacheStore.ensureSpace）:
  used = SUM(bytes) over DISTINCT file_path(cover_cache)
  if used + new_bytes > 256 MiB:
      candidates = SELECT * FROM cover_cache ORDER BY last_accessed_at ASC
      逐行删除：先删行；文件仅在没有其他行引用同一 file_path 时才删并计入释放量
```

- **封面随歌同生共死**：层 1 驱逐按**行**进行，删除该行时一并删除其 `cover_path`。
  已缓存歌曲的封面不会被音频驱逐挤掉，也不再与音频争配额——**P1 消失**。
- **两 store 不跨表读写**：层 1 只读 `audio_cache`、层 2 只读 `cover_cache`，
  各自单一所有者，**无需配额协调器**。
- **层 2 是会话级的**：启动时整体清空（`main.dart` 挂在现有启动自愈旁，fire-and-forget），
  因此层 2 不需要独立 `checkIntegrity`；未下载歌曲的封面每次启动会重新拉取。
- **层 1 → 层 2 回落**：驱逐层 1 后 `tracks.cover_path` 悬空，由现有
  `File.existsSync()` 兜底，重新解析时落入层 2。
- **层 2 → 层 1 拷贝**：封面已在层 2、随后该歌音频被缓存时，**拷贝**一份进层 1
  （不搬移，避免抽走可能被其它曲目共享的文件）；层 2 副本按 LRU/重启自然消失。
- **离线封面是硬约束**：手动下载（pinned）完成后必须确保随行封面已入层 1
  （必要时即时抓取，best-effort 失败不阻塞下载），否则重启清空层 2 后离线歌无封面。
- **内容去重**：下载完成后按字节计算 SHA-1；若已有行索引同一 `content_hash`，
  新下载的文件被删除，本行指向既有物理文件。因此同一份音频只占一份磁盘、只计一次用量。
  引用计数**仅**用于音频内容去重。
- **引用计数删除**：`remove` / 淘汰只在最后一个引用该 `file_path` 的行消失时才删文件；
  pinned 行会保护其共享文件不被淘汰。
- 启动时做一次一致性检查：DB 有行但文件不存在 → 清理；文件存在但无行 → 孤儿清理；
  并以 `deduplicateByContent()` 回填旧行哈希、合并历史重复内容。
  另在启动自愈里把旧根 `audio_cache/`、`cover_cache/` 的文件搬入 `cache/`（见 §4.2）。

> **pinned 豁免配额是有意决策**：上限**不再约束总磁盘占用**，用户可无限下载，
> 需在发布说明注明。代价与风险见
> [`superpowers/specs/2026-09-26-cache-refactor-design.md`](superpowers/specs/2026-09-26-cache-refactor-design.md) §13。

> **离线 / pinned 的管理入口**：设置页新增独立的「**离线缓存**」区块（列表 + 用量 +
> 单条删除 + 全部清空），与曲库行的下载按钮状态一致。设置页原有的缓存区块**显示不变**，
> 但「**清空缓存**」现在是**只清在线**——层 1 非 pinned 行 + 整个层 2，**不误伤**
> pinned/离线下载。

### 4.6 播放集成

```dart
// resolveStream 内部优先级
Future<StreamInfo> resolveStream(Track track) async {
  // 1. 命中缓存 → 本地直放，无需 headers
  final cached = await cache.lookup(track.sourceTrackId);
  if (cached != null) {
    await cache.touch(cached.id);          // 更新 last_accessed_at
    return StreamInfo(url: Uri.file(cached.filePath), headers: const {});
  }

  // 2. 解析在线流
  final info = await bili.resolve(track);

  // 3. 在线流解析成功后，后台边播边写（缓存始终开启，唯一可配置项是上限）
  unawaited(downloader.enqueue(track, info, pinned: false));
  return info;
}
```

### 4.7 下载队列

- 单并发（与 Bilibili 限流策略一致）
- 支持 HTTP Range 断点续传
- 失败退避重试（复用 `RateLimiter` 的退避策略）
- 下载中可见进度；失败可重试
- 流 URL 120 分钟过期 → 下载前校验，过期则重新解析

> **M3 实现现状**
>
> 已实现：`audio_cache` 索引表（schema v3，v6 起含 `content_hash`）、内容哈希去重（同一份音频只存/只计一次）、
> LRU 淘汰（pinned 豁免，引用计数删除）、下载器（`.part` 暂存 + 完成才 rename + `Range` 断点续传 + 指数退避重试 +
> 403/404 立即判定 URL 过期）、单并发下载队列（FIFO）、缓存优先解析器（命中返回 `file:` 且 **headers 为空**）、
> 缓存设置（唯一项：上限，默认 1 GiB，可自定义 MB/GB）、完整性检查（清理无文件的索引行 + 孤儿文件 + 合并历史重复内容）。
>
> 实现细节与偏差：
> 1. **容量检查分两次**：`StreamInfo` 不含字节数，下载前只能按估算值（未知时为 0）预留；下载完成后按**真实
>    字节数**再检查一次，仍不足则删除已下载文件并报失败。因此单曲**不会**突破上限。
> 2. **文件扩展名**由 URL 路径后缀推断（后缀 ≤5 字符且为 `[a-z0-9]+` 时直接采用，B 站通常得到 `.m4s`）；
>    否则 bilibili 用 `.m4a`、其他用 `.mp3`。
> 3. **pinned 可后置更新**：缓存命中后再次请求 `pinned: true` 会只更新固定标记（播放缓存可被提升为手动下载），
>    不会重新下载。
> 4. 手动下载时若 pinned 条目已占满额度，新下载会被拒绝（不会淘汰 pinned 条目）。

---

## 5. 数据库 Schema（drift）

```sql
-- 统一曲库（在线 + 本地）—— 唯一的曲库池
CREATE TABLE tracks (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  source          TEXT    NOT NULL,        -- 'bilibili' | 'local'
  source_track_id TEXT    NOT NULL,        -- bvid:cid | 绝对路径
  uri             TEXT    NOT NULL UNIQUE, -- 'bilibili:BV...:cid' | 'local:/path'（规范键）
  title           TEXT    NOT NULL,
  artist          TEXT,
  album           TEXT,
  album_artist    TEXT,
  track_no        INTEGER,
  disc_no         INTEGER,
  year            INTEGER,
  duration_ms     INTEGER,
  bitrate         INTEGER,
  sample_rate     INTEGER,
  genre           TEXT,
  cover_path      TEXT,                    -- 本地封面文件路径
  cover_url       TEXT,                    -- v7: 远程封面 URL
  last_seen_at    INTEGER,
  size_bytes      INTEGER,                 -- v5: (mtime, size) 新鲜度键
  mtime_ms        INTEGER,                 -- v5
  scan_root       TEXT,                    -- v5: 发现该曲目的扫描根（软删除作用域）
  missing_at      INTEGER,                 -- 软删除时间戳
  created_at      INTEGER NOT NULL,
  updated_at      INTEGER NOT NULL
);

-- 全文检索（外部内容表，content_rowid='id'）
CREATE VIRTUAL TABLE tracks_fts USING fts5(
  title, artist, album, content='tracks', content_rowid='id'
);

-- 扫描根目录
CREATE TABLE scan_roots (
  id       INTEGER PRIMARY KEY AUTOINCREMENT,
  path     TEXT    NOT NULL UNIQUE,
  kind     TEXT    NOT NULL,               -- 'local'
  added_at INTEGER NOT NULL
);

-- v8：歌单（内置收藏 + 自建）
CREATE TABLE playlists (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  name        TEXT    NOT NULL,            -- 必填、非空白
  kind        TEXT    NOT NULL,            -- 'favorites'（内置，id=1）| 'custom'
  description TEXT,
  cover_path  TEXT,                        -- 显式封面（覆盖派生回退链）
  cover_url   TEXT,
  created_at  INTEGER NOT NULL,
  updated_at  INTEGER NOT NULL
);

-- v9：歌单成员（对 `tracks` 池的纯引用，不复制元数据）
CREATE TABLE playlist_tracks (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  playlist_id INTEGER NOT NULL,
  uri         TEXT    NOT NULL,            -- 规范池键（local:<path> / bilibili:<bvid>:<cid>）
  added_at    INTEGER NOT NULL,            -- 加入时间（= 旧收藏 favorited_at），排序键
  UNIQUE(playlist_id, uri)                 -- 同一首歌可进多个歌单
);
CREATE INDEX idx_playlist_tracks_order
  ON playlist_tracks(playlist_id, added_at DESC, id DESC);
```

**迁移策略**：drift 的 schema 版本 + 迁移测试；主键用 provider 命名空间的 `uri`，绝不用裸 id。

> **v8 迁移**：新增 `playlists` / `playlist_tracks` 两表与 `idx_playlist_tracks_order` 索引；
> 内置收藏歌单以 `INSERT OR IGNORE` 播种（id=1）；旧 `favorites` 表存在时，其行并入
> `playlist_tracks`（`favorited_at` → `added_at`），随后 `DROP TABLE favorites`。
> `favorites` 表自此移除。
>
> **v9 迁移**：`playlist_tracks` 由「引用 + 元数据快照」收敛为对池的纯引用。先把每个成员的
> 快照回填（`INSERT OR IGNORE`）进 `tracks` 池（v9 前的收藏是快照，不回填会丢元数据），再重建
> 表为上面的引用形态并重建排序索引；同时删除 `tracks.content_hash`（v8 只建列未填充）与未用
> 的 `scan_state` 表。每步都按物理列存在性守卫，可重复执行。

---

## 6. 性能规则

| 规则 | 原因 |
|---|---|
| 第一遍扫描 `getImage: false` | 3392 首 < 200ms vs ~400ms |
| 单一写路径 + 批量事务（~500 行/事务） | SQLite 写入吞吐 |
| `(mtime, size)` + `MediaStore.getVersion()` 跳过未变更 | 避免全量重扫 |
| 进度事件节流（~10 Hz） | 避免 UI 抖动 |
| 软删除而非级联删除 | 保护用户播放列表/统计 |
| 提取池 N = 核数-1 isolate | 并行且不饿死 UI |

---

## 7. 依赖清单

| 包 | 版本 | 用途 |
|---|---|---|
| `audio_metadata_reader` | ^1.8.0 | 元数据解析（纯 Dart） |
| `drift` + `drift_flutter` | ^2.35.0 | SQLite + FTS5 |
| `permission_handler` | ^13.0.2 | `Permission.audio` |
| `file_picker` | ^12.2.0 | 桌面目录选择 |
| `on_audio_query_pluse` | ^3.0.7 | Android MediaStore（包适配器后使用） |
| `flutter_secure_storage` | latest | 凭证（与本地库共用基础设施） |
| `path_provider` | latest | 应用私有目录 |

**Linux 系统依赖**：`libsecret`（凭证）、`libmpv-dev` + `mpv`（播放）、`libayatana-appindicator3-dev`（托盘）。

> 各依赖许可证与 GPL-3.0 的兼容性见 [`architecture.md`](architecture.md) §12。

---

## 8. 陷阱清单

| 陷阱 | 说明 |
|---|---|
| Android 任意目录选择 | `getDirectoryPath()` 返回 `content://`，`dart:io` 不可用；需 SAF DocumentFile 遍历，MVP 不做 |
| `MANAGE_EXTERNAL_STORAGE` | Play 政策禁止音乐播放器使用 |
| 临时目录存封面 | 系统会清理，必须用 app support 目录 |
| 明文存储凭证 | SESSDATA 必须进 secure storage |
| `metadata_god` | 需 Rust 工具链 + 12 个月未更新 |
| `taglib_ffi` | 已死（3 年未更新，仅 macOS 测试过） |
| 原版 `on_audio_query` | 3 年未更新，用 `_pluse` fork |
| 空扫描覆盖好数据 | 必须有"空结果不覆盖"保护 |
| 淘汰时误删手动下载 | `pinned = 1` 不参与 LRU |
