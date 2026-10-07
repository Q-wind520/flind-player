# 视觉基础层设计（Visual Foundation）

- 日期：2026-10-08
- 状态：待评审
- 背景材料：`docs/archive/UI-REVIEW-2026-09-12.md`（部分问题已随重构消失，逐条核实后见 §3.4）

## 1. 背景与目标

Flind Player 已经是一个完整、可用的 Material 3 实现，但视觉细节缺少统一的「合同」：

- 圆角散布着 4 / 8 / 12 / 24 四种取值，同一角色不统一；
- 分区小标题用 `colorScheme.primary`，浅色模式对比度 2.69:1，不满足 WCAG AA；
- 空状态、分区标题、来源标签等在多个界面各写各的。

本设计建立一层**设计令牌 + 主题级组件主题 + 共享组件**，把这些决策收到少数几个文件里，为后续逐界面精修（B 方向：更大圆角、色调分层、极浅阴影）打底。

**本轮不改功能与信息架构。**

## 2. 范围

### 2.1 本轮做

1. 设计令牌（间距、圆角）。
2. `AppTheme` 的组件主题收口。
3. 共享组件：`SectionHeader`、`EmptyState`、封面圆角统一。
4. §3.4 列出的已知问题修复。
5. 相应的测试与全量回归。

### 2.2 本轮不做（留到后续轮次）

- 具体「哪个元素用哪档圆角 / 阴影 / 色调分层」的映射，悬浮迷你条、播放行染色。
- 动效时长与曲线（连同其应用）。
- 字体与排版体系。

## 3. 设计

### 3.1 设计令牌 `lib/app/theme/app_tokens.dart`

| 令牌 | 取值 |
| --- | --- |
| `AppSpacing` | `xs 4` / `sm 8` / `md 12` / `lg 16` / `xl 24` / `xxl 32` |
| `AppRadius` | `sm 8` / `md 12` / `lg 16` / `xl 20` / `pill 999` |

- 半径梯度从 8 起（按 B 的偏好）。间距保留 `4` 一档，供图标与文字间隙等紧凑场景。
- 动效常量（时长/曲线）本轮不定义，避免落下无人使用的取值。
- 本轮令牌的消费方是主题组件主题与共享组件；**逐屏的间距替换不在本轮**（属后续按界面精修）。

### 3.2 主题级组件主题

`AppTheme._build(Brightness, Color)` 新增以下组件主题（`snackBarTheme` 保留）：

- `cardTheme`：elevation `0`、圆角 `AppRadius.sm`、底色 `surfaceContainerLow`。
  - 作为「扁平」基线；B 的柔和阴影留到下一轮按组件映射。
- `dividerTheme`：`colorScheme.outlineVariant`、`thickness 1`、`space 1`。
- `listTileTheme`：水平内边距 `AppSpacing.lg`（与 Material 默认一致，仅显式化）。
- `navigationBarTheme` / `navigationRailTheme`：指示器圆角 `AppRadius.pill`、选中/未选中标签字重。
- `inputDecorationTheme`：`OutlineInputBorder`，圆角 `AppRadius.md`。（搜索框、颜色十六进制输入、缓存上限对话框共用。）
- `progressIndicatorTheme`：`linearTrackColor = colorScheme.outlineVariant`，`linearMinHeight 2`。
- `snackBarTheme`：保持现状。

把这些集中到 `AppTheme` 后，后续 B 的精修只需改主题，不必逐屏改。

### 3.3 共享组件

**`lib/shared/section_header.dart`**

```dart
SectionHeader(String title, {Widget? trailing})
```

- 样式：`textTheme.titleSmall` + `colorScheme.onSurfaceVariant`（修对比度）。
- 内边距：`EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm)`。
- 替代设置页的 `_SectionHeader` 与 `_ScanRootHeader` 的标题部分（后者带 trailing 加号按钮）。

**`lib/shared/empty_state.dart`**

```dart
EmptyState({required IconData icon, required String title, String? message, Widget? action})
```

