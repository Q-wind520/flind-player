# 应用内磨砂玻璃：底部导航栏与迷你条 设计

- 日期：2026-10-09
- 状态：待评审
- 前置：`docs/spec-visual-foundation-2026-10-08.md`、`docs/spec-visual-depth-motion-2026-10-08.md`（基础层与 B2/M2 已落地）

## 1. 背景与目标

导航 chrome 与迷你播放条目前是不透明的实色底。本轮为**底部导航栏**与**迷你播放条**加上“应用内磨砂玻璃”质感：半透明 + 背景模糊，让下方列表隐约透出，做出通透、有层次的观感。

- **只在应用内做玻璃**：模糊的是应用自身绘制的内容（列表 / 封面），不是桌面或窗口之后的画面。
- **零新依赖**：使用 Flutter 自带 `BackdropFilter` + `ImageFilter.blur` + `ColorScheme`。
- **底部 chrome 共用一层玻璃**：迷你条与底部导航栏之间不再有“露出未模糊内容”的间隙，两者落在同一块连续的玻璃上。
- **不做**：播放器本体、宽屏左侧 `NavigationRail`、窗口级透明/亚克力、iOS Liquid Glass。

## 2. 范围

### 2.1 本轮做

1. 新增共享控件 `GlassSurface`（模糊 + 半透明 tint + 高光边 + 阴影 + 圆角裁剪）。
2. 新增玻璃令牌 `AppGlass`（模糊强度、tint 透明度、顶边高光）。
3. `MiniPlayerBar` 改为**纯内容条**（去掉自带的玻璃/阴影/外边距）。
4. 紧凑布局下，迷你条与底部导航栏**共用一层** `GlassSurface`。
5. 底部 `NavigationBar` 玻璃化（主题背景透明）。
6. 覆盖几何：紧凑布局用 `Scaffold.extendBody`；宽屏布局用覆盖式迷你条 + 内容底部内边距。

### 2.2 本轮不做

- 播放器本体、宽屏 `NavigationRail` 的改动。
- 窗口级透明/模糊桌面（`flutter_acrylic` 等）、iOS Liquid Glass。
- 玻璃强度的用户开关（先固定值，后续如需再加）。
- 除底部导航栏与迷你条外的其它控件。

## 3. 设计

### 3.1 共享控件 `GlassSurface`

新增 `lib/shared/glass_surface.dart`：

```dart
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius,
    this.blurSigma = AppGlass.blurSigma,
    this.border,
    this.boxShadow,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final double blurSigma;
  final Border? border;
  final List<BoxShadow>? boxShadow;
}
```

渲染结构（自外向内）：

```
DecoratedBox(position: background, decoration: BoxDecoration(borderRadius, boxShadow))
  └ ClipRRect(borderRadius)
      └ BackdropFilter(ImageFilter.blur(σ: blurSigma, σ: blurSigma))
          └ DecoratedBox(position: background, decoration: BoxDecoration(color: AppGlass.tintOn(scheme)))
              └ DecoratedBox(position: foreground, decoration: BoxDecoration(border, borderRadius))
                  └ child
```

- tint 由 `AppGlass.tintOn(Theme.of(context).colorScheme)` 在内部取，不作为参数暴露。
- 模糊经 `ClipRRect` 裁到控件范围内，不外溢。
- `borderRadius` 为 `null` 时不做圆角裁剪（`Clip.none`），行为与现在的 `AppSurface` 一致。
- 与 `AppSurface` 的关系：`AppSurface` 继续服务**实色**表面；`GlassSurface` 是**玻璃**表面的兄弟控件。两者都留在 `shared/`，作为“换材质”的接缝。

### 3.2 玻璃令牌 `AppGlass`（`lib/app/theme/app_tokens.dart`）

（需在 `app_tokens.dart` 增加 `import 'package:flutter/painting.dart';` 以使用 `BoxShadow`。）

```dart
@immutable
class AppGlass {
  const AppGlass._();

  /// 背景模糊强度（高斯 σ）。
  static const double blurSigma = 14;

  /// 玻璃上的半透明底：浅色更实、深色更透，兼顾文字对比度。
  static Color tintOn(ColorScheme scheme) => scheme.surface.withValues(
    alpha: scheme.brightness == Brightness.light ? 0.72 : 0.62,
  );

  /// 玻璃顶部 1px 高光边。
  static Border topEdgeOn(ColorScheme scheme) => Border(
    top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
  );

  /// 玻璃板与悬浮胶囊共用的柔和阴影。
  static const List<BoxShadow> shadow = [
    BoxShadow(
      color: Color(0x1F000000), // 约 12% 黑
      blurRadius: 18,
      offset: Offset(0, 6),
    ),
  ];
}
```

### 3.3 迷你播放条改为纯内容条

`MiniPlayerBar` 去掉自带的玻璃、阴影与外边距（`Padding`/`DecoratedBox`/`AppSurface`），只保留内容：

- 顶部进度线（有播放时）+ `InkWell`（保留 `barKey`）+ 内部内边距 + 封面/标题/艺人/控件。
- 背景与阴影由 shell 提供（见 3.4 / 3.5），因此它在紧凑布局下与导航栏共用同一层玻璃、之间没有缝隙。

> 说明：这会把此前“独立悬浮胶囊”的迷你条合并进底部玻璃板；宽屏布局下没有导航栏相伴，迷你条仍是一个独立的悬浮玻璃胶囊（见 3.5）。若你更想两者都保持独立胶囊，请指出。

### 3.4 紧凑布局：底部 chrome 共用一层玻璃

