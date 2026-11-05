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

> `main` 在 `runApp` 前还会：桌面端获取单实例锁（`SingleInstanceGuard`,第二个实例请求
> 唤醒已有窗口后退出）、初始化 `windowManager` 与 `AudioService`、恢复播放快照与语言。
>
> `FlindApp` 同时 watch `coverPrefetchCoordinatorProvider`,让队列封面预取
> 协调器在整个会话期间保持存活。
>
> **桌面端滑动**:Flutter 默认的 `MaterialScrollBehavior` 把 `PointerDeviceKind.mouse`
> 排除在 `dragDevices` 之外,所以桌面端的水平 `PageView`(如曲库 TabBarView)鼠标拖不动,
> 只能滚轮 / 触控板。`lib/app/app_scroll_behavior.dart` 的 `AppScrollBehavior` 把
> mouse / trackpad 等指针类型加回 `dragDevices`,在 `MaterialApp.scrollBehavior` 上全局生效;
> 触摸设备不受影响(不会产生这些指针事件)。对照实现见 `test/app_scroll_behavior_test.dart`
> (含「默认行为下鼠标拖拽无效」的反向断言)。

## 主壳 HomeShell(自适应布局)

`HomeShell` 现在只有三个目的地：**发现 / 曲库 / 我的**。设置不再是
一级入口，账号、最近播放、统计、外观、缓存与曲库管理都收进「我的」。
宽屏侧栏的标签常显；紧凑底栏仍只显示选中项标签。

```text
HomeShell
├─ destinations: 发现 / 曲库 / 我的
├─ LayoutBuilder
│  ├─ wide（≥600 且横屏）
│  │  └─ Scaffold → SafeArea → Column
│  │     ├─ Expanded → Row
│  │     │  ├─ _NarrowRail（品牌 + 3 个 _RailItem）
│  │     │  └─ Expanded → IndexedStack（3 页）
│  │     └─ DesktopNowPlayingBar
│  └─ compact（<600 或竖屏）
│     └─ Scaffold(extendBody: true)
│        ├─ IndexedStack（3 页）
│        └─ SafeArea → GlassSurface
│           └─ Column
│              ├─ MiniPlayerBar(embedded: true)
│              └─ NavigationBar（3 destinations）
└─ Navigator
   ├─ PlayerScreen
   ├─ CoverViewerScreen
   └─ 二级页
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

## 发现页 DiscoverScreen(搜索 + 推荐)

原 `SearchScreen` 改名为 `DiscoverScreen`，页头与导航标签都是「发现」。
页头、搜索框和源切换器固定在 `AppPageScaffold` 的 header 中，内容区
按是否提交关键词切换推荐流或搜索结果。

```text
DiscoverScreen
└─ AppPageScaffold(standard)
   ├─ AppPageHeader("发现")
   ├─ 搜索工具栏
   │  ├─ TextField
   │  └─ _SourceSwitcher<SourceId>（仅多于一个源时显示）
   └─ Expanded
      ├─ DiscoveryView（未提交关键词）
      │  └─ ListView
      │     ├─ _DiscoverySection("每日推荐") → _PosterTrackCarousel
      │     │   （海报卡：大方形封面 + 下方标题/艺术家）
      │     ├─ _DiscoverySection("最近播放") → _RecentTrackCarousel
      │     │   （紧凑行卡：小封面 + 标题/艺术家 + 播放图标）
      │     ├─ _DiscoverySection("推荐歌单") → _PlaylistPosterCarousel
      │     │   （封面海报：标题/曲目数叠加在封面渐变上）
      │     └─ _DiscoverySection("热门歌单") → _HotPlaylistCarousel
      │         （排行行卡：序号 + 小封面 + 标题/曲目数）
      └─ SearchResultsView
         └─ async.when → ListView.separated(TrackListRow)
