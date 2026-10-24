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
            ├─ theme / darkTheme (亮色/暗色主题)
            ├─ themeMode ← appThemeModeProvider (外观: 自动/浅色/深色, 持久化)
            ├─ scrollBehavior: AppScrollBehavior (放开 mouse/trackpad 拖拽 — 桌面端可拖动分页器)
            └─ home: StartupPermissionScope (启动即申请「访问本地音乐」权限)
               └─ HomeShell (主界面壳)
```

> `FlindApp` 同时 watch `coverPrefetchCoordinatorProvider`,让队列封面预取
> 协调器在整个会话期间保持存活。
>
> **桌面端滑动**:Flutter 默认的 `MaterialScrollBehavior` 把 `PointerDeviceKind.mouse`
> 排除在 `dragDevices` 之外,所以桌面端的水平 `PageView`(如曲库三段分页器)鼠标拖不动,
> 只能滚轮 / 触控板。`lib/app/app_scroll_behavior.dart` 的 `AppScrollBehavior` 把
> mouse / trackpad 等指针类型加回 `dragDevices`,在 `MaterialApp.scrollBehavior` 上全局生效;
> 触摸设备不受影响(不会产生这些指针事件)。对照实现见 `test/app_scroll_behavior_test.dart`
> (含「默认行为下鼠标拖拽无效」的反向断言)。

## 主壳 HomeShell(自适应布局)

HomeShell 用 `LayoutBuilder` 按窗口尺寸一分为二:
宽度 < 600 或竖屏 → **紧凑模式**(底部导航);否则 → **宽屏模式**(侧边导航)。
各个页面由 `IndexedStack` 保持状态;每个目的地页面自带 `Scaffold`。

```
HomeShell (主界面壳 StatefulWidget)
└─ LayoutBuilder (响应式布局决策)
   ├─ {宽屏模式}
   │  └─ Scaffold (background: AppSurface.colorOf)
   │     └─ SafeArea (安全区)
   │        └─ Column (垂直布局)
   │           ├─ Expanded
   │           │  └─ Row (水平布局)
   │           │     ├─ _NarrowRail (自绘 76px 窄栏 + 右侧发丝线)
   │           │     │  ├─ _RailBrand (品牌圆标)
   │           │     │  └─ 3 × _RailItem (强调色只包图标圆底; 标签不盖底; 仅选中项显示标签)
   │           │     └─ Expanded → IndexedStack (页面堆栈 — 保持各页状态)
   │           │        ├─ SearchScreen (搜索页, 见下)
   │           │        ├─ LibraryScreen (曲库页, 见下)
   │           │        └─ SettingsScreen (设置页, 见下)
   │           └─ DesktopPlayerBar (全宽底部播放条, 见下; 无曲目时收起)
   │
   └─ {紧凑模式}
      └─ Scaffold (background: AppSurface.colorOf, extendBody: true)
         ├─ body: IndexedStack (页面堆栈 — 同上三个页面)
         └─ bottomNavigationBar: SafeArea → GlassSurface (圆角悬浮 dock)
            └─ Column (垂直布局)
               ├─ MiniPlayerBar(embedded: true) (迷你播放条, 见下)
               └─ NavigationBar (底部导航栏, labelBehavior: onlyShowSelected)
                  └─ 3 × NavigationDestination (搜索/曲库/设置)
```

## 共享背景 AppSurface

页面底色统一为中性画布(`colorScheme.surface`),不再使用被主题色染色的
`surfaceContainerHigh`;抬升表面改用 `surfaceContainerLow/High` 等角色。

```
AppSurface (共享页面表面)
├─ Material (color: colorOf = colorScheme.surface)
├─ colorOf(context) — 静态方法,Scaffold 背景直达同一颜色
└─ borderRadius (可选, clip 随圆角)
```

使用方:所有页面与歌单详情等 `Scaffold` 的 `backgroundColor`。播放条、
设置条与歌词预览已改为直接使用角色色或透明材质,不再经过 `AppSurface`。

## 搜索页 SearchScreen(多音源搜索)

`AppPageHeader` 大标题 + 填充式搜索框(提交时才发起搜索,避免触顶 -412 限流)。
在线源注册表(`onlineSourcesProvider`)多于一个时,搜索框下方显示胶囊式
`_SourceSwitcher` 切源(B站/网易云),结果按选中源路由到
`onlineSearchProvider((sourceId, query))`。内容区限宽 960 并居中。

```
SearchScreen (搜索页 ConsumerStatefulWidget)
└─ PlaybackPermissionScope (播放权限作用域 — 授予后才允许播放)
   └─ Scaffold (background: AppSurface.colorOf)
      └─ SafeArea → Center → ConstrainedBox(maxWidth: 960) → Column
         ├─ AppPageHeader (标题: navSearch)
         ├─ Padding → ValueListenableBuilder (清空按钮随输入状态显隐)
         │  └─ TextField (搜索输入框 — 数字键盘/提交触发)
         ├─ {多于一个在线源} Padding → _SourceSwitcher
         │     └─ _SourceChip × N (胶囊切源: B站/网易云 ← onlineSourcesProvider)
         └─ Expanded → _buildBody(选中源 id)
            ├─ {未提交关键词} _SearchHint (搜索引导空态 — 源无关文案)
            │  └─ ResponsiveCenter → Icon + 标题 + 提示文案
            └─ {已提交} onlineSearchProvider((sourceId, query)).when (按源异步分发)
               ├─ loading → Center ( CircularProgressIndicator 加载圈 )
               ├─ error   → _SearchError (搜索失败面板, 带重试按钮)
               └─ data
                  ├─ {空结果} _NoResults (无结果空态)
                  └─ ListView.separated (结果列表, 发丝线分隔)
                     └─ _SearchResultTile
                        └─ TrackListRow (与曲库共用的曲目行)
                           ├─ 封面 48×48 / 标题 / 艺术家
                           ├─ {正在播放} Icon (graphic_eq)
                           ├─ Text (时长)
                           └─ TrackActionsButton (showSaveToLibrary: true)
