# 视觉深度与动效（B2 + M2）设计

- 日期：2026-10-08
- 状态：待评审
- 前置：`docs/spec-visual-foundation-2026-10-08.md`（基础层已落地并全绿）

## 1. 背景与目标

基础层已统一设计令牌、主题组件主题与共享组件（`SectionHeader` / `EmptyState`）。本轮按已选定的方向落地「层次」与「动效」：

- **B2 · 分层**：列表主体坐在浅色调面板上、播放行染色、迷你播放条改为悬浮胶囊、封面圆角再大一点。
- **M2 · 有主张的动效**：迷你播放条 → 全屏播放页用封面 Hero + 面板淡入，主题切换与播放行染色有平滑过渡。

不改功能逻辑与信息架构。

## 2. 范围

### 2.1 本轮做

1. 播放行染色的主题规则（底色 + 圆角）。
2. 主列表的浅色调面板容器（曲库列表、播放列表详情、收藏列表）。
3. 迷你播放条改为悬浮胶囊 + 柔和阴影。
4. 封面圆角映射微调（小封面 8 → 12）。
5. 动效令牌 + 应用：迷你条 → 播放页 Hero + 淡入、主题切换 300ms、播放行染色 250ms。

### 2.2 本轮不做

- 列表项错落入场、按下缩放、封面悬停（M3 级别动效）。
- 搜索页结果列表与网格/瀑布的列表面板（网格与瀑布本身已是卡片）。
- 字体与排版体系。

## 3. 设计

### 3.1 圆角映射

| 元素 | 令牌 | 变化 |
| --- | --- | --- |
| 列表行小封面 `TrackCover` | `AppRadius.md` (12) | 由基础层的 `sm`(8) 上调 |
| 列表面板容器 | `AppRadius.xl` (20) | 新增 |
| 播放行 | `AppRadius.md` (12) | 新增 |
| `CardThemeData` 形状 | `AppRadius.md` (12) | 由 `sm`(8) 上调 |
| 迷你播放条 | `AppRadius.xl` (20) | 新增 |
| 全屏播放页大封面 | `AppRadius.xl` (20) | 不变 |

### 3.2 播放行染色（主题级，不改各行）

- `ListTileThemeData.selectedTileColor = colorScheme.primary.withValues(alpha: 0.12)`。
- `ListTileThemeData.shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md))`。
- 说明：只有 `ListTile.selected == true` 的行显示底色（当前即「正在播放」行）；未选中行无可见影响。标题/图标沿用 `selectedColor`（默认主色）。

### 3.3 列表面板（新增共享容器）

新增 `lib/shared/list_panel.dart`：

```dart
class ListPanel extends StatelessWidget {
  const ListPanel({super.key, required this.child, this.padding});
  ...
}
```

- 外观：底色 `colorScheme.surfaceContainerLow`、圆角 `BorderRadius.circular(AppRadius.xl)`、内边距 `EdgeInsets.all(AppSpacing.xs)`、极浅阴影 `BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 3, offset: Offset(0, 1))`。
- 与现有关系：页面背景保持 `AppSurface.colorOf` = `surfaceContainerHigh`，面板取 `surfaceContainerLow`，与现有 `CardThemeData.color` 同一档 —— 沿用应用既有的「页面深、卡片浅」约定。
- 应用点：曲库列表容器的 `TrackView` 列表分支、播放列表详情列表、收藏列表。包裹 `ListView`，并保留上下留白。

### 3.4 迷你播放条悬浮胶囊

- `MiniPlayerBar` 外层由 `AppSurface`（全宽）改为带圆角的 `AppSurface(borderRadius: AppRadius.xl)` + 柔和阴影（`BoxShadow(black ~12%, blur 18, offset (0,6))`）。
- 外边距由 `HomeShell` 提供：紧凑模式在内容与 `NavigationBar` 之间留 `AppSpacing.sm`；宽屏模式在内容列底部留同样间距。
- 内部布局不变（封面 / 标题 / 播放键 / 下一首），进度条随圆角裁剪。

### 3.5 动效令牌

`lib/app/theme/app_tokens.dart` 新增：