```

发现页已移除「继续播放」；四类内容使用四种不同卡片轮廓，所有卡片共用
`_DiscoveryCardSurface` 的圆角、`surfaceContainerLow` 底色和发丝边框，
封面统一 `ClipRRect` 圆角。

## 曲库页 LibraryScreen(全部 / 收藏 / 歌单)

曲库页使用标准三段 `TabBar`，取代原来的三段轮盘。页头只保留排序
与视图两个可见操作；「来源」入口放进「歌单」页顶部的 2×2 卡片区，
不再使用把所有功能塞在一起的大菜单。

```text
LibraryScreen
└─ AppPageScaffold(wide)
   ├─ AppPageHeader(
   │    title: "曲库",
   │    actions: [LibrarySortMenuButton, LibraryViewMenuButton]
   │  )
   ├─ TabBar（全部 / 收藏 / 歌单）
   └─ Expanded
      └─ TabBarView
         ├─ AllPage
         │  └─ Column [LibrarySearchField, Expanded → TrackView]
         ├─ FavoritesPage
         │  └─ async.when → TrackView
         └─ PlaylistsPage
            └─ PlaylistsSection
               ├─ LibrarySources("来源")
               │  ├─ 离线缓存 → DownloadLibraryScreen
               │  ├─ B 站收藏夹 → BilibiliFavoritesScreen
               │  ├─ 网易云音乐 → NeteaseLibraryScreen
               │  └─ 本地曲库 → LocalBrowseScreen（iOS 隐藏）
               └─ 自建歌单列表（收藏已有独立 Tab，不再重复）
```

### 来源卡片 LibrarySources

四张卡片统一为 `SourceCard`：图标 + 标题 + 副标题 + chevron。离线缓存
卡片显示下载数量与占用；本地曲库显示本地曲目数。整卡可点，没有并列的
「管理」按钮；曲库扫描管理仍在「我的 > 曲库」。

## 离线缓存页 DownloadLibraryScreen(下载任务 + 已下载歌曲)

由「歌单 > 来源 > 离线缓存」进入，合并了原下载中心与设置页内联的已下载
歌曲列表。设置页只保留缓存位置、上限与清理缓存。

```text
DownloadLibraryScreen
└─ AppPageScaffold(wide)
   ├─ AppPageHeader("离线缓存", leading: IconButton(back), actions: [清空])
   ├─ _StorageSummary（数量 / 占用 / 进行中）
   ├─ _DownloadFilterBar（全部 / 进行中 / 已完成 / 失败）
   └─ Expanded
      └─ AppAsyncView
         └─ ListView
            ├─ _TaskTile（进行中 / 已完成 / 失败）
            └─ _DownloadedTrackRow（已下载歌曲 + 删除）
```

## 我的 MeScreen(账号 / 足迹 / 设置)

原 `SettingsScreen` 改为 `MeScreen`。账号与来源、最近播放/统计、外观与
语言、播放与缓存、曲库管理、关于都在这一页；不再有独立的设置一级入口，
也不在设置里内联下载列表。

```text
MeScreen
└─ AppPageScaffold(form)
   ├─ AppPageHeader("我的")
   └─ ListView
      ├─ SectionHeader("通用") → _GeneralSection
      ├─ SectionHeader("账号与来源") → AccountSection（AccountCard × 2）
      ├─ SectionHeader("我的足迹") → QuickLinks
      │  ├─ 最近播放 → RecentPlaysScreen
      │  └─ 播放统计 → PlaybackStatsScreen
      ├─ SectionHeader("播放") → _PlaybackSection（缓存位置 / 上限 / 清理）
      ├─ SectionHeader("曲库") → _LibrarySection（统计 / 扫描目录 / 导入）
      └─ SectionHeader("关于") → _AboutSection
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
   ├─ Expanded → Column (曲名 titleMedium w700 + 艺术家 bodyMedium w500
   │                        @ onSurface 0.78; 两行都带黑色柔光阴影以便压在
   │                        模糊封面上仍可读)
   └─ SizedBox(width: 48) (右侧配重, 保持标题居中)