```

## 曲库页 LibraryScreen(全部 / 收藏 / 歌单)

`AppPageHeader` 大标题 + 右上工具区(更多菜单 / {歌单段} 新建「+」),
下方左对齐的三段轮盘选择器。内容区限宽 1120 并居中。
搜索框**属于「全部」页本身**(位于环形 `PageView` 内),随该页左右滑动而非在切换时突然显隐;「收藏」「歌单」页无搜索框。
三段主体位于环形无缝 `PageView` 中(右划前进: 全部 → 收藏 → 歌单 → 全部,两端皆可循环);
视图按段独立持久化(见「视图系统」)。
扫描/保存进度以 SnackBar 气泡通知;无 `_SyncStatus` 常驻条。

```
LibraryScreen (曲库页 ConsumerStatefulWidget)
└─ Scaffold (background: AppSurface.colorOf) + SafeArea(bottom: false)
   └─ Center → ConstrainedBox(maxWidth: 1120) → Column
      ├─ _buildHeaderRow
      │  ├─ AppPageHeader (标题「曲库」)
      │  │  ├─ actions: _buildMoreMenu (key: library_more_menu)
      │  │  │  └─ MenuAnchor
      │  │  │     ├─ 「本地」 SubmenuButton {支持本地曲库}
      │  │  │     │  ├─ 添加文件夹 (非同步中)
      │  │  │     │  ├─ 重新扫描 (非同步中)
      │  │  │     │  └─ 导入文件
      │  │  │     ├─ 「排序」 SubmenuButton → 标题/艺术家/专辑/最近添加 (当前项打勾)
      │  │  │     ├─ 「视图」 SubmenuButton → 当前段的可用视图 (当前项打勾)
      │  │  │     └─ 「浏览 B 站收藏夹」 → 推入 BilibiliFavoritesScreen
      │  │  └─ {歌单段} IconButton (「+」新建歌单 → PlaylistEditorDialog)
      │  └─ Padding → Align(左) → _LibraryFilterSelector
      │     (三段轮盘: 左=下一段, 中=选中, 右=上一段)
      │     └─ GestureDetector (点标签切换 + 横向拖拽: 右拖前进 / 左拖后退)
      │        └─ AnimatedSwitcher (交叉淡化 + 位移 250ms)
      │           └─ Row (中=选中项加粗放大; 左右为减弱候选项)
      └─ Expanded
         ├─ {支持本地曲库} _buildBody (环形 PageView: 右划前进 / 左划后退)
         │  └─ {「全部」页} Column (搜索框随本页一起滑动)
         │     ├─ _buildSearchField (内联搜索框)
         │     │  └─ Padding → ValueListenableBuilder → TextField
         │     │     (250ms 防抖搜索, 清空后缀按钮, 提示「搜索曲库」)
         │     └─ Expanded → _buildAllBody (搜索 / 全部曲目)
         └─ {iOS 等无本地曲库} _UnsupportedLibraryNotice (不支持提示)

主体 (按段分支, 曲目列表统一委托 TrackView):
├─ {歌单段} PlaylistsSection(view: 歌单段视图) — 见下
├─ {收藏段} favoritesProvider.when + 客户端排序 → TrackView(view: 收藏段视图)
└─ {全部段} 搜索 / 全部曲目
   ├─ {有查询} librarySearchProvider(_query).when
   │  ├─ loading → CircularProgressIndicator
   │  ├─ error   → _LibraryError (搜索失败)
   │  └─ data    → {空结果} _NoSearchResults | TrackView(结果)
   └─ {无查询} libraryTracksProvider.when
      ├─ loading → CircularProgressIndicator
      ├─ error   → _LibraryError (加载失败)
      └─ data    → {空曲库} _EmptyLibrary | TrackView(全部曲目)

