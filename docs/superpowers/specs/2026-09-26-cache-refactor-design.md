# 设计：缓存重构 —— 按歌曲配额 + 双配额（schema v10）

- 日期：2026-09-26
- 状态：待实现
- 范围：缓存存储布局、数据模型、配额与驱逐、封面生命周期、迁移与测试、设置页离线管理
- 目标读者：实现者
- 关联：[`docs/缓存TODO.md`](../../缓存TODO.md)、[`docs/local-library.md`](../../local-library.md) §3/§4、[`docs/architecture.md`](../../architecture.md) §7

## 1. 背景

项目现有三类内容缓存与一类配置：

- **音频缓存** `audio_cache`：在线（播放缓存，`pinned=false`）与离线（手动下载，`pinned=true`）共用一张表；
- **远程封面缓存** `cover_cache`：以 `sha1(归一化 URL)` 为键、`sha1(字节)` 为文件名；
- **本地内嵌封面** `covers/`（`ArtworkCache`）：不入配额；
- **配置**：`shared_preferences`（`SettingsRepository`）。

`docs/缓存TODO.md` 已逐行核实并列出问题 P1–P5。核心结构性缺陷是：

- **P1**：音频与封面**共用同一字节配额**，且驱逐永远“封面全清 → 再动音频”。曲库占满配额后封面缓存实际归零、反复重下（缓存抖动）。
- **P4**：同一套“合并字节 ≤ 限额、封面先驱逐”策略被 `AudioCacheStore` 与 `CoverCacheStore` 各实现一遍，且互相跨表读写，改一侧另一侧必漂移。

本设计的核心洞察：问题的本质是**按资产类型（音频 vs 封面）分配配额**，而正确的模型是**按歌曲分配配额**。若一首歌的音频与其封面作为同一条缓存记录同生共死，就不存在“封面永远先让路”，也不需要跨表协调器。

## 2. 目标与非目标

### 目标
- **消除 P1**：已缓存歌曲的封面随歌同生共死，不再被音频饥饿。
- **消除 P4**：不再需要跨表协调器；两个缓存各自独立、单一所有者。
- **顺带解决 P3**：补齐 `content_hash` / `file_path` 索引，消除全表扫描与驱逐 N+1。
- **单一缓存根目录**；DB 负责索引与配额。
- **新增离线缓存管理入口**（列表 + 单条删除 + 全部清空）。

### 非目标
- **P2（预检真实长度）延期**：`StreamInfo` 仍不透出长度，`_estimateBytes` 维持 0。见 §12。
- **P5 不修**：`freedBytes`/`evictedCount` 展示口径与并发软上限视为已知行为。
- **歌词缓存不做**：当前无歌词源、无 `LyricsProvider`，仅 UI 占位（`lib/features/player/lyrics_view.dart`）。行结构预留扩展点，不提前加列（YAGNI）。
- **不改本地内嵌封面** `ArtworkCache`（`covers/`，不入配额）。
- 不引入独立缓存框架/内存缓存层。
- 不做跨进程/多窗口设置同步。

## 3. 已确认的语义决策

1. **pinned / 离线缓存不占任何配额**（有意决策；代价见 §13）。
2. **层 2 固定 256 MiB**；会话内按 LRU 淘汰最早项；**每次启动整体清空**。
3. **`audio_cache` 表不改名**，补注释说明它已是“歌曲资产行”。
4. **设置页现有缓存区块显示不变**；“清空缓存”改为**只清在线**；新增“离线缓存”入口（列表 + 单条删除 + 全部清空）。
5. **层 1 封面每行一份**（多分 P 会重复，接受，换取无引用计数）。
6. **离线下载完成后必须确保随行封面入层 1**（否则重启清空层 2 后离线歌无封面）。

## 4. 目标架构与不变量

- **层 1 = 歌曲资产行**（`audio_cache` 扩展）：音频文件 + 随行封面，**行级同生共死**。
- **层 2 = 临时封面缓存**（`cover_cache` 收窄）：仅未缓存歌曲，独立小配额，会话级。
- **单一缓存根**；删除统一走一个 containment guard。
- **`tracks.cover_path` 是唯一对外引用**，可指向层 1 或层 2；悬空由现有 `File.existsSync()` 兜底。
- 降级纪律不变：缓存失败只 log，播放永不被打断。

## 5. 存储布局

单一缓存根 `<app support>/cache/`，**两个 store 各占一个互不重叠的子树**（否则一方的递归 `clear()`/孤儿清理会误删另一方文件）：

