# Flind Player 架构设计

> 版本：v1.0（设计定稿）
> 日期：2026-09-10
> 状态：设计阶段完成，待进入 M0 实现

---

## 1. 项目概述

Flind Player 是一个 Flutter 跨平台音乐播放器。以 **Bilibili 作为主要在线音源**（提取视频流中的音频轨），同时支持本地音乐库，两者在统一曲库中混合呈现。

| 项 | 值 |
|---|---|
| Dart 包名 | `flind_player` |
| Android applicationId | `top.qwind.app.flind_player` |
| iOS/macOS bundle ID | `top.qwind.app.flindPlayer` |
| Linux application ID | `top.qwind.app.flind_player` |
| 许可证 | **GPL-3.0**（见 D13） |
| 主平台 | Android、Linux |
| 辅平台 | Windows、macOS、iOS（可延后构建） |
| Web | **推迟至 v2**（见 D11） |

---

## 2. 需求与约束

| 维度 | 结论 |
|---|---|
| 音乐来源 | 多平台聚合架构，MVP 仅接入 Bilibili |
| 曲库范围 | 在线 + 本地混合 |
| UI 方向 | Material 3 自适应（移动 / 桌面断点切换） |
| 首页入口 | **Bilibili 为主入口**（D12） |
| MVP 功能 | 基础播放、音乐库、系统集成、搜索、播放列表/收藏、离线缓存 |
| 歌词 | 暂不接入，保留抽象待后续（D10） |
| 离线缓存 | 支持，默认 **1 GiB**，可配置（D9） |

---

## 3. 关键决策（ADR）

| # | 决策 | 选择 | 理由 |
|---|---|---|---|
| D1 | 状态管理 | **Riverpod**（`flutter_riverpod` + `Notifier`） | Linthra / Flick / sweyer 三个独立生产项目验证；兼做 DI，避免 get_it + provider 混用 |
| D2 | 播放引擎 | **just_audio + audio_service 为主**，`media_kit` 为可选逃生舱 | Bilibili 音频为 AAC/FLAC/Opus，ExoPlayer 全覆盖；OS 集成最顺；桌面端 just_audio 底层本就是 libmpv |
| D3 | 在线源 | **`MusicSource` 抽象 + 适配器** | 多平台聚合的前提；单个源可替换、可远程禁用 |
| D4 | Bilibili 接入 | 原生直连 + WBI + 安全凭证；Web 走无凭证代理 | 实测第三方 Origin 一律 403（见 `bilibili-source.md`） |
| D5 | 本地扫描 | **`audio_metadata_reader`**（纯 Dart） | 零原生依赖，3392 首 < 200ms，字段齐全 |
| D6 | 缓存 | **drift（SQLite + FTS5）** | 关系查询、迁移、后台 isolate、Flutter Favorite |
| D7 | 系统集成 | **`audio_service`** 统一层 | 一个 AudioHandler 覆盖通知栏 / MPRIS / SMTC / MediaSession |
| D8 | 凭证存储 | **`flutter_secure_storage`** | SESSDATA 是全账号 bearer token |
| D9 | 离线缓存 | Bilibili 音频缓存到本地，**默认 1 GiB 可配置**，LRU 淘汰 | 见 `local-library.md` §4 |
| D10 | 歌词 | **暂不接入**，保留 `LyricsProvider` 抽象 | Bilibili 无歌词源，后续可接 LRC / 第三方 |
| D11 | Web | **推迟至 v2** | CORS 全阻断，需代理且无法登录，性价比低 |
| D12 | 首页 | **Bilibili 主入口** | 在线优先的产品定位 |
| D13 | 许可证 | **GPL-3.0** | 强 copyleft；与全部依赖兼容；解除 libmpv GPL 构建限制（见 §12） |

### D2 补充说明：多引擎依赖方案

两份调研结论存在冲突：音频引擎调研推荐 `media_kit`（唯一在 Android + Linux 都能解 APE/DSD），平台集成调研推荐 `just_audio`（`media_kit` 无任何 OS 媒体控制，需手写桥接）。

**裁决：**

- **主引擎 = `just_audio`**。Bilibili 流为 AAC/FLAC/Opus，ExoPlayer 全覆盖；`audio_service` 集成最成熟；桌面端 `just_audio_media_kit` 底层即 media_kit/libmpv，格式能力不丢。
- **`media_kit` = `PlaybackController` 的第二个实现**，仅当用户播放本地 APE/DSD 等 ExoPlayer 不支持的格式时按需热切换（参考 Flick 的 `AudioEngineManager` 竞态令牌模式）。
- 代价：多一个引擎依赖；收益：OS 集成最顺 + 格式全覆盖。

