# 设计：曲库界面（LibraryScreen）UI TODO

- 日期：2026-09-27
- 状态：待实现
- 范围：曲库顶栏与菜单结构、单曲菜单操作、按页面持久化的多视图系统、瀑布流布局、本地化与测试
- 目标读者：实现者
- 关联：[`lib/features/library/library_screen.dart`](../../../lib/features/library/library_screen.dart)、[`docs/widget-tree.md`](../../widget-tree.md)、[`docs/local-library.md`](../../local-library.md)（离线缓存）

## 1. 背景与目标

`LibraryScreen` 当前存在以下问题与需求（用户给出的 UI TODO）：

1. 单曲「更多」菜单的离线缓存有「缓存到本地 / 已缓存（未固定）/ 已缓存」三态，语义冗余，且点击「已缓存（未固定）」后菜单重新打开仍显示旧状态（pin 状态变更未被观察）。
2. 左上角「更多」菜单是扁平结构，需要精简化：把本地库操作归入「本地」二级菜单，把排序归入「排序」二级菜单。
3. 右上角「搜索」小按钮与「新建歌单」按钮需要按页面收窄：搜索只保留「全部」页并常显搜索框；新建歌单只保留给「歌单」页。
4. 单曲菜单需要补充「移出歌单」与「删除歌曲」（后者为危险操作，需二次确认）。
5. 新增按页面独立的「视图」功能：展柜 / 列表 / 瀑布流。
6. 新增瀑布流视图：卡片封面按真实宽高比排布，类似小红书主页。

### 目标
- 离线缓存行内显示统一为**两态**。
- 「更多」菜单改为「本地」「排序」「视图」三个二级菜单。
- 搜索常显于「全部」页并移除切换按钮；「+」仅在「歌单」页。
- 「移出歌单」「删除歌曲」按页面提供，删除带二次确认并编排跨仓库清理。
- 视图按页面独立持久化并渲染。
- 瀑布流按封面真实宽高比布局。

### 非目标
- 不改动搜索页（`search_screen.dart`）与 B 站收藏夹页（`bilibili_favorites_screen.dart`）的单曲菜单。
- 「删除歌曲」**不删除本地磁盘原始文件**，仅删曲库行 / 歌单引用 / 离线缓存。
- 不实现歌词、不实现跨窗口设置同步。
- 歌单列表页不提供瀑布流视图（歌单没有「歌曲封面宽高比」语义）。
- 不改离线缓存的存储/配额实现（删除单条缓存复用现有 `AudioCacheStore`）。

## 2. 已确认的语义决策

1. 离线缓存两态：未缓存 = **「离线缓存」**（可点击下载并 pin）；已缓存（无论是否 pin）= **「已缓存」**（`enabled: false`，纯状态展示，不可点击）。删除缓存仍走「设置 → 离线缓存」。
2. 搜索框**仅在「全部」页常显**；「收藏」「歌单」页不再显示、不再支持搜索。删除右上角搜索切换按钮。
3. 二级菜单用 **Material 3 原生 `SubmenuButton`**（`MenuAnchor`）。
4. 「删除歌曲」作用范围：**「全部」页**仅「删除歌曲」；**「歌单详情」页**「移出歌单」+「删除歌曲」；**「收藏」页**仅「删除歌曲」+ 现有「取消收藏」开关（**跳过重复的「移出歌单」**）。
5. 「删除歌曲」= 从**所有歌单**移除 + 删除曲库行 + 删除离线缓存（如有）；对本地歌曲**不动原始文件**。
6. 视图作用范围与默认：**「全部」页**三视图、默认**瀑布流**；**「收藏」页**三视图、默认**展柜**；**「歌单」列表页**仅展柜/列表、默认**展柜**；**「歌单详情」页**三视图、默认**列表**。搜索查询在离开「全部」页后**保留**，返回时仍显示。

## 3. 目标架构