TrackView (曲目渲染器 — 全部/收藏/歌单详情共用, track_view.dart):
├─ {list} ListView.separated
│  └─ TrackTile (曲目行, track_list_items.dart)
│     └─ TrackListRow (搜索页共用)
│        ├─ TrackCover (圆角封面 48, sm 圆角)
│        ├─ 曲名 / 艺术家 + SourceBadge (来源圆点 + 名称)
│        ├─ {正在播放} Icon (graphic_eq)
│        ├─ 时长 (tabular numerals)
│        └─ TrackActionsButton
├─ {showcase} GridView.builder (maxCrossAxisExtent 260)
│  └─ TrackCard (曲目卡片, track_list_items.dart)
│     └─ Material(transparent) → InkWell → Column
│        ├─ Expanded → Stack
│        │  ├─ TrackCover (通栏封面, md 圆角)
│        │  ├─ {正在播放} Positioned 播放指示丸
│        │  └─ Positioned TrackActionsButton (右上角半透明圆底)
│        └─ Padding → Column( 曲名 + 艺术家 + SourceBadge )
└─ {waterfall} MasonryGridView.count (列数按宽度 2–5)
   └─ WaterfallTrackCard (瀑布流卡片)
      └─ Material(transparent) → InkWell → Column
         ├─ Stack
         │  ├─ AspectRatio(封面真实宽高比 ← coverAspectRatioProvider)
         │  │  └─ TrackCover (通栏封面)
         │  ├─ {正在播放} Positioned 播放指示角标
         │  └─ Positioned TrackActionsButton (右上角)
         └─ Padding → Column( 曲名 + 艺术家 + SourceBadge )

TrackActionsButton 菜单:
├─ 收藏 / 取消收藏
├─ {在线曲目} 离线缓存 (未缓存, 可点击) | 已缓存 (不可点击)
├─ {搜索结果} 存入曲库
├─ 加入歌单
├─ {playlistId != null} 移出歌单 (仅移除本歌单, 保留曲库)
└─ {showDeleteTrack} 删除歌曲 (危险: 二次确认 → TrackDeletionService)

视图系统:
- 作用域 LibraryViewScope: all / favorites / playlists / playlistDetail
- 视图 LibraryView: showcase / list / waterfall
- 默认: all=waterfall, favorites=showcase, playlists=showcase, playlistDetail=list
- playlists 作用域仅允许 showcase/list; 持久化于 shared_preferences (键 library.view.*)
- 「歌单」列表无自建歌单时回落列表, 以显示空态

删除歌曲 (危险操作): TrackDeletionService 从所有歌单移除 + 删除曲库行 + 删除离线缓存;
本地磁盘原始文件不动。

PlaylistsSection (歌单区 ConsumerWidget, 收藏置顶 + 自建歌单):
├─ {showcase 且 有自建歌单} GridView.count → PlaylistCard × (收藏 + 自建)
│  └─ PlaylistCard (Card: 派生封面 + 名称 + 曲目数; 收藏卡 primary 图标)
│     → 收藏卡切到收藏段 / 自建卡推入 PlaylistDetailScreen
└─ {list 或 无自建歌单}
   └─ ListView
      ├─ _FavoritesRow (置顶收藏行, primary 强调色, 不可删除, 点击切到收藏段)
      │  └─ ListTile (派生封面 + 「收藏」 + 曲目数)
      ├─ {无自建歌单} _EmptyPlaylists (空态提示)
      └─ {有自建歌单}
         ├─ Padding → Text (「我的歌单」标题)
         └─ _PlaylistRow × N (自建歌单行)
            └─ ListTile (派生封面 + 名称 + 曲目数)
               → 点击推入 PlaylistDetailScreen

PlaylistDetailScreen (歌单详情页 ConsumerWidget)
└─ Scaffold (background: AppSurface.colorOf)
   ├─ AppBar (歌单名 + {自建} 编辑/删除按钮 + LibraryViewMenuButton(playlistDetail))
   └─ playlistTracksProvider(id).when
      ├─ loading → CircularProgressIndicator
      ├─ error   → 重试按钮
      └─ data
         ├─ _PlaylistHeader (封面 + 名称 + 简介 + 曲目数, 点击封面可换)
         └─ Expanded → {空} _EmptyPlaylist | TrackView(view: 歌单详情视图,
            playlistId 传入 → 「移出歌单」, showDeleteTrack: true → 「删除歌曲」)

PlaylistEditorDialog (歌单编辑器对话框 ConsumerStatefulWidget, 创建/编辑)
└─ AlertDialog
   ├─ title: 新建歌单 / 编辑歌单
   └─ content: Column
      ├─ TextField (名称, 必填, 空名报错)
      ├─ TextField (简介, 可选)
      └─ 封面区 (56×56 预览 + 选择图片 + 移除封面)

PlaylistPickerSheet (加入歌单底部选择器 ConsumerStatefulWidget)
└─ showModalBottomSheet (showDragHandle)
   └─ SafeArea → Column
      ├─ Text (「选择歌单」)
      └─ ListView
         ├─ _PlaylistPickerRow × N (封面 + 名称, 已含该曲时打勾禁用)
         └─ ListTile (「新建歌单」→ PlaylistEditorDialog → 创建后直接加入)