---

## 4. 分层架构

```
┌──────────────────────────────────────────────────────────┐
│ presentation   features/  (页面 + 组件, 只依赖 core 接口)     │
├──────────────────────────────────────────────────────────┤
│ application    features/*/*_notifier.dart (Riverpod 状态)   │
├──────────────────────────────────────────────────────────┤
│ domain (core)  models / repositories(抽象) / services(抽象)  │
│                sources: MusicSource + StreamInfo            │
├──────────────────────────────────────────────────────────┤
│ data           drift / sources(bilibili, local) / playback   │
│                repositories(实现) / cache                    │
├──────────────────────────────────────────────────────────┤
│ platform       audio_service handler / MPRIS / tray / window │
└──────────────────────────────────────────────────────────┘
```

**铁律：`features/` 只依赖 `core/` 中的接口，绝不 import 具体实现、数据库或播放引擎。**

数据流（在线播放）：

```
UI → SourceProvider → BilibiliAdapter → api.bilibili.com (WBI + 凭证)
                                     → CDN (带 Referer/UA 的音频流)
UI ← PlaybackController ← just_audio ← StreamInfo
```

---

## 5. 目录结构

```
flind_player/
├── lib/
│   ├── main.dart                       # ProviderScope + bootstrap
│   ├── app/
│   │   ├── app.dart                    # MaterialApp.router
│   │   ├── router.dart                 # go_router
│   │   ├── theme/                      # M3 主题 + 自适应断点
│   │   └── di/
│   │       └── application_overrides.dart  # 生产 Provider 装配（单一入口）
│   ├── core/                           # 纯 Dart 领域层
│   │   ├── models/                     # Track/Album/Artist/Playlist/PlaybackQueue/PlaybackState/Lyric
│   │   ├── repositories/               # MusicLibraryRepository / PlaylistRepository (抽象)
│   │   ├── services/                   # PlaybackController / LyricsProvider / ArtworkCache (抽象)
│   │   └── sources/                    # MusicSource + SourceCapabilities + StreamInfo + SourceTrackId
│   ├── data/
│   │   ├── database/                   # drift tables + DAO + migrations
│   │   ├── repositories/               # drift 实现 + *_provider.dart 绑定
│   │   ├── sources/
│   │   │   ├── local/                  # 目录扫描 + audio_metadata_reader
│   │   │   └── bilibili/               # client / wbi / auth / riskcontrol / mapper / ratelimiter
│   │   ├── playback/                   # JustAudioPlaybackController / MediaKitPlaybackController
│   │   └── cache/                      # 封面缓存 + 音频离线缓存（DownloadManager）
│   ├── platform/
│   │   ├── audio_handler.dart          # audio_service AudioHandler（桥接 PlaybackController）
│   │   ├── media_session/              # 各平台媒体会话绑定
│   │   ├── tray/                       # 桌面托盘
│   │   └── window/                     # window_manager
│   ├── features/                       # 一屏一目录
│   │   ├── home/                       # Bilibili 主入口
│   │   ├── library/
│   │   ├── player/
│   │   ├── queue/
│   │   ├── playlists/
│   │   ├── search/
│   │   ├── lyrics/                     # 占位（D10）
│   │   ├── account/                    # Bilibili 登录
│   │   └── settings/
│   └── shared/                         # 通用组件、布局断点、扩展
├── android/  linux/  windows/  web/  macos/  ios/
└── docs/
    ├── architecture.md                 # 本文档
    ├── bilibili-source.md              # Bilibili 适配器设计
    └── local-library.md                # 本地库 + 离线缓存设计
```

---

## 6. 核心抽象

### 6.1 音源

```dart
// core/sources/music_source.dart
abstract interface class MusicSource {
  String get id;                        // 'bilibili' | 'local'
  SourceCapabilities get capabilities;  // canLogin / canSearch / canStreamDirect ...

  Future<SearchPage> search(String query, {int page});
  Future<Track> fetchTrack(SourceTrackId id);
  Future<StreamInfo> resolveStream(Track track);
  Future<List<Playlist>> playlists();
}

class StreamInfo {
  final Uri url;
  final List<Uri> backupUrls;           // Bilibili 必须保留 failover
  final Map<String, String> headers;    // Referer / User-Agent
  final DateTime? expiresAt;            // Bilibili ≈ 120 分钟
  final String qualityId;
}

// 身份：绝不只用 bvid（多分P 会冲突）
sealed class SourceTrackId {}

class BiliTrackId extends SourceTrackId {
  final String bvid;
  final int cid;
}

class LocalTrackId extends SourceTrackId {
  final String path;
}
```

