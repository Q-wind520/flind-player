# Flind Player — Widget 树总览 (LiteTree)

> 由静态源码整理而来的轻量级 widget 树(litetree)。每个节点以
> 「中文名称 (`ClassName`)」标注;`{条件}` 花括号内为运行时分支,
> 并非同时存在。

## 入口

```
main (入口)
└─ runApp
   └─ UncontrolledProviderScope (Provider 容器作用域 — 手动创建的容器,
      │                         与音频后台服务共享 playbackController)
      └─ FlindApp (应用根组件 ConsumerWidget)
         └─ MaterialApp (应用外壳)
            ├─ locale / localizationsDelegates / supportedLocales (国际化)
            ├─ theme / darkTheme / themeMode (主题: 亮色/暗色/跟随系统)
            └─ home: HomeShell (主界面壳)
```

## 主壳 HomeShell(自适应布局)

HomeShell 用 `LayoutBuilder` 按窗口尺寸一分为二:
宽度 < 600 或竖屏 → **紧凑模式**(底部导航);否则 → **宽屏模式**(侧边导航)。

```
HomeShell (主界面壳 StatefulWidget)
└─ LayoutBuilder (响应式布局决策)
   ├─ {宽屏模式}
   │  └─ Scaffold (页面骨架)
   │     └─ SafeArea (安全区)
   │        └─ Row (水平布局)
   │           ├─ NavigationRail (侧边导航栏)
   │           │  └─ 3 × NavigationRailDestination (搜索/曲库/设置)
   │           └─ Expanded (内容区)
   │              └─ Column (垂直布局)
   │                 ├─ Expanded
   │                 │  └─ IndexedStack (页面堆栈 — 保持各页状态)
   │                 │     ├─ SearchScreen (搜索页, 见下)
   │                 │     ├─ LibraryScreen (曲库页, 见下)
   │                 │     └─ SettingsScreen (设置页, 见下)
   │                 └─ MiniPlayerBar (迷你播放条, 见下)
   │
   └─ {紧凑模式}
      └─ Scaffold (页面骨架)
         ├─ body: IndexedStack (页面堆栈 — 同上三个页面)
         └─ bottomNavigationBar: Column (垂直布局)
            ├─ MiniPlayerBar (迷你播放条, 见下)
            └─ NavigationBar (底部导航栏)
               └─ 3 × NavigationDestination (搜索/曲库/设置)
```

## 搜索页 SearchScreen(哔哩哔哩搜索)

```
SearchScreen (搜索页 ConsumerStatefulWidget)
└─ PlaybackPermissionScope (播放权限作用域 — 授予后才允许播放)
   └─ Scaffold (页面骨架)
      ├─ AppBar (标题栏)
      │  ├─ title: Text (标题「搜索」)
      │  └─ bottom: PreferredSize
      │     └─ TextField (搜索输入框 — 提交时才发起搜索)
      └─ body
         ├─ {未提交关键词} _SearchHint (搜索引导空态)
         │  └─ ResponsiveCenter → Icon + 标题 + 提示文案
         └─ {已提交} AsyncValue.when (异步结果分发)
            ├─ loading → Center ( CircularProgressIndicator 加载圈 )
            ├─ error   → _SearchError (搜索失败面板, 带重试按钮)
            └─ data
               ├─ {空结果} _NoResults (无结果空态)
               └─ ListView.builder (结果列表)
                  └─ _SearchResultTile (搜索结果行)
                     └─ ListTile
                        ├─ leading: Container (占位封面 48×48)
                        ├─ title: Text (标题)
                        ├─ subtitle: Text (UP 主)
                        └─ trailing: Row
                           ├─ {正在播放} Icon (graphic_eq 均衡器动画图标)
                           ├─ Text (时长)
                           └─ TrackActionsButton (轨道操作菜单, 见下)
```

## 曲库页 LibraryScreen(本地 + 收藏曲库)

