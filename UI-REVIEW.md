# Flind Player — UI 审查报告

> 生成于 2026-09-12 · 证据：12 张真实渲染截图（`.omo/evidence/ui-review/`）
> 方法：Flutter 真实 widget 树渲染 + 独立只读交叉审查（设计系统 / 视觉排版两路）

> 截图文件位于本地 `.omo/evidence/ui-review/`，该目录已被 gitignore，**不随仓库发布**；
> 下文以文件名引用它们，未做图片内嵌。

---

## 修复状态（2026-09-12 更新）

| 问题 | 状态 |
| --- | --- |
| P0 死按钮（扫描根目录） | ✅ 已修（接上 `_addFolder`，新增测试覆盖） |
| P0 进度条拖动不跟手 | ✅ 已修（本地拖拽状态 + 松手才 seek，新增测试覆盖） |
| P1 导航标签错配（首页→搜索、账户→设置） | ✅ 已修（标签与图标同步更新，测试已更新） |
| P1 停靠面板与迷你播放器重复 | ✅ 已修（面板展开时隐藏迷你播放器） |
| P1 设置页对齐混用 | ✅ 已修（两个 Column 加 `crossAxisAlignment`，截图已确认左对齐） |
| P1 `Colors.grey` 硬编码 | ✅ 已修（改用 `colorScheme.onSurfaceVariant`） |
| P2 桌面曲库仅网格 / 圆角 token / 死代码 | ⏳ 未修（待定，部分需产品决策） |
| **浅色模式分区标题对比度 2.69:1（AA 不达标）** | ⏳ **未修（Pass B 新发现）** |
| **浅色模式「用量」0 B 进度条几乎不可见（1.1:1）** | ⏳ **未修（Pass B 新发现）** |
| 深色模式来源标签对比度 3.2:1（小字号） | ⏳ 未修（Pass B，轻微） |
| 非激活传输图标与激活图标视觉权重无差异 | ⏳ 未修（Pass B，轻微） |

> 修复后已重新采集全部 12 张截图并**逐张目视确认**（导航标签、设置页对齐、面板去重均生效）。
> 采集脚本 `test/ui_capture_test.dart` 为临时工具，已删除（golden 图位于 gitignore 的 `.omo/`，留在仓库会让 CI 失败）。

---

## 结论速览

| 优先级 | 问题 | 位置 |
| --- | --- | --- |
| **P0** | 设置页「扫描根目录」的添加按钮是**空回调**，可点但无反应 | `settings_screen.dart:437` |
| **P0** | 播放器进度条**拖动不跟手**，只有松手才跳转 | `player_screen.dart:170` |
| **P1** | 导航标签与内容错配（首页→搜索、账户→设置） | `home_shell.dart:80-92` |
| **P1** | 停靠播放面板与迷你播放器重复显示 | `player-panel-dark.png` |
| **P1** | 设置页对齐方式混用 + `Colors.grey` 绕过主题 | `settings_screen.dart:89/226/256` |
| **P1** | 「存入曲库」两处交互不一致；收藏夹行缺收藏/缓存 | `bilibili_favorites_screen.dart:523` |
| **P2** | 桌面曲库仅网格、无列表开关 | `library_screen.dart:390` |
| **P2** | 封面圆角无统一 token（4 / 8 / 24 / 28 四种） | 多处 |
| **P2** | 死代码：重复分支、重复 provider、`DraggableScrollableSheet` 死参数 | 多处 |

**整体评价**：这是一个**真实的、活的 Material 3 实现**，不是花架子——主题确实由 seed 派生、
所有功能路径都落到真实实现（JustAudio / drift / DownloadManager，无桩），
空状态/错误态/加载态齐全，400px 与 1280px 都不溢出。

---

## 一、P0：功能缺陷

### 1. 「扫描根目录」的添加按钮点了没反应

```dart
// lib/features/settings/settings_screen.dart:434
IconButton(
  icon: const Icon(Icons.create_new_folder_outlined),
  tooltip: '添加文件夹',
  onPressed: isSyncing ? null : () {},   // ← 空回调
),
```

按钮**可点、有涟漪、有 tooltip**，但什么都不做。而且它正下方就有一个**能正常工作**的
「添加文件夹」列表项（`:282`），两个入口一个真一个假。**已亲自核实源码。**

证据：`settings-desktop-dark.png` / `settings-desktop-light.png` 右上角图标。

**修法**：接上 `_addFolder`，或直接删掉这个按钮（下方列表项已够用）。

---

### 2. 播放器进度条拖动不跟手

```dart
// lib/features/player/player_screen.dart:167
Slider(
  value: positionValue,
  max: maxValue,
  onChanged: enabled ? (_) {} : null,     // ← 空实现
  onChangeEnd: enabled ? (value) => ...seek(...) : null,
),
```

`value` 由播放状态驱动，`onChanged` 又不更新任何状态，所以**拖动过程中滑块会弹回原位**，
只有松手瞬间才跳转。观感像坏了。**已亲自核实源码。**

**修法**：改成 `StatefulWidget`，`onChanged` 更新本地拖拽值、`onChangeEnd` 再 seek 并清空本地值。