### 6.2 播放控制

```dart
// core/services/playback_controller.dart
abstract interface class PlaybackController {
  Stream<PlaybackState> get state;
  PlaybackQueue get queue;

  Future<void> playQueue(PlaybackQueue queue, {int index = 0});
  Future<void> play();
  Future<void> pause();
  Future<void> next();
  Future<void> previous();
  Future<void> seek(Duration position);
  Future<void> setRepeatMode(RepeatMode mode);
  Future<void> setShuffle(bool enabled);
}
```

### 6.3 队列（不可变值类型）

```dart
// core/models/playback_queue.dart
@immutable
class PlaybackQueue {
  final List<Track> tracks;
  final int currentIndex;
  final List<int> originalOrder;   // 洗牌前顺序，用于取消随机

  const PlaybackQueue({
    required this.tracks,
    required this.currentIndex,
    required this.originalOrder,
  });

  PlaybackQueue copyWith({...});

  // 洗牌 = 纯变换，可脱离引擎单元测试
  PlaybackQueue shuffled();
  PlaybackQueue unshuffled();
}
```

**约束**：任何 widget 不得 `import 'just_audio'` 或 `'media_kit'`，只能经 `PlaybackController`。

---

## 7. 数据模型与缓存

### 7.1 统一曲库

主键使用 **provider 命名空间的 uri**，避免跨源 id 冲突：

| 源 | uri 示例 |
|---|---|
| Bilibili | `bilibili:BV1GJ411x7h7:137649199`（bvid + cid） |
| 本地 | `local:/home/user/Music/song.flac` |

字段（详见 `local-library.md` §5）：`title / artist / album / album_artist / track_no / disc_no / year / duration_ms / bitrate / sample_rate / genre / cover_hash / last_seen_at`。

- **FTS5 虚拟表**覆盖 title / artist / album，供搜索。
- **封面**：内容哈希 → `covers/<sha1>.webp`（应用私有目录，256–512px）。
- **在线元数据**激进缓存；**流地址**视为易失（120 分钟过期，403 时刷新）。

### 7.2 离线音频缓存

- 位置：`<app support>/audio_cache/<source>/<hash>.<ext>`
- 默认上限 **1 GiB**，可在设置中调整（D9）
- 淘汰：按 `last_accessed_at` LRU；**手动下载（pinned）条目不参与淘汰**
- 播放时 `resolveStream` 优先命中缓存 → 返回 `file://`，无需 headers
- 详见 `local-library.md` §4

---

## 8. 播放管线

```
Track → PlaybackController.playQueue(queue)
  → resolveStream(track)              # 源适配器产出 StreamInfo
  → 命中离线缓存? → file:// 直放
    否则 → just_audio setAudioSources(headers: {...})
  → AudioHandler 上报 playbackState / mediaItem / queue
  → Android 通知栏 / Linux MPRIS / macOS Now Playing
  → 流过期 (403) → 重新 resolveStream → seek 回原位置（自愈）
```

关键点：

1. `resolveStream` 的 headers 必须注入播放器（Bilibili CDN 防盗链必需）。
2. 流地址带 `expiresAt`，播放中失效要能自愈，不能中断用户。
3. 队列变更 → 重新计算 `mediaItem` 与队列窗口（Android Binder 有大小限制，只发布窗口）。

---

## 9. 系统集成矩阵

| 平台 | 机制 | 实现 |
|---|---|---|
| Android | MediaSession + 通知栏 + 锁屏 | `audio_service`（FGS `mediaPlayback` + `POST_NOTIFICATIONS`） |
| Linux | MPRIS2 / 媒体键 | `audio_service_mpris` ^0.2.1 |
| Windows | SMTC | `audio_service_win`（备选 `smtc_windows` ^1.1.0） |
| macOS | MPNowPlayingInfoCenter | `audio_service` darwin 内置 |
| iOS | MPNowPlayingInfoCenter | `audio_service` 内置 |
| Web | Media Session API | 推迟（D11） |
| 桌面托盘 | tray | `tray_manager` ^0.5.2 |

桌面附加：`window_manager`（关闭到托盘）、Linux 需 `libmpv-dev` + `libayatana-appindicator3-dev`。

---

## 10. 里程碑