_PortraitBody (竖屏正文)
└─ Column
   ├─ Expanded → _PortraitPager (横滑: 封面 ⇄ 歌词, 250ms, 跟随手指)
   │  ├─ _PortraitNormal (封面靠上 + 滚动歌词)
   │  │  └─ Column
   │  │     ├─ SizedBox(4) → LayoutBuilder → _PlayerCover
   │  │     │  (size = _portraitCoverEdge: 宽度 72%, 短窗先让位给歌词;
   │  │     │   size = min(w×0.72, h − 112 − 48).clamp(96, 420))
   │  │     ├─ SizedBox(16)
   │  │     └─ Expanded → LyricsPreview (滚动歌词窗 ≥ 112 高, 点击展开)
   │  └─ LyricsView (全屏歌词 — provider 驱动, 点击收起, 见下)
   ├─ _ProgressBar (进度条, 见下)
   ├─ _TransportControls (传输控制区, 见下)
   └─ SizedBox (歌词展开 24 / 折叠 16 — 与设置条分隔)

_LandscapeBody (横屏正文 — 左右等宽双栏, 无分隔线)
└─ Row
   ├─ Expanded → MiniMain (左栏: 迷你主视图)
   │  └─ Column
   │     ├─ Expanded → LayoutBuilder (edge = min(w, h);
   │     │   size = _coverSizeFor = (edge×0.65).clamp(min(80,edge), 480))
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
   ├─ Expanded → _barButton 更多 (more_vert → PlayerMorePanel)
   ├─ Expanded → _barButton 播放速度 (speed → PlaybackSpeedPanel)
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

PlayerMorePanel (更多面板 — 歌曲信息 + 真实操作)
└─ Column
   ├─ _PanelHeader (「更多」)
   └─ Expanded → ListView
      ├─ _SongInfo (标题 / 艺术家 · 专辑 / 来源)
      ├─ _ActionTile 收藏 / 取消收藏
      ├─ _ActionTile 离线缓存 / 已缓存 (非本地曲目)
      ├─ _ActionTile 加入歌单
      └─ _ActionTile 查看封面 → CoverViewerScreen

PlaybackSpeedPanel (播放速度面板)
└─ Column
   ├─ _PanelHeader (「播放速度」)
   └─ Expanded → ListView
      ├─ 速度百分比 + Slider (0.5×–2.0×)
      └─ 歌词偏移调节（±30s）

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
并由 `_LyricsScroll` 按真实几何自动居中,翻译以次级样式渲染在原文下方;无歌词或
源未适配时回落占位(「词莫见,敬聆听」)。`LyricsView` 与 `LyricsPreview` 共用
`_LyricsScroll`/`_LyricLineTile`,只有 `compact` 排版不同。

```
LyricsView (全屏歌词 ConsumerWidget, 点击回调 onTap 收起竖屏歌词页)
└─ GestureDetector (opaque)
   ├─ {无曲目/无歌词/空歌词} _LyricsPlaceholder (占位)
   │  └─ LayoutBuilder → SingleChildScrollView → ConstrainedBox(minHeight) → Center
   │     └─ Column [ Icon(lyrics_outlined) + Text(占位标题)
   │                 + Text(提示: lyricsLoginRequiredProvider 为真 → 「登录后可获取该视频的字幕」,
   │                        sourceSupportsLyricsProvider 为真 → 「暂无歌词」,
   │                        否则 → 「该音源暂未适配歌词」)
   │                 + {需要登录获取 B 站字幕} FilledButton.tonalIcon(
   │                     「登录 Bilibili 后获取字幕」→ showAccountLoginSheet) ]
   └─ {有歌词} _LyricsScroll
      └─ SingleChildScrollView → Column (全量布局, key: ValueKey(曲目 uri))
         └─ _LyricLineTile × Lyric.lines
            └─ Container {当前行} key: lyric-current (主色加粗)
               └─ Column [ Text(原文) + {有翻译} Text(次级样式翻译) ]
            → index 变化时 Scrollable.ensureVisible(alignment: 0.5, 250ms easeOut)
              (非 lazy, 未构建的行也能精确居中)

LyricsPreview (竖屏滚动歌词窗 — 竖屏封面临下填满剩余高度 ConsumerWidget)
└─ {无歌词} _LyricsPreviewPlaceholder (单行 Icon + 文案)
└─ {有歌词} LayoutBuilder (半视口 padding 让首尾行也能居中)
   └─ ShaderMask (上下 16% 淡出边缘)
      └─ _LyricsScroll(compact: true)
         → 当前行居中高亮, 相邻行 bodyMedium 变淡; 仅当前行显示翻译
```