- **数据模型**：新增 `LibraryView`（showcase/list/waterfall）与 `LibraryViewScope`（all/favorites/playlists/playlistDetail）枚举；新增不可变聚合 `LibraryViews`。
- **持久化**：`SettingsRepository` 新增 `libraryViews()` / `setLibraryView(scope, view)`，`shared_preferences` 键 `library.view.<scope>`；缺失/非法时回落默认值，`playlists` 作用域把 `waterfall` 强制回落为 `showcase`。
- **状态**：单例 `LibraryViewsNotifier extends AsyncNotifier<LibraryViews>`，暴露 `libraryViewsProvider`，提供 `setView(scope, view)`。
- **操作编排**：新增 `TrackDeletionService`（组合 `AudioCacheStore`、`PlaylistRepository`、`MusicLibraryRepository`），提供 `deleteEverywhere(Track)`。
- **渲染**：三种视图渲染器（展柜网格 / 列表 / 瀑布流 masonry）按 `LibraryView` 选择；宽度只决定列数，不再决定视图。
- **菜单**：`MenuAnchor` + `SubmenuButton`，叶子项通过 `MenuController.close()` 关闭菜单。

### 不变量
- 视图选择纯本地持久化，不触发任何网络/数据库写入。
- 删除歌曲失败不破坏界面：捕获异常 → SnackBar；已完成的步骤不回滚（幂等，可重试）。
- 未缓存/不可用行保持可见与降级语义（`unavailable`）。

## 4. 逐项设计

### 4.1 离线缓存两态（TODO 1）

文件：`lib/features/library/widgets/track_actions_button.dart`

- 删除 `_cacheLabel` 的三态分支：`entry == null` → `l10n.cacheOffline`（「离线缓存」，可点击）；`entry != null` → `l10n.cached`（「已缓存」，`PopupMenuItem(enabled: false)` 或 `MenuItemButton(onPressed: null)`）。
- 图标：未缓存 `Icons.download_outlined`；已缓存 `Icons.download_done`。
- 移除 `_cacheIcon` 中对 `entry.pinned` 的分支（保留「已缓存」统一图标）。
- `_cacheTrack` 保持 `cacheTrack(track, pinned: true)`。
- 本地歌曲仍不显示缓存项。
- l10n：新增 `cacheOffline`（zh「离线缓存」/ en「Download」）；移除不再使用的 `cachedUnpinned`。
- 独立 `CacheActionButton`（`cache_action_button.dart`）当前未在 UI 中使用（仅导出 `audioCacheEntryProvider`）。本设计**不改其行为**，仅更新其过时的注释（注释声称 pin 不生效，实际 `DownloadManager` 已处理 pin）。

### 4.2 「更多」菜单：本地 / 排序 / 视图（TODO 2、5）

文件：`lib/features/library/library_screen.dart`

- 用 `MenuAnchor`（保留 key `library_more_menu`）替换 `PopupMenuButton<_LibraryAction>`；用私有 `MenuController` 控制。叶子项点击后 `_menuController.close()` 再执行动作。
- 菜单结构：
  - `SubmenuButton` **本地**（仅 `hasLocalLibrary`）：添加文件夹 / 重新扫描（同步中禁用） / 导入文件。
  - `SubmenuButton` **排序**：按标题 / 按艺术家 / 按专辑 / 最近添加，当前项前打勾。
  - `SubmenuButton` **视图**：依当前 `_section` 决定选项（§4.5）。
  - `MenuItemButton` 浏览 B 站收藏夹（顶层，不变）。
- 移除 `_LibraryAction` 枚举中的 `sortBy*` 分支与 `_SortRow`（打勾行可复用于子菜单）。同步状态 `isSyncing` 继续来自 `librarySyncStateProvider`。
- **排序默认改为最近添加**：
  - `PrefsSettingsRepository.librarySort()` 缺失/非法回落 `TrackSort.recentlyAdded`。
  - `libraryTracksProvider`、`_buildHeaderRow`、`_buildFavouritesBody` 的 `?? TrackSort.title` 改为 `?? TrackSort.recentlyAdded`。
  - 更新 `lib/core/models/track_sort.dart` 与 `SettingsRepository.librarySort` 文档注释（“title 是默认” → “recentlyAdded 是默认”）。
- l10n：新增 `menuLocal`、`menuSort`、`menuView`。

### 4.3 顶栏按钮（TODO 3）

文件：`lib/features/library/library_screen.dart`