| 阶段 | 内容 | 验收标准 |
|---|---|---|
| **M0 骨架** | 目录结构 + Riverpod 装配 + drift + 本地文件播放 | Linux/Android 能播放本地 MP3 |
| **M1 Bilibili 播放** | WBI + view + playurl + 直连播放 + 限流 | 搜索并播放一个 BV，带 Referer 正常出声 |
| **M2 曲库** | 本地扫描 + 在线元数据入库 + 统一列表/搜索 | 混合列表可查询，FTS 生效 |
| **M3 离线缓存** | 下载队列 + LRU 淘汰 + 1 GiB 默认上限 | 断网可播已缓存曲目；超限自动淘汰 |
| **M4 系统集成** | audio_service + 通知栏 + MPRIS + 托盘 | 后台/桌面媒体键可控 |
| **M5 播放列表/收藏** | 队列持久化、收藏、Bilibili 收藏夹 | 重启后恢复队列与收藏 |
| **M6 打磨** | M3 自适应、设置、错误处理、登录 | 桌面/移动自适应无布局问题 |
| **v2 Web** | JSON 代理 + 匿名能力 | 见 `bilibili-source.md` §9 |

> 歌词（D10）不在 MVP 里程碑内，保留抽象待后续插入。

---

## 11. 风险与对策

| 风险 | 等级 | 对策 |
|---|---|---|
| Bilibili 法律/ToS（社区 API 文档已被律师函关停） | 高 | 个人使用姿态、不内置凭证、`MusicSource` 隔离可远程禁用、不做带凭证的公共代理 |
| API 不稳定（WBI 每日轮换、风控升级） | 高 | 集中签名客户端、限流退避、能力开关、feature flag |
| Web CORS 全阻断 | 确定 | Web 推迟至 v2（D11） |
| Android 17 音频加固 | 中 | 首次播放前台启 FGS、`androidStopForegroundOnPause: false`、17 beta 实测 |
| 双引擎复杂度 | 中 | 接口隔离，media_kit 仅按需用于 APE/DSD |
| 离线缓存占满磁盘 | 低 | 默认 1 GiB 上限 + LRU + 设置可调 |

---

## 12. 许可证与依赖兼容性

本项目采用 **GNU General Public License v3.0**，全文见根目录 [`LICENSE`](../LICENSE)。

### 12.1 依赖许可证总览

| 包 | 用途 | 许可证 | 与 GPL-3.0 兼容 |
|---|---|---|---|
| `just_audio` | 主播放引擎 | Apache-2.0 / MIT | 是 |
| `audio_service` | 系统集成 | MIT | 是 |
| `audio_session` | 音频焦点 | MIT | 是 |
| `media_kit`（+ libs） | 逃生舱引擎 | MIT；libmpv/FFmpeg 为 LGPL-2.1+ | 是 |
| `audio_service_mpris` | Linux MPRIS | MIT | 是 |
| `audio_service_win` | Windows SMTC | MIT | 是 |
| `tray_manager` | 桌面托盘 | MIT | 是 |
| `window_manager` | 桌面窗口 | MIT | 是 |
| `drift` / `drift_flutter` | SQLite + FTS5 | MIT | 是 |
| `audio_metadata_reader` | 元数据解析 | MIT | 是 |
| `permission_handler` | 权限申请 | MIT | 是 |
| `file_picker` | 目录选择 | MIT | 是 |
| `on_audio_query_pluse` | Android MediaStore | Apache-2.0 | 是 |
| `flutter_secure_storage` | 凭证存储 | BSD-3-Clause | 是 |
| `go_router` | 路由 | BSD-3-Clause | 是 |
| `dio` | HTTP 客户端 | MIT | 是 |

### 12.2 GPL-3.0 带来的两点变化

1. **libmpv 构建限制解除**：在闭源假设下，原需避免 GPL 风味的 libmpv 构建、只能动态链接 LGPL 版本。项目改为 GPL-3.0 后，GPL 风味构建同样兼容，选型不再受此约束。
2. **GPL 参考项目可直接复用**：`PiliPlus`、`PiliPala` 等 GPL-3.0 项目的实现（如 WBI 签名），从"仅行为参考、勿复制"变为**许可兼容、可直接复用**（见 [`bilibili-source.md`](bilibili-source.md) §3、§8）。

### 12.3 源码文件头约定

每个 Dart 源文件顶部使用如下声明：

```dart
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
```

### 12.4 分发义务

若分发本应用的二进制版本，必须同时提供完整对应源码（GPL-3.0 §6）。个人使用不受此约束。

## 13. 相关文档

- [`bilibili-source.md`](bilibili-source.md) —— Bilibili 适配器：端点、WBI、鉴权、风控、限流、法务
- [`local-library.md`](local-library.md) —— 本地库：扫描、元数据、drift schema、离线缓存