```
<app support>/cache/
├── audio/                                  # 层 1 根（AudioCacheStore.baseDir）
│   └── <source>/<sha1(source:trackId)>.<ext>          # 层 1 音频
│   └── <source>/<sha1(source:trackId)>.cover.<ext>    # 层 1 随行封面
└── cover/                                  # 层 2 根（CoverCacheStore.baseDir）
    └── <sha1(字节)>.jpg                              # 层 2 临时封面
```

- **层 1 音频保持现有命名**（`sha1(source:trackId)` 的确定性路径）；内容去重仍在 `insert` 时通过指向既有 canonical 文件实现（`file_path` 可被多行共享），**不把磁盘文件名改成内容哈希**。
- **层 2 封面保持内容寻址**（`sha1(字节)` 文件名），保留 URL→内容去重。
- 旧根 `<app support>/audio_cache/` 与 `<app support>/cover_cache/` 合并进 `<app support>/cache/` 的对应子树。
- **`file_path` 是权威**：新写入一律落在新根；旧行由启动自愈一次性搬迁，搬迁失败时旧路径仍可用（下次重试或被 LRU 自然淘汰）。
- 每个 store 的删除/清理只在自己的子树内进行；层 1 的 containment guard 覆盖音频与随行封面两个子路径，**移除 `AudioCacheStore._deleteCoverFile` 跨目录特例**。

## 6. 数据模型（schema v10）

### 6.1 `audio_cache`（不改名，补注释“歌曲资产行”）
- 新增列：`cover_path TEXT NULL`（层 1 随行封面路径）。
- 保留列与约束：`source`、`source_track_id`、`file_path`、`bytes`、`quality_id`、`pinned`、`cached_at`、`last_accessed_at`、`content_hash`；`UNIQUE(source, source_track_id)`；`idx_audio_cache_lru(pinned, last_accessed_at)`。
- **不加歌词列**；行结构保持可扩展。

### 6.2 `cover_cache`
- schema 不变；**语义收窄为仅层 2**；**不再计入 `limitBytes`**。

### 6.3 新增索引（对应 P3）
| 表 | 新增索引 | 服务的查询 |
|---|---|---|
| `audio_cache` | `content_hash` | `insert` 去重 `_findByContentHash`、`deduplicateByContent` |
| `audio_cache` | `file_path` | 驱逐引用检查、`_deleteFileIfUnreferenced` |
| `cover_cache` | `content_hash` | `_findExistingContentPath` 去重 |
| `cover_cache` | `file_path` | 驱逐引用检查、`_deleteFileIfUnreferenced` |

> `cover_cache.last_accessed_at` 已由 `idx_cover_cache_lru` 覆盖；`audio_cache` 的 LRU 已由 `idx_audio_cache_lru(pinned, last_accessed_at)` 覆盖。不重复建。

## 7. 配额与驱逐

| 配额 | 约束对象 | 可配 |
|---|---|---|
| `limitBytes`（现有） | 层 1 **非 pinned** 行（音频 + 随行封面字节） | 是（现有 UI 不变） |
| 固定 **256 MiB** | 层 2 临时封面 | 否 → 无需新增配额 UI |
| **pinned / 离线** | **不占任何配额** | — |

- **层 1 驱逐按行**：达到上限时按 `last_accessed_at` 最旧优先删除行，同时删除该行音频与其 `cover_path` 封面。**P1 消失**。
- 引用计数仅保留给**音频内容去重**（同一份音频被两个逻辑键引用时，删到最后一个才删物理文件）。
- **层 2 独立驱逐**：单一所有者，按 `last_accessed_at` 最旧优先，256 MiB 上限。
- **两 store 不再跨表读写**：**P4 消失，无需协调器**。
- **启动时清空层 2**：调用层 2 `clear()`（删行 + 删文件），挂在 `main.dart` 现有启动自愈旁，fire-and-forget；层 2 的 `checkIntegrity` 由此被清空取代。

## 8. 生命周期与流转

- **播放 miss** → `DownloadManager` 下载音频入层 1；封面处理见下。
- **封面路由**（`CoverService`）：先查该曲目音频是否已缓存 →
  - 已缓存 → 封面存入**层 1**（`songs/<key>/cover.<ext>`，写回 `audio_cache.cover_path` 与 `tracks.cover_path`）；
  - 未缓存 → 封面存入**层 2**。
- **层 1 ↔ 层 2 搬迁**：若封面已在层 2、随后该歌音频被缓存，则**拷贝**一份进层 1（不搬移，避免抽走层 2 中可能被其它曲目共享的文件）；层 2 副本按 LRU/重启自然消失。
- **离线下载（pinned）完成后**，必须确保随行封面已入层 1（必要时即时抓取）。这是保证离线歌有封面的硬约束。
- **驱逐层 1** → 删音频 + 随行封面；`tracks.cover_path` 悬空由 `File.existsSync()` 兜底，回落层 2 重新缓存。
- **去重规则**：层 1 封面每行一份（多分 P 重复，接受）；层 2 保持内容寻址去重。