```dart
@immutable
class AppMotion {
  const AppMotion._();
  static const Duration fast = Duration(milliseconds: 150);       // 按下反馈、染色
  static const Duration standard = Duration(milliseconds: 250);   // 多数状态切换
  static const Duration emphasized = Duration(milliseconds: 400); // 大过渡
  static const Curve standardCurve = Curves.easeInOutCubic;
  static const Curve emphasizedCurve = Curves.easeOutCubic;
}
```

### 3.6 迷你条 → 播放页（Hero + 淡入）

- 路由：`mini_player_bar.dart` 现有的 `MaterialPageRoute` 改为 `PageRouteBuilder`，过渡为淡入（`FadeTransition` + `AppMotion.emphasized`）。这是全屏播放页的唯一入口。
- Hero：迷你条封面与 `PlayerScreen` 大封面各包一层 `Hero`，`tag` 由 `track.uri` 派生（如 `'player-cover:${track.uri}'`）；配套 `flightShuttleBuilder` 保证封面在飞行中保持裁切圆形/圆角。
- 不需要新依赖。

### 3.7 主题切换过渡

`app.dart` 的 `MaterialApp` 设 `themeAnimationDuration: AppMotion.standard`（250ms）。`MaterialApp` 默认已用 `AnimatedTheme`，故主题色/明暗切换平滑过渡。

### 3.8 播放行染色过渡

播放行染色在 250ms（`AppMotion.standard`）内过渡。机制由实现计划确定（在行背景上用隐式动画 `AnimatedContainer` / `TweenAnimationBuilder`，避免每行手写控制器）。

## 4. 架构与影响

- **新增**：`lib/shared/list_panel.dart`；`app_tokens.dart` 增 `AppMotion`。
- **修改**：`lib/app/theme/app_theme.dart`（`selectedTileColor` / `listTileTheme.shape` / `cardTheme` 圆角）；`lib/app/app.dart`（`themeAnimationDuration`）；`lib/features/library/widgets/track_list_items.dart`（小封面圆角）；`lib/features/library/widgets/track_view.dart` 与 `playlist_detail_screen.dart`（列表面板）；`lib/features/player/mini_player_bar.dart`（悬浮胶囊 + 路由 + Hero）；`lib/features/player/player_screen.dart`（Hero 目标）。
- 无数据层改动，无新依赖。

## 5. 错误处理

纯展示层，无新增错误路径。Hero 仅在同一路由栈内工作；播放页被直接构建（无来源 Hero）时 `Hero` 会退化为普通渲染，不报错。

## 6. 测试策略

- **主题**：`selectedTileColor` 透明度与 `listTileTheme.shape` 圆角、`cardTheme` 圆角为 `AppRadius.md`；`AppMotion` 时长/曲线取值。
- **`ListPanel`**：渲染 child、底色与圆角来自主题。
- **Hero**：迷你条封面与 `PlayerScreen` 封面都存在 `Hero` 且 `tag` 一致；淡入路由可被构建。
- **封面圆角**：`TrackCover` 为 `AppRadius.md`（更新基础层的 8 断言）。
- **主题切换时长**：断言 `AppMotion.standard == 250ms`；`FlindApp` 的 `themeAnimationDuration` 接线沿用基础层做法（无 app 级测试，由组合覆盖）。
- **回归**：`flutter analyze` 干净 + 全量测试绿（当前 831）。

## 7. 验收标准

- `flutter analyze` 无问题；全量测试通过。
- 迷你条为悬浮圆角胶囊且带动画过渡到播放页；封面 Hero 从条上飞到大封面。
- 播放行有主色浅底与圆角，且在切换时平滑过渡。
- 主列表坐在浅色调圆角面板上。
- 主题切换肉眼可见为平滑淡变。

## 8. 风险与取舍

- 结构性改动（列表面板、Hero、路由）比基础层回归面更大；**真机/桌面目视核对是必需项**。
- 深浅色下「页面深、面板浅」沿用现有卡片约定；深色模式下与严格 M3 elevation 方向相反（与现状一致，非本轮引入）。
- 播放行染色的隐式动画若在某列表模式下（如网格）不适用，则仅列表模式生效。

## 9. 后续

M3 级别的列表入场/按下动效、字体与排版体系。
