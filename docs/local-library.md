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

---

## 4. 离线音频缓存（D9）

### 4.1 目标

Bilibili 音频缓存到本地，实现：

- 播放即缓存（边听边存）
- 手动标记下载（离线可用）
- 默认上限 **1 GiB**，设置中可调
- 超限自动淘汰，**手动下载的条目不淘汰**

### 4.2 存储布局

```
<app support>/
├── covers/<sha1>.webp           # 封面缓存
└── audio_cache/
    ├── bilibili/<sha1>.<ext>    # 在线音频（通常 .m4a）
    └── local/                    # 预留（本地文件不复制）
```

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
  UNIQUE(source, source_track_id)
);
CREATE INDEX idx_audio_cache_lru ON audio_cache(pinned, last_accessed_at);
CREATE INDEX idx_audio_cache_content_hash ON audio_cache(content_hash);
```

设置项（`SettingsRepository`）：缓存只有一个可配置项——上限。

| 键 | 默认 | 说明 |
|---|---|---|
| `cache_limit_bytes` | `1073741824`（1 GiB） | 上限，可自定义 MB / GB |

> 缓存始终开启（在线音频播放时后台写入）；旧版本写入的 `cache_enabled` /
> `cache_auto_on_play` 键不再读取。

### 4.5 淘汰算法（LRU）

```
写入前检查:
  used = SUM(bytes) over DISTINCT file_path   -- 内容去重后多行可共享一个物理文件，只计一次
  if used + new_bytes > limit:
      candidates = SELECT * FROM audio_cache
                   WHERE pinned = 0
                   ORDER BY last_accessed_at ASC
      逐个删除：先删行；仅当没有其他行引用同一 file_path 时才删文件并计入释放量
      if 仍不足（pinned 占用过多）:
          拒绝新的播放缓存；手动下载前提示用户
```

- **内容去重**：下载完成后按字节计算 SHA-1；若已有行索引同一 `content_hash`，
  新下载的文件被删除，本行指向既有物理文件。因此同一份音频只占一份磁盘、只计一次用量。
- **引用计数删除**：`remove` / 淘汰只在最后一个引用该 `file_path` 的行消失时才删文件；
  pinned 行会保护其共享文件不被淘汰。
- 启动时做一次一致性检查：DB 有行但文件不存在 → 清理；文件存在但无行 → 孤儿清理；
  并以 `deduplicateByContent()` 回填旧行哈希、合并历史重复内容。

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
-- 统一曲库（在线 + 本地）
CREATE TABLE tracks (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  source          TEXT    NOT NULL,        -- 'bilibili' | 'local'
  source_track_id TEXT    NOT NULL,        -- bvid:cid | 绝对路径
  uri             TEXT    NOT NULL UNIQUE, -- 'bilibili:BV...:cid' | 'local:/path'
  title           TEXT    NOT NULL,
  artist          TEXT,
  album           TEXT,
  album_artist    TEXT,
  track_no        INTEGER,
  track_total     INTEGER,
  disc_no         INTEGER,
  year            INTEGER,
  duration_ms     INTEGER,
  bitrate         INTEGER,
  sample_rate     INTEGER,
  genre           TEXT,
  cover_hash      TEXT,
  last_seen_at    INTEGER,
  created_at      INTEGER NOT NULL,
  updated_at      INTEGER NOT NULL
);
CREATE INDEX idx_tracks_source ON tracks(source);
CREATE INDEX idx_tracks_album  ON tracks(album, album_artist);

-- 全文检索
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

-- 扫描状态（增量）
CREATE TABLE scan_state (
  key   TEXT PRIMARY KEY,
  value TEXT
);
```

**迁移策略**：drift 的 schema 版本 + 迁移测试；主键用 provider 命名空间的 `uri`，绝不用裸 id。

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