## 9. 迁移 v9 → v10

`AppDatabase.schemaVersion` 9 → 10；`onUpgrade` 增 `if (from < 10)` 块，步骤幂等、可重跑。

DB 迁移只做结构与索引；**文件搬迁属文件系统操作，放在启动自愈**（可重试、失败不影响正确性），二者职责分离。

1. `audio_cache` 加 `cover_path`：用 `_addColumnIfMissing(m, audioCache, audioCache.coverPath)`。
2. 建 4 个索引（§6.3），`IF NOT EXISTS`。
3. 重生成 `app_database.g.dart`：`dart run build_runner build --delete-conflicting-outputs`。
4. 迁移测试（v9 fixture → v10）+ 现有缓存测试全绿。

**文件搬迁（启动自愈，非迁移）**：把旧 `audio_cache/`、`cover_cache/` 下被 DB 引用的文件移入新根并改写 `file_path`；失败则保留旧路径（`file_path` 权威），下次启动重试。

## 10. 设置页

- **现有缓存区块显示不变**（用户决定）：上限编辑、位置、用量展示维持现状。
- **“清空缓存”改为只清在线**：层 1 非 pinned + 层 2。离线/pinned 不被误伤。
- **新增“离线缓存”入口**：列出已下载（pinned）曲目及大小，支持**单条删除**与**全部清空**；与曲库行的 `cache_action_button` 状态一致。

## 11. 测试计划

### 单元
- `audio_cache_store`：层 1 行级驱逐（音频 + 随行封面一起删）；pinned 不参与配额与驱逐；`cover_path` 持久化；音频内容去重引用计数保持正确；索引存在（迁移后 `PRAGMA index_list`）。
- `cover_cache_store`：独立 256 MiB 上限；`clear()` 清行 + 清文件；不再计入 `limitBytes`。
- `cover_service`：音频已缓存 → 存层 1；未缓存 → 存层 2；层 2→层 1 拷贝；`tracks.cover_path` 悬空回落。
- `download_manager`：离线（pinned）下载完成后确保随行封面入层 1。

### 迁移
- v9 fixture（含旧根路径行）→ v10：`cover_path` 列存在；4 索引存在；重复运行安全；旧路径文件搬迁后 `file_path` 已改写。

### Widget
- 离线缓存入口：列表渲染、单条删除、全部清空。
- 现有缓存区块显示不变；“清空缓存”不影响 pinned 行。

### 基线
- `flutter analyze` 0 error；`flutter test` 全绿。

## 12. 延期与已知

- **P2**：`StreamInfo` 不透出长度，预检 `_estimateBytes` 仍为 0；超限大文件仍会先整段下载再失败。待 `StreamResolver` API 层改动或启发式阈值。
- **P5**：`freedBytes`/`evictedCount` 展示口径；两 store 并发 `ensureSpace` 的软上限自愈。
- **歌词缓存**：无源，不做；行结构预留扩展点。

## 13. 风险与行为变化

- **pinned 豁免配额** → 上限**不再约束总磁盘占用**，用户可无限下载。有意决策，需在发布说明注明。
- **层 2 每次启动清空** → 未下载歌曲的封面是**会话级**的，每次启动首次浏览曲库/搜索会重新拉图（网络成本）；已下载歌封面在层 1、持久保留。
- **目录合并失败降级** → `file_path` 权威，旧路径行仍可用，不影响正确性。
- **`tracks.cover_path` 悬空** → 依赖现有 `existsSync` 兜底，无需回写清理。
- **层 1 封面重复** → 多分 P 场景会重复存储封面字节，代价小。

## 14. 建议执行顺序

1. **schema v10**：`cover_path` 列、4 索引、迁移、重生成、迁移测试。
2. **store 层重构**：层 1 行级驱逐 + `cover_path`；层 2 独立配额 + 启动清空；删除跨表协调逻辑与 `_deleteCoverFile`。
3. **生命周期**：`CoverService` 路由与层间拷贝；`DownloadManager` 确保离线随行封面；providers 装配；`main.dart` 启动清空层 2。
4. **设置页**：清空语义调整 + 离线缓存入口。
5. **全量回归**：`flutter analyze` + `flutter test`。

> 子智能体派发遵循 [`docs/agent-model-policy.md`](../../agent-model-policy.md)：主智能体负责中高风险/高难度；子智能体按难度+工作量授模型，审阅者不低于实现者，同形小任务批处理，免费端点限量。