同步气泡通知 (ScaffoldMessenger SnackBar — 无常驻状态条):
├─ {扫描/保存/封面} SnackBar(duration: 1天) — 文案 + LinearProgressIndicator 进度
└─ {完成/失败}  SnackBar(3s) — 「新增 X · 删除 Y」总结 / 失败描述
```

## 设置页 SettingsScreen(设置)

`AppPageHeader` 页头 + 限宽 760 的滚动列表;`SafeArea(bottom: false)` 保证
「通用」标题不被状态栏遮挡。「通用」分区提供 **外观(主题模式)** 切换。

```
SettingsScreen (设置页 ConsumerWidget)
└─ Scaffold (background: AppSurface.colorOf)
   └─ body: SafeArea(bottom: false) → Center → ConstrainedBox(maxWidth: 760)
      └─ SingleChildScrollView → Column
         ├─ AppPageHeader (「设置」)
         ├─ SectionHeader (「通用」)
         ├─ _GeneralSection (通用)
         │  ├─ ListTile (语言 → SimpleDialog: 跟随系统/中文/英文)
         │  └─ ListTile (外观 → SimpleDialog: 自动/浅色/深色, 经 appThemeModeProvider 持久化)
         ├─ SectionHeader (「播放」)
         ├─ _PlaybackSection (播放缓存)
         │  ├─ ListTile (缓存位置 → _CacheLocationDialog: 路径+复制+清空缓存)
         │  └─ ListTile (缓存上限 — 音频与封面共享额度 → _CustomLimitDialog,
         │                单一 MB 数值输入, 确认后强制执行限额)
         ├─ SectionHeader (「曲库」)
         ├─ {支持本地曲库} _LibrarySection (曲库统计/扫描目录/重新扫描)
         │  ├─ ListTile (统计: 曲目数 + 已缓存数)
         │  ├─ _ScanRootHeader (扫描目录标题 + 添加入口)
         │  ├─ scanRootsProvider.when
         │  │  ├─ loading → CircularProgressIndicator
         │  │  ├─ error   → ListTile (失败 + 重试按钮)
         │  │  └─ data    → {空} 无扫描目录提示 | ListTile × N (删除 → 确认对话框)
         │  ├─ ListTile (添加文件夹)
         │  └─ ListTile (重新扫描, 带同步状态副标题: 扫描中/保存中/封面缓存/完成/失败)
         ├─ {无本地曲库} _UnsupportedLibraryNotice (不支持提示)
         ├─ SectionHeader (「关于」)
         └─ _AboutSection (关于)
            ├─ ListTile (应用名 + 版本号, packageInfoProvider)
            ├─ ListTile (开源许可证 → showLicensePage)
            ├─ ListTile (项目主页)
            └─ Text (许可证说明)
```

## 迷你播放条 MiniPlayerBar

```
MiniPlayerBar (迷你播放条 ConsumerWidget)
├─ {无播放} SizedBox.shrink (隐藏)
└─ {有播放} content
   └─ Column
      ├─ Padding → Row
      │  ├─ Expanded → _MiniLabelStrip (44px; 封面 + 曲名/艺术家,
      │  │   点击 → push PlayerScreen; 支持横滑切歌)
      │  ├─ IconButton (播放/暂停)
      │  └─ IconButton (下一首, 无下一首时禁用)
      └─ {时长>0} LinearProgressIndicator (底部 2px 进度线)
   {embedded: false} → Padding → GlassSurface (lg 圆角 + 阴影) → content
   {embedded: true}  → content 直接嵌入移动端合并 dock
```

## 全屏播放页 PlayerScreen(正在播放)

由迷你播放条/桌面播放条点击推入非透明路由。播放页**始终使用暗色主题**
(浅色模式下也用 `AppTheme.dark`),背景是当前封面的模糊环境色 + 渐变遮罩;
无 AppBar,标题/艺术家在共享 `_HeaderRow`,正文按方向分栏。
播放/暂停按钮在按下瞬间切换;音频增益和进度波共用
`PlaybackController.fadeDuration`(700ms, cosine S 曲线),两者同时开始、同时收束。

```
PlayerScreen (播放页 StatelessWidget)
└─ Theme (暗色播放器主题) → AppSystemUiOverlay → Scaffold(transparent)
   └─ BlockSemantics → _PlayerDismissWrapper (下拉关闭 + 背景压暗)
      └─ PlayerView (播放视图 ConsumerStatefulWidget)
         └─ LayoutBuilder (landscape = maxWidth > maxHeight)
            ├─ _NowPlayingBackdrop (封面模糊 48σ + 双层渐变 + accent 径向光)
            └─ SafeArea → Stack
               ├─ Column
               │  ├─ _HeaderRow (共享头部行)
               │  ├─ Expanded → body:
               │  │  ├─ {无播放} EmptyState (未播放空态)
               │  │  ├─ {横屏}   _LandscapeBody (左右分栏, 见下)
               │  │  └─ {竖屏}   _PortraitBody (上下布局, 见下)
               │  └─ {竖屏} AnimatedSize → MiniSettings (底部停靠设置条)
               │     └─ {歌词展开或无播放时} SizedBox (设置条让位)
               └─ Positioned.fill → AnimatedSwitcher (淡入 + 上滑 220ms)
                  └─ {音量浮层打开} Stack(key: volume_overlay)
                     ├─ GestureDetector (全屏遮罩, 点击关闭)
                     └─ Positioned (下方: 横屏左半宽 / 竖屏通栏, 高 56)
                        └─ VolumeBar (不透明音量条, 完整覆盖 MiniSettings)