## B 站收藏夹浏览页 BilibiliFavoritesScreen

由曲库页「来源 > B 站收藏夹」推入。内容内 `AppPageHeader` 提供返回/标题,
UID 输入条仅文件夹页显示;使用与其他页面一致的 1600px 页宽。

```
BilibiliFavoritesScreen (收藏夹浏览页 ConsumerStatefulWidget)
└─ AppPageScaffold(page 1600)
   └─ Column
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
  边缘。方形解码器按 **2× 显示边长**取样(上限 2048),避免 16:9 等非方形原图
  被 `BoxFit.cover` 放大后发虚。文件失效时自动回退到网络 URL。
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
- `AppPalette` 提供中性纯白/近黑 surface,主题色(seed)只驱动 accent、
  primary 与选中态,不再染遍全部 surface;浅色主题的抬升表面用很浅的中性
  灰阶,与白色页面拉开层次。
- `AppTypography` 统一字阶、行高、字重与数字等宽;`AppRadius` 收敛为
  `sm 8 / md 16 / lg 24 / pill` 四档。
- `AppIcons` 统一映射 Lucide Regular 线性图标;主播放/暂停是例外,使用
  实心 rounded glyph(Lucide 没有 Fill),激活收藏使用 600 字重。
- `AppSurface`(shared/app_surface.dart)统一页面底色为 `colorScheme.surface`。
- `AppBreakpoints` (app_theme.dart):
  - `compact` 断点 = **600** 逻辑像素宽;窗口更窄或竖屏(`height >= width`)
    一律按紧凑布局处理,桌面端拉窄窗口也会切换为手机式底部导航。
  - 宽屏自绘 `_NarrowRail` 的标签**常显**;紧凑 `NavigationBar` 仍只显示选中项
    标签。侧栏保留圆形选中/悬停底,但点击不画圆角矩形水波纹。
- `AppPageScaffold` 的页宽统一为 **1600** 逻辑像素,页面内部再用
  `ConstrainedBox` 限制搜索框/表单等阅读宽度;不再由各页分别选择
  760/960/1120。`MeScreen` 在 ≥1100px 时使用两栏设置布局。

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
| `lib/features/home/home_shell.dart` | `HomeShell` 自适应导航壳(发现/曲库/我的; 窄 rail / 合并 dock) |
| `lib/features/player/desktop_player_bar.dart` | 宽屏全宽底部播放条 |
| `lib/shared/app_page_header.dart` | 共用大标题页头 |
| `lib/shared/app_page_scaffold.dart` | 共用页面骨架(页头 + 限宽内容 + SafeArea) |
| `lib/shared/app_async_view.dart` | 共用加载/错误/空态渲染 |
| `lib/shared/app_surface.dart` | 统一页面底色 + `colorOf` |
| `lib/features/discover/discover_screen.dart` | 发现页(搜索 + 每日推荐/最近播放/歌单) |
| `lib/features/library/library_screen.dart` | 曲库页(页头/三段 Tab/搜索/收藏/歌单/来源) |
| `lib/core/models/library_view.dart` | 视图模型:`LibraryView`(卡片/列表) + `LibraryViewScope`(按段作用域) |
| `lib/features/library/library_view_provider.dart` | `LibraryViewsNotifier` — 按段持久化的多视图(存设置仓) |
| `lib/features/library/library_sort_provider.dart` | 曲库排序(标题/艺术家/专辑/最近添加) |
| `lib/features/library/track_sorting.dart` | 排序比较器与本地化键 |
| `lib/features/library/cover_aspect_ratio_provider.dart` | 封面宽高比设置(卡片视图用) |
| `lib/features/library/playlist_detail_screen.dart` | 歌单详情页(内容内返回/操作栏 + 头部 + 成员列表) |
| `lib/features/library/widgets/library_view_menu_button.dart` | 曲库页头视图切换菜单 |
| `lib/features/library/widgets/library_sort_menu_button.dart` | 曲库页头排序菜单 |
| `lib/features/library/widgets/library_sources.dart` | 歌单页顶部来源卡片(离线缓存 / B站 / 网易云 / 本地) |
| `lib/features/library/widgets/playlists_section.dart` | 歌单区(仅自建歌单; 收藏已独立 Tab) |
| `lib/features/library/widgets/playlist_card.dart` | 歌单卡片(封面 + 覆盖文字) |
| `lib/features/library/widgets/library_card_shell.dart` | 曲库卡片底板(悬停/播放态) + 播放徽标 + 封面占位 |
| `lib/features/library/widgets/playlist_editor_dialog.dart` | 歌单创建/编辑对话框 |
| `lib/features/library/widgets/playlist_picker_sheet.dart` | 加入歌单底部选择器 |
| `lib/features/library/widgets/track_view.dart` | 共享曲目渲染(卡片 / 列表二态) |
| `lib/features/library/widgets/waterfall_track_card.dart` | 卡片视图的曲目卡片 |
| `lib/features/library/widgets/track_list_items.dart` | 共享曲目行/来源徽标/封面 |
| `lib/features/library/widgets/track_actions_button.dart` | 轨道操作弹出菜单(收藏/缓存/存入曲库/加入歌单/移出歌单) |
| `lib/features/library/widgets/cache_action_button.dart` | 缓存按钮(未挂载) |
| `lib/data/services/track_deletion_service.dart` | `TrackDeletionService` — 删除曲目的缓存/歌单/曲库三步编排 |
| `lib/platform/audio_handler.dart` | audio_service + `audio_service_mpris` 后台播放与媒体控制 |
| `lib/platform/tray/tray_service.dart` | 系统托盘图标 + 关闭到托盘 |
| `lib/features/me/me_screen.dart` | 我的(账号与来源/最近播放/统计/外观/播放缓存/曲库/关于) |
| `lib/features/downloads/download_library_screen.dart` | 离线缓存页(下载任务 + 已下载歌曲 + 存储摘要) |
| `lib/features/settings/account_section.dart` | 账号与来源列表 + 扫码登录/退出 Sheet |
| `lib/core/auth/` | `AuthSession` / `AuthDriver` / `AuthState` / `AuthSourcePolicy` |
| `lib/data/auth/` | `SecureAuthSessionStore` / `AuthCookieJar` / `Set-Cookie` 解析 |
| `lib/data/sources/bilibili/bili_auth_driver.dart` | Bilibili QR 登录 |
| `lib/data/sources/netease/netease_auth_driver.dart` | 网易云 QR 登录 |
| `lib/platform/single_instance/single_instance_guard.dart` | 桌面单实例文件锁 + 唤醒请求 |
| `lib/shared/platform_support.dart` | 本地曲库平台能力(iOS/Web 不支持) |
| `lib/features/player/mini_player_bar.dart` | 迷你播放条(可嵌入移动端合并 dock) |
| `lib/features/player/player_screen.dart` | 全屏暗房播放页(封面环境色 + 横竖屏 + 传输控制) |
| `lib/features/player/player_progress_bar.dart` | 波浪/直线 morph 进度条 + 缓冲点阵动画 |
| `lib/features/player/mini_settings.dart` | 底部设置条(更多/播放速度/定时/音量/模式) + VolumeBar |
| `lib/features/player/lyrics_view.dart` | 歌词视图 `LyricsView` / `LyricsPreview`(provider 驱动, 同步高亮 + 双语, 无歌词占位) |
| `lib/features/player/player_panels.dart` | 面板系统 `showPlayerPanel` + 更多/播放速度/睡眠/队列面板 |
| `lib/features/player/play_mode_button.dart` | 播放模式四态循环按钮 |
| `lib/features/player/sleep_timer.dart` | 睡眠定时提供者(非 UI) |
| `lib/features/playlists/bilibili_favorites_screen.dart` | B 站公开收藏夹浏览(内容内页头 + 共享曲目行) |
| `lib/shared/responsive_center.dart` | 防溢出居中容器 |
| `lib/shared/cover_image.dart` | 封面图(按需解码, 本地/网络兜底) |