```
LibraryScreen (曲库页 ConsumerStatefulWidget)
└─ Scaffold (页面骨架)
   ├─ AppBar (标题栏)
   │  ├─ title: Text (「音乐曲库」)
   │  ├─ actions
   │  │  ├─ {支持本地曲库} _SortButton (排序弹窗按钮)
   │  │  │  └─ PopupMenuButton<TrackSort> (标题/艺术家/专辑/最近添加)
   │  │  └─ PopupMenuButton<_LibraryAction> (更多操作菜单)
   │  │     ├─ {支持本地曲库} 添加文件夹 / 重新扫描 / 导入文件
   │  │     └─ 浏览 B 站收藏夹 → 推入 BilibiliFavoritesScreen
   │  └─ bottom: {支持本地曲库} PreferredSize
   │     └─ TextField (库内搜索框 — 250ms 防抖)
   ├─ body
   │  ├─ {支持本地曲库}
   │  │  └─ Column
   │  │     ├─ _SyncStatus (同步状态条, 见下)
   │  │     ├─ _FilterBar (筛选条)
   │  │     │  └─ SegmentedButton<LibraryFilter> (全部 / 收藏)
   │  │     └─ Expanded (列表主体, 见下)
   │  └─ {iOS 等无本地曲库} _UnsupportedLibraryNotice (不支持提示)
   └─ {无轨道时的浮层入口}
      └─ SnackBar (提示条) / 对话框等

列表主体 (按 筛选/搜索/数据状态 分支):
├─ 收藏模式 → favoritesProvider.when
│  ├─ loading → CircularProgressIndicator (加载圈)
│  ├─ error   → _LibraryError (加载失败, 可重试)
│  └─ data
│     ├─ {空收藏} _EmptyFavourites (收藏为空空态)
│     ├─ {命中查询} _trackDisplay(过滤后的收藏)
│     └─ _trackDisplay(全部收藏)
├─ 搜索模式 → librarySearchProvider(query).when
│  ├─ loading → CircularProgressIndicator
│  ├─ error   → _LibraryError (搜索失败)
│  └─ data
│     ├─ {空结果} _NoSearchResults (无匹配空态)
│     └─ _trackDisplay(结果)
└─ 全部曲目 → libraryTracksProvider.when
   ├─ loading → CircularProgressIndicator
   ├─ error   → _LibraryError (加载失败)
   └─ data
      ├─ {空曲库} _EmptyLibrary (添加文件夹 / 导入本地音乐按钮)
      └─ _trackDisplay(全部曲目)

_trackDisplay (按视口宽度切换列表/网格):
└─ LayoutBuilder
   ├─ {紧凑} _trackList → ListView.builder
   │  └─ _TrackTile (曲目行)
   │     └─ ListTile
   │        ├─ leading: _TrackCover (圆角封面 48)
   │        ├─ title: 曲名
   │        ├─ subtitle: 艺术家 + _SourceBadge (来源徽标: 本地/B站)
   │        └─ trailing: Row( 播放指示图标 + 时长 + TrackActionsButton )
   └─ {宽屏} _trackGrid → GridView.builder
      └─ _TrackCard (曲目卡片)
         └─ Card → InkWell → Column
            ├─ Expanded → Stack
            │  ├─ _TrackCover (通栏封面)
            │  ├─ {正在播放} Positioned 播放指示角标
            │  └─ Positioned TrackActionsButton (右上角操作菜单)
            └─ Padding → Column( 曲名 + 艺术家 + _SourceBadge )

_SyncStatus (同步状态条 — 扫描/保存/封面/完成/失败):
└─ {非空闲} _SyncBanner (色调条)
   ├─ Row (图标 + 文本)
   └─ {进行中} LinearProgressIndicator (进度条)
```

## 设置页 SettingsScreen(设置)