_HeaderRow (共享头部行 — 取代原 AppBar)
└─ Row
   ├─ IconButton (keyboard_arrow_down 向下箭头 → maybePop 收起)
   ├─ Expanded → Column (曲名 titleMedium w700 + 艺术家 bodySmall)
   └─ SizedBox(width: 48) (右侧配重, 保持标题居中)

_PortraitBody (竖屏正文)
└─ Column
   ├─ Expanded → _PortraitPager (横滑: 封面 ⇄ 歌词, 250ms, 跟随手指)
   │  ├─ _PortraitNormal
   │  │  └─ Column
   │  │     ├─ Expanded → _CoverArt (自适应封面, 底部对齐)
   │  │     │  └─ LayoutBuilder (edge = min(w, h); size = (edge×0.82).clamp(min(80,edge), 480))
   │  │     │     └─ Center → Padding(24,8,24,12) → _PlayerCover
   │  │     └─ SizedBox (约 3.6 行歌词高度) → LyricsPreview (点击展开)
   │  └─ LyricsView (全屏歌词 — provider 驱动, 点击收起, 见下)
   ├─ _ProgressBar (进度条, 见下)
   ├─ _TransportControls (传输控制区, 见下)
   └─ SizedBox (歌词展开 24 / 折叠 16 — 与设置条分隔)

_LandscapeBody (横屏正文 — 左右等宽双栏, 无分隔线)
└─ Row
   ├─ Expanded → MiniMain (左栏: 迷你主视图)
   │  └─ Column
   │     ├─ Expanded → LayoutBuilder (与竖屏同一公式: edge = min(w, h);
   │     │   size = (edge×0.82).clamp(min(80,edge), 480))
   │     │  └─ Center → _PlayerCover (封面随窗口缩放)
   │     ├─ _ProgressBar
   │     ├─ _TransportControls
   │     ├─ SizedBox(16)
   │     └─ MiniSettings (设置条内嵌于左栏底部)
   └─ Expanded → LyricsView (右栏: 全屏歌词 — provider 驱动)

_PlayerCover (大圆角封面 24px — 本地路径/网络 URL 皆可)
└─ ClipRRect → Container(尺寸见上)
   └─ {有封面} CoverImage | {无封面} Icon (music_note 占位)

_ProgressBar (可拖动进度条 ConsumerStatefulWidget — 拖动本地跟手, 松手 seek)
└─ Padding → Row
   ├─ Text (当前时间 m:ss — 拖动期间显示预览位置)
   ├─ Expanded → PlayerProgressBar (自绘轨道, 高 36)
   │  ├─ 播放/暂停: 正弦波振幅 0 ⇄ 4.5, 与 700ms cosine S 音频淡入/淡出同步
   │  ├─ 播放中: 相位每 1500ms 滚过一个波长, 波形横向流动
   │  ├─ 缓冲: 点状脉冲动画(1200ms 循环)
   │  ├─ 已播放段 primary, 剩余段 onSurface 22%; 6px thumb 随波形上下浮动 + 柔光
   │  └─ 手势拖动/点击 → onChanged + onChangeEnd(松手 seek)
   └─ Text (总时长)

_TransportControls (传输控制 — 居中成组的三级尺寸层级, 禁止 spaceBetween)
└─ LayoutBuilder (可用宽 ≥340 用舒适布局; <340 回退紧凑布局, 任何尺寸都不 overflow)
   └─ Row (mainAxisAlignment: center)
      ├─ {无曲目} SizedBox.shrink | _FavoriteButton (收藏 44/26 — 已收藏红, 未收藏 onSurfaceVariant)
      ├─ gap 20 → IconButton (上一首 52/32, 无则禁用)
      ├─ gap 10 → IconButton.filled (播放/暂停 64/36 — 主按钮, 突出)
      ├─ gap 10 → IconButton (下一首 52/32, 无则禁用)
      └─ gap 20 → IconButton (queue_music 播放队列 44/26, onSurfaceVariant → showPlayerPanel)
   舒适总宽 316 (44+20+52+10+64+10+52+20+44);
   紧凑回退全部 44 + gap 4 = 236 (适配 480×320 横屏的 240px 左栏)。
```

### MiniSettings(底部设置条)与 VolumeBar

```
MiniSettings (底部设置条 ConsumerWidget, 高 kMiniSettingsHeight=56)
└─ Material(transparent) → SizedBox(56) → Row (5 等分)
   ├─ Expanded → _barButton 更多 (more_vert → showPlayerPanel(EmptyPanel))
   ├─ Expanded → _barButton 调节 (tune → showPlayerPanel(EmptyPanel, 竖屏高 0.8))
   ├─ Expanded → _sleepTimerButton (定时关闭)
   │  └─ InkWell → SizedBox(56) → Column
   │     ├─ Icon (timer_outlined / 已启用 timer — 主色着色)
   │     └─ {倒计时模式} Text (mm:ss 实时倒计时)
   │        {播完本曲} Container (6px 圆点)
   │        → showPlayerPanel(SleepTimerPanel, 竖/横屏均 0.5)
   ├─ Expanded → _barButton 音量 (音量图标随增益变化 → onVolumeTap 打开浮层)
   └─ Expanded → PlayModeButton (播放模式 — 顺序/列表循环/单曲循环/随机)
      └─ IconButton (playlist_play/repeat/repeat_one/shuffle,
                     非顺序时图标主色着色)