- 删除 `_searchOpen`、`_toggleSearch` 及搜索切换 `IconButton`（key `library_search_button`）。
- `_buildSearchField()` 仅当 `hasLocalLibrary && _section == LibrarySection.all` 时渲染；始终展开（去掉 `AnimatedSize` 的开关语义或保留尺寸动画但恒为展开）；提示语固定 `l10n.searchLibrary`；保留清除按钮。
- 「+ 新建歌单」（key `library_add_playlist`）仅当 `_section == LibrarySection.playlists` 时渲染，仍在右上。
- 顶栏 `Stack` 的宽度预留更新：右侧仅在有「+」时预留 48。
- 搜索/过滤只作用于「全部」页：
  - `_buildSectionBody`：`playlists` 分支不再传 `query`；`favorites` 分支不再按 `_query` 过滤；`all` 分支保持 `librarySearchProvider(_query)` + `libraryTracksProvider`。
  - `PlaylistsSection` 删除 `query` 参数与过滤逻辑。
  - 删除 `_NoFavouritesSearchResults`（不再可达）。
- 查询在离开「全部」后保留（状态不变，字段随页面隐藏）。

### 4.4 单曲菜单操作：移出歌单 / 删除歌曲（TODO 4）

文件：`lib/features/library/widgets/track_actions_button.dart`、`lib/features/library/widgets/track_list_items.dart`、`lib/features/library/library_screen.dart`、`lib/features/library/playlist_detail_screen.dart`、`lib/data/services/track_deletion_service.dart`（新）、`lib/core/repositories/playlist_repository.dart`、`lib/data/repositories/drift_playlist_repository.dart`、`lib/data/providers/*`

- `TrackActionsButton` 新增 `bool showDeleteTrack = false`；保留 `playlistId`（`playlistId != null` → 显示「移出歌单」）。
  - 「移出歌单」动作：`playlistRepositoryProvider.removeTrack(playlistId, track.uri)`（现有逻辑）。
  - 「删除歌曲」动作：弹二次确认 → `trackDeletionServiceProvider.deleteEverywhere(track)` → SnackBar。
- 页面接线：
  - **全部**：`TrackTile/TrackCard(..., showDeleteTrack: true)`，不传 `playlistId`。
  - **收藏**：`showDeleteTrack: true`，不传 `playlistId`（「取消收藏」开关即移除入口）。
  - **歌单详情**：`showDeleteTrack: true` + `playlistId: playlistId`（已存在）。
  - 搜索页 / B 站收藏夹页不传新参数（默认 false，行为不变）。
- `TrackTile`、`TrackCard` 增加 `showDeleteTrack` 透传。
- `PlaylistRepository` 新增 `Future<void> removeTrackFromAllPlaylists(String uri)`；`DriftPlaylistRepository` 实现 `DELETE FROM playlist_tracks WHERE uri = ?`。
- `TrackDeletionService.deleteEverywhere(Track track)`：
  1. `audioCacheStore.lookup(track.source, cacheSourceTrackId(track))`，命中则 `remove(entry.id)`（不动无关文件）。
  2. `playlistRepository.removeTrackFromAllPlaylists(track.uri)`。
  3. `track.id != null` 时 `musicLibraryRepository.deleteTrack(track.id)`。
  4. 失效：`libraryTracksProvider`、`favoritesProvider`、`playlistsProvider`、`playlistTracksProvider`（按需）、`audioCacheEntryProvider(track)`、`audioCacheUsageProvider`。
  5. 返回删除结果（供 SnackBar）。
- 二次确认弹窗：危险样式（`colorScheme.error`），标题 `deleteTrackTitle`、正文 `deleteTrackBody(track.title)`（说明：从所有歌单移除 + 删除曲库 + 删除离线缓存 + 不可撤销），动作「取消 / 删除」。
- l10n：`deleteTrack`、`deleteTrackTitle(String)`、`deleteTrackBody(String)`、`trackDeleted(String)`；`removeFromPlaylist` 的 zh 值改为「移出歌单」。

### 4.5 视图系统（TODO 5）

新增文件：`lib/core/models/library_view.dart`、`lib/features/library/library_view_provider.dart`、`lib/features/library/widgets/library_view_menu_button.dart`、`lib/features/library/widgets/waterfall_track_card.dart`

修改：`settings_repository.dart`、`prefs_settings_repository.dart`、`library_screen.dart`、`playlists_section.dart`、`playlist_detail_screen.dart`