- 主题（`app_theme.dart`）新增 `navigationBarTheme.backgroundColor = Colors.transparent`，让 `NavigationBar` 自身不再铺实色底。
- Shell 把 `[MiniPlayerBar, NavigationBar]` 一起放进**一个** `GlassSurface`：
  - 圆角：上方两角 `AppRadius.xl`（整屏宽，下方方形）；
  - 顶边：`AppGlass.topEdgeOn`（作为玻璃板的顶沿高光）；
  - 阴影：把原迷你条的柔和阴影移到这块玻璃板上。
- 于是迷你条与导航栏之间不再有“露出未模糊内容”的缝隙，整块底栏是一层连续玻璃，模糊其背后延伸过来的列表。

### 3.5 覆盖几何

**紧凑布局**（宽度 < 600 或 竖屏比例）：

```dart
Scaffold(
  extendBody: true,
  body: IndexedStack(index: _selectedIndex, children: _screens),
  bottomNavigationBar: GlassSurface(
    borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    border: AppGlass.topEdgeOn(scheme),
    boxShadow: AppGlass.shadow,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MiniPlayerBar(),          // 纯内容条
        NavigationBar(...),       // 背景透明
      ],
    ),
  ),
)
```

- `extendBody: true` 使 `body`（列表）延伸到 `bottomNavigationBar` 之后；框架把 body 的 `MediaQuery.padding.bottom` 设为底栏高度，`ListView` 自动据此留白 → 最后一行仍能滚到玻璃之上。
- 玻璃在底栏内，模糊其后延伸过来的列表。

**宽屏布局**（宽度 ≥ 600 且 横屏比例）：

- `NavigationRail` 与整体 `Row` 保持；迷你条作为**独立的悬浮玻璃胶囊**覆盖在内容列底部：

```dart
Expanded(
  child: Stack(
    children: [
      Positioned.fill(
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: MediaQuery.of(context).padding.copyWith(
              bottom: MediaQuery.of(context).padding.bottom + _miniPlayerHeight,
            ),
          ),
          child: IndexedStack(index: _selectedIndex, children: _screens),
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.sm,
          ),
          child: GlassSurface(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: AppGlass.shadow,
            child: MiniPlayerBar(),
          ),
        ),
      ),
    ],
  ),
),
```

- `_miniPlayerHeight` 用 `GlobalKey` 在首帧后测量（`MiniPlayerBar` 无播放时为 0，不预留）。内容底部内边距据此预留，避免最后一行被困在玻璃之下。

### 3.6 状态与依赖

- 无数据层改动，无新依赖，无信息架构变化。
- 仅表现层：`home_shell.dart`、`mini_player_bar.dart`、`app_theme.dart`、`app_tokens.dart`，新增 `glass_surface.dart`。
- 阴影令牌：`AppGlass.shadow`（玻璃板与悬浮胶囊共用），沿用现有柔和阴影量级。

## 4. 错误处理

纯展示层，无新增错误路径。`BackdropFilter` 在所有目标平台都可用。

## 5. 测试策略

- **`GlassSurface`**：渲染出 `BackdropFilter` 且 `filter` 为 `ImageFilter.blur`；tint 颜色透明度在 (0,1) 之间；给定 `borderRadius` 时存在对应的 `ClipRRect` 裁剪；`child` 正常渲染。
- **令牌**：`AppGlass.blurSigma`、`tintOn` 深浅色 alpha、`topEdgeOn` 取值。
- **主题**：`navigationBarTheme.backgroundColor == Colors.transparent`。
- **紧凑布局**：`Scaffold.extendBody == true`；迷你条与导航栏处在**同一个** `GlassSurface` 之内（两者都是该玻璃板的子孙），其间无其它背景层。
- **宽屏布局**：迷你条与内容重叠（覆盖式）；迷你条外层是 `GlassSurface` 胶囊；内容被赋予新的底部 `MediaQuery.padding.bottom`。
- **迷你条**：`MiniPlayerBar` 自身不再含 `GlassSurface`（纯内容）；紧凑下由 shell 的玻璃板提供背景。
- **回归**：`flutter analyze` 干净 + 全量测试绿（当前 850）。

## 6. 验收标准

- `flutter analyze` 无问题；全量测试通过。
- 紧凑布局下，迷你条与底部导航栏落在同一块连续玻璃上、之间无缝隙；列表从这块玻璃下方穿过，透过玻璃隐约可见；最后一行可滚到玻璃之上。
- 宽屏布局下，迷你条是悬浮玻璃胶囊并覆盖在列表底部，内容不因迷你条而无法触达。
- 底部导航栏与迷你条看起来是通透的玻璃（半透明 + 模糊 + 顶边高光），深浅色下文字均清晰可读。
- 播放器本体与宽屏导航栏外观不变。

## 7. 风险与取舍

- **图层顺序**：`BottomNavigationBar` 槽内的 `BackdropFilter` 需能模糊 `extendBody` 延伸过来的 body；实现时用一个测试/目视先确认（若平台表现不一致，退路是把玻璃板移入 body 的 `Stack` 覆盖层，自行处理安全区）。
- **性能**：`BackdropFilter` 较费，尤其 Android；σ 先取 14，模糊面积用 `ClipRRect` 限制在条内；暂不做开关。
- **迷你条身份变化**：紧凑布局下迷你条从“独立悬浮胶囊”变为底部玻璃板的一部分；若更想保留独立胶囊，需要另定方案。
- **宽屏测量**：首帧 `_miniPlayerHeight` 为 0，测量后 `setState` 再补内边距（多一帧），可接受。

## 8. 后续

- 玻璃强度/开关（低端机降级）。
- 播放器本体、宽屏导航栏的玻璃化。
- 若将来要窗口级亚克力或 Liquid Glass，只需替换 `GlassSurface` 的内部实现（`AppSurface`/`GlassSurface` 仍是唯一接缝）。