VolumeBar (音量浮层 ConsumerWidget, 高 56)
└─ Material(surfaceContainerHigh) (悬浮 pill: lg 圆角 + 边框 + elevation)
   └─ SizedBox(56) → Row
      ├─ Icon (volume_off/down/up 按增益分档)
      ├─ Expanded → Slider (0.01–1.4, onChanged 直写 setVolume)
      └─ Text (百分比, labelMedium + 等宽数字)
   打开时: 宽度上限 520px, 在横屏左栏/竖屏内容区居中, bottom 12px;
   MiniSettings 在下方保持占位但隐藏绘制, 不再叠画。
```

### 面板系统 player_panels(播放器面板)

```
showPlayerPanel (面板助手 — 浮动卡片, 不再满高侧抽)
├─ {横屏} showGeneralDialog(barrier 38%) → SafeArea → Padding(16)
│  └─ Align(centerRight) → SizedBox(宽 320–420, 高 ≤680)
│     → _PanelFrame(landscape: true) (四角 24 + 阴影 + 右侧滑入/淡入)
└─ {竖屏} showModalBottomSheet (isScrollControlled + useSafeArea)
   └─ Padding(12) → SizedBox(高×0.66) → _PanelFrame (四角 24 + 拖动手柄)

_PanelFrame (面板骨架) → Material(surfaceContainerHigh, elevation 24, 四角 24)
├─ 边框发丝线
├─ {竖屏} 拖动手柄 (36×4 圆角条)
└─ Expanded → 面板内容

_PanelHeader (面板标题行)
└─ Row [ 40px primary 软底图标 + Text(标题) + 圆形关闭按钮 ]

EmptyPanel (空面板 — 更多/调节 占位)
└─ Column [ _PanelHeader + Center (Icon 48 + 「暂无内容」) ]

SleepTimerPanel (睡眠定时面板 ConsumerWidget)
└─ Column
   ├─ _PanelHeader (「睡眠定时」)
   └─ Expanded → ListView
      ├─ {定时中} _ActiveBanner (primaryContainer 横幅: 剩余时间/播完本曲)
      ├─ _OptionRow 关闭 (mode == off 高亮)
      ├─ _OptionRow × 5 (10/20/30/45/60 分钟预设 — 计数归零即暂停)
      └─ _OptionRow 播完本曲 (当前歌曲结束后暂停 — 会话级, 不持久化)

PlaylistPanel (播放队列面板 ConsumerWidget)
└─ Column
   ├─ _PanelHeader (「播放队列」)
   └─ Expanded → {空} 提示 Center | ListView.builder
      └─ _QueueRow (InkWell → Container)
         ├─ {当前曲目} Icon (graphic_eq) + 行背景高亮 + 标题主色加粗
         ├─ _QueueCover (封面 40×40)
         └─ Column (曲名 + 艺术家)
         → 点击 playQueue(index) 跳转并关面板
```

### 歌词 LyricsView / LyricsPreview

provider 驱动:watch `playbackStateProvider`(当前曲目 + 播放位置)与
`trackLyricsProvider(当前曲目)`;有歌词时按 `Lyric.indexAt(position)` 高亮当前行
并自动滚动居中,翻译以次级样式渲染在原文下方;无歌词或源未适配时回落占位
(「词莫见,敬聆听」)。

```
LyricsView (全屏歌词 ConsumerStatefulWidget, 点击回调 onTap 收起竖屏歌词页)
└─ GestureDetector (opaque)
   ├─ {无曲目/无歌词/空歌词} _LyricsPlaceholder (占位)
   │  └─ LayoutBuilder → SingleChildScrollView → ConstrainedBox(minHeight) → Center
   │     └─ Column [ Icon(lyrics_outlined) + Text(占位标题)
   │                 + Text(提示: sourceSupportsLyricsProvider 为真 → 「暂无歌词」,
   │                        否则 → 「该音源暂未适配歌词」) ]
   └─ {有歌词} ListView.builder (Lyric.lines, controller 自滚动)
      └─ Container {当前行} key: lyric-current (主色加粗)
         └─ Column [ Text(原文) + {有翻译} Text(次级样式翻译) ]
         → index 变化时 animateTo 居中(250ms easeOut, 估算行高 56)

LyricsPreview (歌词 teaser 条 — 竖屏封面下约 3.6 行高 ConsumerWidget)
└─ GestureDetector (透明, 直接叠在播放页环境背景上; 点击展开歌词页)
   └─ LayoutBuilder → SingleChildScrollView → ConstrainedBox(minHeight) → Center
      └─ Padding → Column
         ├─ {无歌词} Icon(20) + Text(占位文案, 单行省略)
         └─ {有歌词} Container(key: lyric-current)
            → 当前行(主色) [ + {有翻译} 单行翻译 ]