- `enum LibraryView { showcase, list, waterfall }`，附 `label(l10n)`。
- `enum LibraryViewScope { all, favorites, playlists, playlistDetail }`，附：
  - `LibraryView get defaultView`：all→waterfall；favorites→showcase；playlists→showcase；playlistDetail→list。
  - `Set<LibraryView> get allowedViews`：playlists→{showcase,list}；其余三种。
  - `LibraryView sanitize(LibraryView v)`：不在允许集合时回落 `defaultView`。
- `LibraryViews` 不可变类：持有 `Map<LibraryViewScope, LibraryView>`；`viewOf(scope)` 缺失回落默认；`static LibraryViews get defaults`。
- `SettingsRepository`：`Future<LibraryViews> libraryViews()`、`Future<void> setLibraryView(LibraryViewScope scope, LibraryView view)`。
  - `PrefsSettingsRepository`：键 `library.view.all` / `.favorites` / `.playlists` / `.playlistDetail`，值为枚举 `name`；读取非法值回落默认；`playlists` 写入前 `sanitize`。
- `LibraryViewsNotifier extends AsyncNotifier<LibraryViews>`：
  - `build()` 读取全部；
  - `setView(scope, view)` 先 `sanitize`，持久化后 `state = AsyncData(...)`。
- UI 读取：`final views = ref.watch(libraryViewsProvider).value ?? LibraryViews.defaults;`
- 渲染器：
  - 曲目（全部/收藏/歌单详情）：
    - `showcase` → 卡片网格（现有 `_trackGrid` 的 `TrackCard`，列数按宽度）。
    - `list` → `TrackTile` 列表（现有 `_trackList`）。
    - `waterfall` → `MasonryGridView.count` + `WaterfallTrackCard`（§4.6）。
    - 取代原 `AppBreakpoints.isCompact` 的「窄屏自动列表 / 宽屏自动网格」；列数用宽度推导（如 `(width / 180).round().clamp(2, 6)`）。
  - 歌单列表页：
    - `showcase` → 网格：首个为「收藏」卡片，其后为歌单卡片（新建 `PlaylistCard`，展示封面 + 名称 + 曲目数）。
    - `list` → 现有 `_FavoritesRow` + `_PlaylistRow`。
  - 歌单详情：AppBar 新增 `LibraryViewMenuButton`（key `playlist_view_menu`），三种视图渲染成员曲目。
- `LibraryViewMenuButton`：可复用的 `MenuAnchor` 按钮，输入 `scope`；选项来自 `allowedViews`，当前项打勾。
- l10n：`viewShowcase`、`viewList`、`viewWaterfall`。

### 4.6 瀑布流卡片（TODO 6）

新增文件：`lib/features/library/widgets/waterfall_track_card.dart`、`lib/features/library/cover_aspect_ratio_provider.dart`

- `WaterfallTrackCard`：沿用 `TrackCard` 的视觉（`Card` + `InkWell` + 更多按钮叠加 + 播放徽标 + 标题/艺术家/来源标签），但封面按列宽填满、高度 = 列宽 / 宽高比。
- `coverAspectRatioProvider`（`FutureProvider.family<double, CoverAspectKey>`，key 为 `coverPath` 优先、否则 `coverUrl`）：
  - 用 `FileImage` / `NetworkImage` 的 `resolve` + `ImageStreamListener` 读取 `ImageInfo.width`/`height`（复用 Flutter 图片缓存，避免与卡片自身加载重复下载）。
  - 未知 / 无封面 → 默认 `1.0`；provider 缓存结果。
- 布局：`MasonryGridView.count(crossAxisCount, mainAxisSpacing, crossAxisSpacing)`（`flutter_staggered_grid_view`），列数同 §4.5。
- 未加载完成时使用默认比例占位，加载后自然重排（Masonry 支持）。

### 4.7 顶栏/菜单保留项
- 顶栏中部的 `_LibraryFilterSelector` 不变。
- `library_search_button`、`library_add_playlist`、`library_more_menu` 的 key 语义更新；`library_search_button` 被删除。

## 5. 数据与持久化变更

- 新增 prefs 键：`library.view.all`、`library.view.favorites`、`library.view.playlists`、`library.view.playlistDetail`。
- 默认排序由 `title` 改为 `recentlyAdded`（仅影响未设置过的用户；已存储值保持不变）。
- 无数据库 schema 变更。