---

## 二、P1：用户可见的一致性问题

### 3. 导航标签与实际内容错配（两处）

```dart
// lib/features/home/home_shell.dart:80-92
NavigationRailDestination(icon: Icon(Icons.home_outlined),          label: Text('首页')),
NavigationRailDestination(icon: Icon(Icons.library_music_outlined), label: Text('曲库')),
NavigationRailDestination(icon: Icon(Icons.account_circle_outlined),label: Text('账户')),
```

而 `_screens = [SearchScreen(), LibraryScreen(), SettingsScreen()]`：

| 标签 | 图标 | 实际页面 | 页面自己的标题 |
| --- | --- | --- | --- |
| 首页 | home | `SearchScreen` | **搜索** ❌ |
| 曲库 | library_music | `LibraryScreen` | 音乐库 ✓ |
| 账户 | account_circle | `SettingsScreen` | **设置** ❌ |

**两处错配**（我只发现了第一处，第二处由独立审查补出，已亲自核实源码）。

证据：`search-results-dark.png`（高亮「首页」而标题是「搜索」）、
两张 settings 图（高亮「账户」而标题是「设置」）。

**修法**：标签改为「搜索」「曲库」「设置」，图标同步换成 `Icons.search` / `Icons.settings_outlined`。

---

### 4. 停靠播放面板与迷你播放器重复

`player-panel-dark.png`：右侧停靠面板已展开（封面、曲名、进度条、完整传输控制），
但**底部迷你播放器仍在显示同一首歌与播放/下一首**，控制双重重复。

源码依据：`home_shell.dart:142-146` 无条件渲染 `MiniPlayerBar`，面板作为 trailing 兄弟节点。

**修法**：`_playerPanelOpen && wideEnoughForPanel` 时隐藏迷你播放器。

---

### 5. 设置页对齐混用（根因已定位）

同一屏内三种对齐：标签左对齐、「缓存上限」下的容量 chip 组**整行居中**、
「未配置扫描根目录」**居中**、「清空缓存」又被显式左对齐、「用量」数值右对齐。

**根因**：`_PlaybackSection` 的 Column（`:89`）与 `_LibrarySectionState` 的 Column（`:226`）
**没有设置 `crossAxisAlignment`**，而 Column 的默认值是 **center**。
于是固有宽度的子元素（chip 的 `Wrap`、单行空文本）被居中，
而 `ListTile` 自身撑满宽度、`清空缓存` 外层包了 `Align(centerLeft)`，所以那两处靠左。

```dart
// lib/features/settings/settings_screen.dart:256
child: Text('未配置扫描根目录', style: TextStyle(color: Colors.grey)),
//                                                  ↑ 绕过主题，应使用 onSurfaceVariant
```

证据：`settings-desktop-dark.png`、`settings-desktop-light.png`（两个主题表现一致）。

**修法**：两个 Column 加 `crossAxisAlignment: CrossAxisAlignment.stretch`（或 `start`），
去掉 `清空缓存` 的 `Align`；`Colors.grey` 换成 `colorScheme.onSurfaceVariant`。

---

### 6. 「存入曲库」两处交互不一致

| 位置 | 实现 | 交互 |
| --- | --- | --- |
| B站收藏夹行 | `bilibili_favorites_screen.dart:523` 直接 `IconButton(Icons.library_add_outlined)` | 一键 |
| 搜索结果行 | `search_screen.dart:224` → `TrackActionsButton(showSaveToLibrary: true)` | 藏在 ⋮ 菜单 |

更值得注意的是：**收藏夹行只有这一个动作**——同一批 B 站曲目，在搜索页有「收藏 / 缓存 / 存入曲库」，
在收藏夹页却**无法收藏、无法缓存**。同类行、不同动作集。

证据：`favorites-tracks-dark.png`（行尾直接图标）vs `search-results-dark.png`（行尾只有 ⋮）。

**修法**：收藏夹行改用与搜索行相同的 `TrackActionsButton`，统一入口与动作集。

---

## 三、P2：打磨项

### 7. 桌面曲库只有网格，没有紧凑列表

```dart
if (constraints.maxWidth >= AppBreakpoints.compact) {  // 600
  return _trackGrid(...);     // 1280px 下 6 列卡片，一屏约 12 首
}
return _trackList(...);
```

纯按宽度切换、**无用户开关**。同时搜索页在任何宽度都是列表——同一批曲目两种布局。

### 8. 封面圆角无统一 token

网格卡 `4.0`、列表/迷你/搜索 `8`、播放器 `24`、底部面板 `28`（`library_screen.dart:862`、
`player_screen.dart:128`、`player_sheet.dart:56`）。建议抽一组 `AppRadius` 常量。

### 9. 死代码

- `track_actions_button.dart:141-152`：`_cacheTrack` 的 if / else 两个分支**代码完全相同**
- `track_actions_button.dart:169` 与 `player_screen.dart:295`：两个**完全重复**的收藏 provider
- `player_sheet.dart:47-51`：`DraggableScrollableSheet` 的 controller 从未被任何可滚动组件挂载，
  导致 `minChildSize: 0.4` / `maxChildSize: 0.95` **永远不可达**（面板高度实际固定）