```

## B 站收藏夹浏览页 BilibiliFavoritesScreen

由曲库页「浏览 B 站收藏夹」菜单推入。内容内 `AppPageHeader` 提供返回/标题,
UID 输入条仅文件夹页显示;内容区限宽 960。

```
BilibiliFavoritesScreen (收藏夹浏览页 ConsumerStatefulWidget)
└─ Scaffold (background: AppSurface.colorOf) + SafeArea(bottom: false)
   └─ Center → ConstrainedBox(maxWidth: 960) → Column
      ├─ AppPageHeader (leading: arrow_back → {已打开收藏夹} 返回列表 | 否则 pop;
      │                  title: 「浏览 B 站公开收藏夹」或收藏夹名)
      ├─ {文件夹列表页} _buildUidBar
      │  └─ Row [ Expanded TextField (UID, 数字键盘) + FilledButton 加载 ]
      └─ Expanded → _buildBody
         ├─ {加载中} Center ( CircularProgressIndicator )
         ├─ {出错} _FavoritesError (失败面板 + 重试)
         ├─ {文件夹列表}
         │  ├─ {未输入 UID} EmptyState (引导空态)
         │  ├─ {无公开收藏夹} EmptyState (空态)
         │  └─ ListView.builder
         │     └─ ListTile (44px 圆角文件夹图标 + 名称 + 数量 + chevron)
         └─ {曲目列表}
            ├─ {无可播放视频} EmptyState (空态)
            └─ ListView.separated (曲目 + 1 个分页脚行, 发丝线分隔)
               ├─ _FavoriteTrackTile → TrackListRow
               │  (封面 48 + 标题 + UP 主 + graphic_eq + 时长
               │   + TrackActionsButton(showSaveToLibrary: true))
               └─ _TrackListFooter (分页脚: 加载圈 / 重试 / 加载更多 / 已全部加载)
```

## 通用组件

### TrackActionsButton(轨道操作菜单)

曲库行/卡片、搜索结果行共用的弹出式操作菜单(取代原平铺按钮,避免 400px
宽度溢出;菜单项按轨道来源/场景动态增删):

```
TrackActionsButton (轨道操作菜单 ConsumerWidget)
└─ PopupMenuButton<_TrackAction>
   ├─ PopupMenuItem: {收藏/取消收藏} (心形 + 文案, 收藏者主色)
   ├─ {非本地曲目} PopupMenuItem: 缓存到本地 (下载/已缓存/已固定 — 三态图标文案)
   ├─ {showSaveToLibrary: 搜索行} PopupMenuItem: 存入曲库
   ├─ PopupMenuItem: 加入歌单 → PlaylistPickerSheet (底部选择器)
   └─ {playlistId 非空: 歌单详情内} PopupMenuItem: 移出歌单