## 6. 本地化（l10n）

模板：`lib/l10n/app_en.arb`；目标：`lib/l10n/app_zh.arb`；生成物：`lib/l10n/app_localizations*.dart`（`flutter gen-l10n`）。

新增键：
- `menuLocal`（本地 / Local）
- `menuSort`（排序 / Sort）
- `menuView`（视图 / View）
- `viewShowcase`（展柜视图 / Showcase view）
- `viewList`（列表视图 / List view）
- `viewWaterfall`（瀑布流视图 / Waterfall view）
- `cacheOffline`（离线缓存 / Download）
- `deleteTrack`（删除歌曲 / Delete song）
- `deleteTrackTitle`（删除歌曲？ / Delete song?）
- `deleteTrackBody(String title)`（将从所有歌单移除，并从曲库删除《{title}》及其离线缓存（如有）。此操作不可撤销。/ This removes "{title}" from every playlist, deletes it from the library, and removes its offline cache (if any). This cannot be undone.）
- `trackDeleted(String title)`（已删除《{title}》/ Deleted "{title}"）

修改键：
- `removeFromPlaylist` zh：`从歌单移除` → `移出歌单`。

移除键：
- `cachedUnpinned`（三态中冗余的一项）。

保留但可能不再使用的键（暂不删除，避免无关改动）：`cacheToLocal`、`searchFavorites`、`searchPlaylists`。

## 7. 依赖变更

- 新增 `flutter_staggered_grid_view`（最新稳定版）到 `pubspec.yaml` dependencies，并 `flutter pub get`。
- 备用方案：若离线无法获取该包，改为自研「按已解析宽高比均衡分列的 `CustomScrollView`」；接口保持 `WaterfallTrackCard` 不变，仅替换容器实现。

## 8. 测试策略

更新既有：
- `test/library_screen_test.dart`：去掉 `_openSearch`（搜索框在「全部」页默认存在）；顶栏断言改为「无搜索图标、`+` 仅在歌单页、`library_more_menu` 存在」；菜单断言改为二级菜单；收藏页搜索相关用例删除或改写。
- `test/playlist_ui_test.dart`、`test/favorites_ui_test.dart`：同步顶栏与菜单变化。
- 涉及排序默认值的用例：显式覆盖 `librarySortProvider`（避免依赖默认）。

新增：
- `library_view` 模型测试：默认值、`sanitize`、allowedViews。
- `prefs_settings_repository` 测试：视图读写、非法值回落、`playlists` 拒绝 `waterfall`。
- `library_screen` 视图测试：切换视图后渲染对应布局（`TrackCard` 网格 / `TrackTile` / `MasonryGridView`），且按页面独立。
- 单曲菜单：未缓存显示「离线缓存」可点、已缓存显示「已缓存」不可点。
- 删除流程：`removeTrackFromAllPlaylists`（drift 测试）、`TrackDeletionService`（缓存 + 歌单 + 曲库清除，含 `track.id == null`）、“删除歌曲”二次确认。
- `MenuAnchor` 子菜单：展开「本地/排序/视图」可见叶子项。

## 9. 文档更新

- `docs/widget-tree.md`：更新 `LibraryScreen` 结构（新菜单、视图、搜索范围）。
- 在相关文档注明视图默认值与「删除歌曲」语义。
- 本规格与随后的实施计划。

## 10. 风险与取舍

- **`MenuAnchor`/`SubmenuButton` 在窄屏的可用性**：级联子菜单在手机上可能超出屏幕；Material 会将其约束在可用区域内，需在 400 px 用 widget 测试确认无溢出。
- **瀑布流首屏抖动**：宽高比未知时先用 1:1 占位，图片解析后重排；可接受（小红书式体验）。
- **危险操作**：`deleteEverywhere` 部分完成即中断不回滚；通过幂等与 SnackBar 提示降低风险。删除前二次确认。
- **排序默认变更**：对未设置过的既有用户，曲库顺序会从「按标题」变为「最近添加」；这是明确需求。
- **新依赖**：`flutter_staggered_grid_view`；已提供自研备用实现。
- **收藏页移除入口**：不加重复的「移出歌单」；由「取消收藏」承担，避免同一动作出现两项。