- 居中列：图标 64 / `onSurfaceVariant`、标题 `titleMedium`、说明 `bodyMedium` + `onSurfaceVariant`、可选操作按钮。
- 首先替代 `player_screen.dart` 的 `_NothingPlaying`、`search_screen.dart` 的 `_SearchHint`、曲库/搜索的空结果态。

**封面圆角**

- 小封面（列表行、网格卡片、迷你播放条、搜索结果）统一为 `AppRadius.sm`。
- 全屏播放器大封面为 `AppRadius.xl`（原 24）。
- 按比例计算的歌单封面（`size * 0.16`）保持不动。

### 3.4 已知问题修复

| # | 问题 | 现状 | 修复 |
| --- | --- | --- | --- |
| 1 | 分区标题浅色对比度 2.69:1 | `titleSmall` + `primary` | 改走 `SectionHeader`（`onSurfaceVariant`） |
| 2 | 封面圆角 4 / 8 / 24 混用 | `track_list_items` `waterfall_track_card` 用 4，`player_screen` 用 24 | 统一到 `AppRadius`（见 §3.3） |
| 3 | 来源标签字号偏小 | `SourceBadge` 用 `labelSmall` | 提到 `labelMedium`，并在当前种子色下核对对比度 ≥4.5:1 |
| 4 | 播放器硬编码收藏色 | `Colors.red` | 改 `colorScheme.error`；并核对非激活操作图标（收藏/队列）与传输键的层级（现为 `onSurfaceVariant` vs `onSurface`，已达标则不改） |
| 5 | 迷你播放条 0 进度轨道几乎不可见 | 硬编码 `backgroundColor: surfaceContainerHighest` | 去掉硬编码，轨道色由 `progressIndicatorTheme.linearTrackColor` 提供 |

> 说明：9 月评审中「设置页 0 B 进度条不可见」已随缓存行重构消失（现为文本用量），不修。

## 4. 架构与影响

- **新增**：`lib/app/theme/app_tokens.dart`、`lib/shared/section_header.dart`、`lib/shared/empty_state.dart`。
- **修改**：`lib/app/theme/app_theme.dart`（组件主题）；`settings_screen.dart`、`search_screen.dart`、`library_screen.dart`、`mini_player_bar.dart`、`player_screen.dart`、`track_list_items.dart`、`waterfall_track_card.dart` 等（替换分区标题、空态与封面圆角）。
- **无数据层改动，无新依赖。** 纯展示层。

## 5. 错误处理

纯展示层，无新增错误路径。`EmptyState` 的 `message` / `action` 可选，缺省时只渲染图标与标题。

## 6. 测试策略

- **主题**：断言组件主题确实生效，且随种子色/明暗变化（`cardTheme` 形状、`inputDecorationTheme` 圆角、`progressIndicatorTheme.linearTrackColor == colorScheme.outlineVariant`）。
- **`SectionHeader`**：渲染标题、文字色为 `onSurfaceVariant`、支持 `trailing`。
- **`EmptyState`**：图标 / 标题 / 说明 / 操作按需渲染。
- **修复项**：`SourceBadge` 字号、封面圆角、迷你条轨道色、收藏色。
- **回归**：`flutter analyze` 无问题 + 全量测试绿（当前基线 817）。

## 7. 验收标准

- `flutter analyze` 无问题；全量测试通过。
- 浅色模式分区标题对比度 ≥ 4.5:1。
- 同一角色的封面圆角一致。
- 迷你播放条在 0 进度时轨道可见。
- 主题组件主题生效（由测试覆盖）。

## 8. 风险与取舍

- 主题级组件主题与半径放大都会带来**可见变化**（输入框圆角 4→12、卡片去阴影），需在真机/桌面目视确认。
- 令牌本轮只在新消费点使用，尚未全量铺开；逐屏替换放到后续轮次，避免一次性大范围改动引发回归。

## 9. 后续

B 细节（圆角 / 阴影 / 色调分层的逐组件映射）、动效、字体与排版体系。