```

### 其他共享 widget

- `AppSurface` (共享表面):见上「共享背景 AppSurface」。
- `ResponsiveCenter` (响应式居中):`LayoutBuilder` → `SingleChildScrollView` →
  `ConstrainedBox(minHeight)` → `Center`,空间不够时转为纵向滚动,避免
  RenderFlex overflow。
- `CoverImage` (封面图):`path`(本地缓存)优先,`url`(网络)兜底;按显示尺寸解码
  (`cacheWidth = size × DPR`),`double.infinity` 时用 `LayoutBuilder` 推导
  边缘。文件失效时自动回退到网络 URL。
- `PlayModeButton` (播放模式按钮):顺序/列表循环/单曲循环/随机四态循环,
  由 `playbackStateProvider` 推导当前态(随机优先),切换时先设 shuffle
  再设 repeat。
- `CacheActionButton` (缓存操作按钮):定义了下载/进度环/已缓存图标三态,
  **当前未在任何页面挂载**(已被 TrackActionsButton 弹出菜单取代)。
- 非 UI 提供者:`sleepTimerProvider`(睡眠定时 — 会话级,倒计时/播完本曲,
  触发时仅暂停播放)。

## 主题与断点

- `AppTheme.light` / `AppTheme.dark`(Material 3),外加 `appThemeModeProvider`
  驱动的 **自动/浅色/深色** 三态外观切换(持久化于设置仓)。
- `AppPalette` 提供中性纸感/近黑 surface,主题色(seed)只驱动 accent、
  primary 与选中态,不再染遍全部 surface。
- `AppTypography` 统一字阶、行高、字重与数字等宽;`AppRadius` 收敛为
  `sm 8 / md 16 / lg 24 / pill` 四档。
- `AppIcons` 统一映射 Lucide Regular 线性图标;主播放/暂停是例外,使用
  实心 rounded glyph(Lucide 没有 Fill),激活收藏使用 600 字重。
- `AppSurface`(shared/app_surface.dart)统一页面底色为 `colorScheme.surface`。
- `AppBreakpoints` (app_theme.dart):
  - `compact` 断点 = **600** 逻辑像素宽;窗口更窄或竖屏(`height >= width`)
    一律按紧凑布局处理,桌面端拉窄窗口也会切换为手机式底部导航。
  - 宽屏自绘 `_NarrowRail` 与紧凑 `NavigationBar` 均采用 **仅选中项显示标签**,
    不再依赖窗口高度收起;窄栏的选中/悬停底是 16px 圆角块,不是方形。

## 文件索引

| 文件 | 内容 |
| --- | --- |
| `lib/main.dart` | 入口:音频服务初始化、会话恢复、缓存一致性、runApp |
| `lib/app/app.dart` | `FlindApp` 根组件(MaterialApp + 国际化 + 语言/主题模式) |
| `lib/app/app_scroll_behavior.dart` | `AppScrollBehavior` — 放开鼠标/触控板拖拽(桌面端分页可拖) |
| `lib/app/theme_mode.dart` | `appThemeModeProvider` 外观切换(自动/浅色/深色) |
| `lib/app/theme/app_palette.dart` | 中性浅色/深色 surface 调色板(seed 仅作 accent) |
| `lib/app/theme/app_typography.dart` | 全局字阶、行高、字重与等宽数字 |
| `lib/app/theme/app_icons.dart` | `AppIcons` — Lucide Regular 图标语义映射 |
| `lib/features/home/home_shell.dart` | `HomeShell` 自适应导航壳(窄 rail / 合并 dock) |
| `lib/features/player/desktop_player_bar.dart` | 宽屏全宽底部播放条 |
| `lib/shared/app_page_header.dart` | 三页共用的大标题页头 |
| `lib/shared/app_surface.dart` | 统一页面底色 + `colorOf` |
| `lib/features/search/search_screen.dart` | 多音源搜索页(页头 + 胶囊切源 + onlineSearchProvider) |
| `lib/features/library/library_screen.dart` | 曲库页(页头/三段式选择器/搜索/收藏/歌单/列表/网格) |
| `lib/core/models/library_view.dart` | 视图模型:`LibraryView`(展柜网格/列表/瀑布流) + `LibraryViewScope`(按段作用域) |
| `lib/features/library/library_view_provider.dart` | `LibraryViewsNotifier` — 按段持久化的多视图(存设置仓) |
| `lib/features/library/library_sort_provider.dart` | 曲库排序(标题/艺术家/专辑/最近添加) |
| `lib/features/library/track_sorting.dart` | 排序比较器与本地化键 |
| `lib/features/library/cover_aspect_ratio_provider.dart` | 封面宽高比设置(瀑布流用) |
| `lib/features/library/playlist_detail_screen.dart` | 歌单详情页(内容内返回/操作栏 + 头部 + 成员列表) |
| `lib/features/library/widgets/library_view_menu_button.dart` | 顶部「本地/排序/视图」二级菜单(MenuAnchor + SubmenuButton) |
| `lib/features/library/widgets/playlists_section.dart` | 歌单区(置顶收藏行 + 自建歌单列表) |
| `lib/features/library/widgets/playlist_card.dart` | 歌单卡片(封面 + 计数) |
| `lib/features/library/widgets/playlist_editor_dialog.dart` | 歌单创建/编辑对话框 |
| `lib/features/library/widgets/playlist_picker_sheet.dart` | 加入歌单底部选择器 |
| `lib/features/library/widgets/track_view.dart` | 共享曲目渲染(展柜网格 / 列表 / 瀑布流三态) |
| `lib/features/library/widgets/waterfall_track_card.dart` | 瀑布流曲目卡片 |
| `lib/features/library/widgets/track_list_items.dart` | 共享曲目行/卡片/来源徽标/封面 |
| `lib/features/library/widgets/track_actions_button.dart` | 轨道操作弹出菜单(收藏/缓存/存入曲库/加入歌单/移出歌单) |
| `lib/features/library/widgets/cache_action_button.dart` | 缓存按钮(未挂载) |
| `lib/data/services/track_deletion_service.dart` | `TrackDeletionService` — 删除曲目的缓存/歌单/曲库三步编排 |
| `lib/platform/audio_handler.dart` | audio_service + `audio_service_mpris` 后台播放与媒体控制 |
| `lib/platform/tray/tray_service.dart` | 系统托盘图标 + 关闭到托盘 |
| `lib/features/settings/settings_screen.dart` | 设置页(通用/播放/曲库/关于) |
| `lib/features/player/mini_player_bar.dart` | 迷你播放条(可嵌入移动端合并 dock) |
| `lib/features/player/player_screen.dart` | 全屏暗房播放页(封面环境色 + 横竖屏 + 传输控制) |
| `lib/features/player/player_progress_bar.dart` | 波浪/直线 morph 进度条 + 缓冲点阵动画 |
| `lib/features/player/mini_settings.dart` | 底部设置条(更多/调节/定时/音量/模式) + VolumeBar |
| `lib/features/player/lyrics_view.dart` | 歌词视图 `LyricsView` / `LyricsPreview`(provider 驱动, 同步高亮 + 双语, 无歌词占位) |
| `lib/features/player/player_panels.dart` | 面板系统 `showPlayerPanel` + 空/睡眠/队列面板 |
| `lib/features/player/play_mode_button.dart` | 播放模式四态循环按钮 |
| `lib/features/player/sleep_timer.dart` | 睡眠定时提供者(非 UI) |
| `lib/features/playlists/bilibili_favorites_screen.dart` | B 站公开收藏夹浏览(内容内页头 + 共享曲目行) |
| `lib/shared/responsive_center.dart` | 防溢出居中容器 |
| `lib/shared/cover_image.dart` | 封面图(按需解码, 本地/网络兜底) |