```
SettingsScreen (设置页 ConsumerWidget)
└─ Scaffold (页面骨架)
   ├─ AppBar (标题栏, 标题「设置」)
   └─ body: ListView (滚动列表)
      ├─ _SectionHeader (「通用」)
      ├─ _GeneralSection (通用)
      │  └─ ListTile (语言 — 弹出 SimpleDialog 选择 跟随系统/中文/英文)
      ├─ _SectionHeader (「播放」)
      ├─ _PlaybackSection (播放缓存)
      │  ├─ ListTile (缓存位置 — _CacheLocationDialog: 路径+复制+清空)
      │  └─ ListTile (缓存上限 — _CustomLimitDialog: 数值 + MB/GB 分段选择)
      ├─ _SectionHeader (「曲库」)
      ├─ {支持本地曲库} _LibrarySection (曲库统计/扫描目录/重新扫描)
      │  ├─ ListTile (统计: 曲目数 + 已缓存数)
      │  ├─ _ScanRootHeader (扫描目录标题 + 添加入口)
      │  ├─ {扫描目录} ListTile × N (删除按钮 → 确认对话框)
      │  ├─ ListTile (添加文件夹)
      │  └─ ListTile (重新扫描, 带同步状态副标题)
      ├─ {无本地曲库} _UnsupportedLibraryNotice (不支持提示)
      ├─ _SectionHeader (「关于」)
      └─ _AboutSection (关于)
         ├─ ListTile (应用名 + 版本号)
         ├─ ListTile (开源许可证 → showLicensePage)
         ├─ ListTile (项目主页)
         └─ Text (许可证说明)
```

## 迷你播放条 MiniPlayerBar

```
MiniPlayerBar (迷你播放条 ConsumerWidget)
├─ {无播放} SizedBox.shrink (隐藏)
└─ {有播放}
   └─ Material (表面色块)
      └─ Column
         ├─ {时长>0} LinearProgressIndicator (顶部 2px 进度线)
         └─ InkWell (点击 → push PlayerScreen 全屏播放页)
            └─ Padding → Row
               ├─ _MiniCover (小封面 40×40)
               ├─ Expanded → Column (曲名 + 艺术家)
               ├─ IconButton (播放/暂停)
               └─ IconButton (下一首)
```

## 全屏播放页 PlayerScreen(正在播放)

由迷你播放条点击推入 `MaterialPageRoute`。

```
PlayerScreen (播放页 ConsumerWidget)
└─ Scaffold (页面骨架)
   ├─ AppBar (向下箭头收起 + 标题「正在播放」)
   └─ body: PlayerView (播放视图)
      ├─ {无播放} _NothingPlaying (未播放空态)
      └─ {有播放}
         └─ LayoutBuilder (按窗口尺寸算封面大小 140–320px)
            └─ SingleChildScrollView → Center → ConstrainedBox(maxWidth 520)
               └─ Column
                  ├─ _PlayerCover (大圆角封面 24px)
                  ├─ Text (曲名 headlineSmall)
                  ├─ Text (艺术家)
                  ├─ _ProgressBar (进度条 — 拖动时本地跟手, 松手后 seek)
                  │  ├─ Slider (进度滑条)
                  │  └─ Row (当前时间 … 总时长)
                  └─ _TransportControls (传输控制区)
                     └─ ConstrainedBox(maxWidth 420) → FittedBox → Row
                        ├─ _FavoriteButton (收藏心形)
                        ├─ IconButton (上一首)
                        ├─ IconButton.filled (播放/暂停)
                        ├─ IconButton (下一首)
                        └─ IconButton (播放模式: 顺序→列表循环→单曲循环→随机)
```

## B 站收藏夹浏览页 BilibiliFavoritesScreen

由曲库页「浏览 B 站收藏夹」菜单推入。