---

## 三-B、Pass B 新发现：浅色模式可访问性问题

这两条是在我修复**之前**的截图上测出来的，与已修的项无关，**目前仍未修**。

### 分区标题对比度不达标（浅色模式）

设置页的「播放 / 曲库 / 扫描根目录」小标题：

| 主题 | 测得的文字色 / 底色 | 对比度 | WCAG AA（小字需 4.5） |
| --- | --- | --- | --- |
| 浅色 | `#66558E` / `#FEF7FF` | **2.69:1** | ❌ 不达标 |
| 深色 | `#D1BCFD` / `#141218` | 10.43:1 | ✅ 通过 |

根因：小标题用了 `colorScheme.primary`，而 M3 的 `primary` 是为**大字/强调**设计的，
作小字正文色时浅色模式不达标。

**修法**：改用 `colorScheme.onSurfaceVariant`（浅色约 7:1），或换任何 ≥4.5:1 的色调。
代价是失去紫色强调（深色模式本来是达标的）。

### 「用量」0 B 进度条几乎不可见（浅色模式）

设置页「用量」行在 `0 B / 1 GB` 时**没有任何填充**，唯一的视觉提示是轨道本身：

| 主题 | 轨道色 / 底色 | 对比度 | 观感 |
| --- | --- | --- | --- |
| 浅色 | `#E9DEF8` / `#FEF7FF` | **1.1:1** | 细如发丝，几乎等于空白 |
| 深色 | `#4A4358` / `#141218` | 约 1.6:1 | 可见 |

**修法**：轨道改用 `outlineVariant`（更深一档），或在 0 进度时也保留极小可见填充。

### 两条轻微项

- 深色模式 `本地` / `B站` 来源标签：文字 `#E9DEF8` 于 `#4A4358`，约 **3.2:1**，字号约 10px，
  低于小字 AA 但实际可读。
- 播放器的 shuffle / repeat / heart（关闭态）与 prev / next 的图标颜色**完全相同**（均 `#CBC4CF`，约 10.5:1），
  非激活态只能靠「没有主色着色」来区分，视觉权重上没有差异。

### 覆盖缺口

- `低音质 (64kbps)` 这一混排文案在任何截图中都未出现，**无法验证**。

---

## 四、我怀疑过、但实测后**推翻**的（不要修）

诚实记录，避免后续白做工：

| 怀疑 | 实测结果 |
| --- | --- |
| 移动端列表行距不均匀 | **错**。实测行距恒为 **72px**，封面方块恒为 **48×48**；末行 44px 只是被底部导航裁切。 |
| 网格卡片作者名与标签纵向错位 | **错**。实测作者文字带恒在 **y 359–370**、标签恒在 **y 379–389**，所有卡片完全一致；标题区底部对齐。 |
| 空状态两个按钮语义混淆 | **不成立**。标签明确、图标不同、上方有说明文案、主次层级正确。**无需修改。** |

前两条我差点误报，都是先测量才撤回的。

---

## 五、做得好的地方（不要改坏）

- **主题是真的**：单一 `ColorScheme.fromSeed(0xFF5E35B1)` + `ThemeMode.system`，
  文本全部走 `textTheme` 角色，除上面那处 `Colors.grey` 外无硬编码配色。
- **状态齐全**：每个异步界面都有空 / 错误 / 加载态，且都由主题驱动。
- **行尾纪律一致**：[播放指示] → 时长 → 操作，列表/搜索/收藏夹三处一致；
  400px 下的双控件预算被遵守，所有截图**无溢出**。
- **功能路径真实**：`playQueue` / `toggleFavorite` / `cacheTrack` 都落到真实实现；
  搜索是提交式 + 本地 FTS 防抖，符合各自限流要求。
- **算法一致**：排序比较器在数据库侧与收藏夹客户端侧逻辑一致。

---

## 六、截图清单（12 张，覆盖 6 个界面）

| 界面 | 桌面 1280×800 | 移动 400×800 |
| --- | --- | --- |
| 曲库 · 网格 | 浅色 / 深色 | — |
| 曲库 · 列表 | — | 浅色 / 深色 |
| 曲库 · 空状态 | 深色 | — |
| 搜索 · 有结果 | 深色 | — |
| 设置 | 浅色 / 深色 | — |
| B站收藏夹 · 文件夹 / 曲目 | 深色 | — |
| 播放器 · 停靠面板 / 全屏 | 深色 | — |

---

## 七、已知盲区与验证状态

| 项 | 状态 |
| --- | --- |
| 封面呈现本身 | **未验证**。`Image.file` 在 widget 测试假异步区内无法解析（实测 `resolve` 失败、`precacheImage` 挂死），截图里封面是空白方块——**采集限制，不是产品缺陷**。 |
| 设计系统完整性审查（Pass A） | ✅ 已完成，结论已并入本报告；关键指控我已逐条复核源码 |
| 视觉保真 / 中文排版审查（Pass B） | ⏳ 首次会话异常中止，已重跑，结果待回 |
| 动画 / 悬停 / 按下态 | 未采集（golden 渲染限制） |