```
BilibiliFavoritesScreen (收藏夹浏览页 ConsumerStatefulWidget)
└─ Scaffold (页面骨架)
   ├─ AppBar
   │  ├─ leading: {已打开收藏夹} IconButton (返回收藏夹列表)
   │  ├─ title: Text (「浏览 B 站公开收藏夹」或收藏夹名)
   │  └─ bottom: {文件夹列表页} PreferredSize
   │     └─ Row (UID 输入框 + FilledButton 加载)
   └─ body
      ├─ {加载中} Center ( CircularProgressIndicator )
      ├─ {出错} _FavoritesError (失败面板 + 重试)
      ├─ {文件夹列表}
      │  ├─ {未输入} _FavoritesHint (引导空态)
      │  ├─ {无公开收藏夹} _FavoritesHint (空态)
      │  └─ ListView.builder
      │     └─ ListTile (文件夹: 头像图标 + 名称 + 数量 + chevron)
      └─ {曲目列表}
         ├─ {无可播放视频} _FavoritesHint (空态)
         └─ ListView.builder (曲目 + 1 个分页脚行)
            ├─ _FavoriteTrackTile (收藏曲目行)
            │  └─ ListTile (占位封面 + 标题 + UP 主 + 时长 + 存入曲库按钮)
            └─ _TrackListFooter (分页脚: 加载圈 / 重试 / 加载更多 / 已全部加载)
```

## 通用组件

### TrackActionsButton(轨道操作菜单)

曲库行/卡片、搜索结果行共用的弹出式操作菜单:

```
TrackActionsButton (轨道操作菜单 ConsumerWidget)
└─ PopupMenuButton<_TrackAction> (弹出菜单)
   ├─ PopupMenuItem: {收藏/取消收藏} (心形 + 文案)
   ├─ {非本地曲目} PopupMenuItem: 缓存到本地 (下载/已缓存/已固定)
   └─ {搜索/收藏夹场景} PopupMenuItem: 存入曲库
```

### 其他共享 widget

- `ResponsiveCenter` (响应式居中):`LayoutBuilder` → `SingleChildScrollView` →
  `ConstrainedBox(minHeight)` → `Center`,空间不够时转为纵向滚动,避免
  RenderFlex overflow。
- `CoverImage` (封面图):按显示尺寸解码(`cacheWidth = size × DPR`),
  `double.infinity` 时用 `LayoutBuilder` 推导边缘。
- `CacheActionButton` (缓存操作按钮):定义了下载/进度环/已缓存图标三态,
  **当前未在任何页面挂载**(已被 TrackActionsButton 弹出菜单取代)。

## 主题与断点

- `AppTheme.light` / `AppTheme.dark` / `ThemeMode.system`(跟随系统)。
- `AppBreakpoints` (app_theme.dart):
  - `compact` 断点 = **600** 逻辑像素宽;窗口更窄或竖屏(`height >= width`)
    一律按紧凑布局处理,桌面端拉窄窗口也会切换为手机式底部导航。
  - `NavigationRail` 标签在窗口高度 < 420 时收起为仅选中项显示。

## 文件索引

| 文件 | 内容 |
| --- | --- |
| `lib/main.dart` | 入口:音频服务初始化、会话恢复、缓存一致性、runApp |
| `lib/app/app.dart` | `FlindApp` 根组件(MaterialApp + 国际化 + 主题) |
| `lib/features/home/home_shell.dart` | `HomeShell` 自适应导航壳 |
| `lib/features/search/search_screen.dart` | B 站搜索页 |
| `lib/features/library/library_screen.dart` | 曲库页(搜索/收藏/列表/网格) |
| `lib/features/library/widgets/track_actions_button.dart` | 轨道操作弹出菜单 |
| `lib/features/library/widgets/cache_action_button.dart` | 缓存按钮(未挂载) |
| `lib/features/settings/settings_screen.dart` | 设置页(通用/播放/曲库/关于) |
| `lib/features/player/mini_player_bar.dart` | 迷你播放条 |
| `lib/features/player/player_screen.dart` | 全屏播放页 |
| `lib/features/playlists/bilibili_favorites_screen.dart` | B 站公开收藏夹浏览 |
| `lib/shared/responsive_center.dart` | 防溢出居中容器 |
| `lib/shared/cover_image.dart` | 封面图(按需解码) |