# 视觉基础层（Visual Foundation）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立一层「设计令牌 + 主题级组件主题 + 共享组件」，统一 Flind Player 的视觉细节，并修掉若干已核实的视觉问题。

**Architecture:** 纯展示层。新增 `AppSpacing` / `AppRadius` 令牌与 `SectionHeader` / `EmptyState` 两个共享组件；把卡片、分隔线、输入框、进度条等组件样式收口到 `AppTheme`；把散落的空状态、分区标题与封面圆角改为使用共享实现。

**Tech Stack:** Flutter 3.47（Material 3）、Riverpod；`flutter_test`。注意 3.47 使用 `CardThemeData` / `InputDecorationThemeData`。

**Spec:** `docs/spec-visual-foundation-2026-10-08.md`

## Global Constraints

- 不改功能逻辑、信息架构与数据层；无新依赖。
- Flutter 3.47：主题字段类型为 `CardThemeData`、`InputDecorationThemeData`、`NavigationBarThemeData`、`NavigationRailThemeData`、`DividerThemeData`、`ListTileThemeData`、`ProgressIndicatorThemeData`。
- 令牌：`AppSpacing` = 4/8/12/16/24/32；`AppRadius` = 8/12/16/20/pill(999)。
- 每个新增 Dart 文件都以仓库统一的 GPL 头开始（从任意同级文件复制 15 行头）。
- 每个任务结束跑 `flutter analyze` 与相关测试；最后跑全量 `flutter test`（当前基线 817 通过）。
- 提交信息用 conventional commits（`feat(ui):` / `refactor(ui):` / `fix(ui):`）。
- 测试文件统一用 `localizedApp(...)`（`test/support/l10n.dart`）包裹，以拿到 `AppLocalizations`。

## Review Focus

- **窄屏 / 横屏下的空状态**：`EmptyState` 必须经 `ResponsiveCenter` 渲染，在视口高度不足时可滚动而不是溢出。由 `empty_state`/各页面现有窄屏测试覆盖（`favorites_ui_test.dart` 的 400px 用例、`mini_player_bar_test.dart` 的 400px 用例）。
- **超长标题 / 说明文案**：空状态标题与说明要居中且可换行，不溢出。由长标题的既有测试覆盖。
- **深浅色一致性**：分区标题、来源标签、折叠图标必须来自 `colorScheme` 角色，不得硬编码。由主题/组件测试断言颜色角色覆盖。
- **主题种子色变化**：组件主题（卡片、输入框、进度条轨道）必须随 seed 派生，不写死颜色。由 `app_theme_test` 的双 brightness 循环覆盖。
- **迷你播放条无时长**：`durationMs == 0` 时不渲染进度条（既有行为，不得回归）。由 `mini_player_bar_test` 覆盖。

---

### Task 1: 设计令牌 + 主题级组件主题

**Files:**
- Create: `lib/app/theme/app_tokens.dart`
- Modify: `lib/app/theme/app_theme.dart:31-48`（`_build`）
- Test: `test/app_theme_test.dart`（追加一个 test）

**Interfaces:**
- Produces: `AppSpacing.xs/sm/md/lg/xl/xxl`、`AppRadius.sm/md/lg/xl/pill`（`static const double`）。
- Produces: `AppTheme.light(seed)` / `AppTheme.dark(seed)` 返回带组件主题的 `ThemeData`。

- [ ] **Step 1: Write the failing test**

在 `test/app_theme_test.dart` 顶部加 `import 'package:flind_player/app/theme/app_tokens.dart';`，并在 `main()` 内追加：

```dart
  test('component themes derive from the tokens and the colour scheme', () {
    for (final theme in [AppTheme.light(seed), AppTheme.dark(seed)]) {
      expect(theme.cardTheme.elevation, 0);
      final shape = theme.cardTheme.shape;
      expect(shape, isA<RoundedRectangleBorder>());
      expect(
        (shape! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(AppRadius.sm),
      );
      expect(theme.dividerTheme.color, theme.colorScheme.outlineVariant);
      expect(
        theme.progressIndicatorTheme.linearTrackColor,
        theme.colorScheme.outlineVariant,
      );
      final border = theme.inputDecorationTheme.border;
      expect(border, isA<OutlineInputBorder>());
      expect(
        (border! as OutlineInputBorder).borderRadius,
        BorderRadius.circular(AppRadius.md),
      );
      expect(
        theme.listTileTheme.contentPadding,
        const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      );
    }
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/app_theme_test.dart`
Expected: FAIL（`AppSpacing`/`AppRadius` 未定义 → 编译错误；或组件主题断言失败）。

- [ ] **Step 3: Create the tokens**

Create `lib/app/theme/app_tokens.dart`（加 GPL 头）：

```dart
import 'package:flutter/foundation.dart';

/// Spacing scale in logical pixels, on a 4pt base.
@immutable
class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Corner-radius scale in logical pixels.
@immutable
class AppRadius {
  const AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;

  /// Fully rounded (chips, pills).
  static const double pill = 999;
}
```

- [ ] **Step 4: Apply the component themes**

在 `lib/app/theme/app_theme.dart` 顶部加 `import 'package:flind_player/app/theme/app_tokens.dart';`，把 `_build` 的 `return ThemeData(...)` 整体替换为：

```dart
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        indicatorShape: StadiumBorder(),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        indicatorShape: StadiumBorder(),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        linearTrackColor: colorScheme.outlineVariant,
        linearMinHeight: 2,
      ),
      // Every SnackBar renders as a rounded floating bubble clear of the
      // screen edges instead of a full-width bottom bar.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
```

- [ ] **Step 5: Run tests + analyze**

Run: `flutter test test/app_theme_test.dart` → PASS
Run: `flutter analyze` → No issues

- [ ] **Step 6: Commit**

```bash
git add lib/app/theme/app_tokens.dart lib/app/theme/app_theme.dart test/app_theme_test.dart
git commit -m "feat(ui): add design tokens and component themes"
```

---

### Task 2: `SectionHeader` 共享组件

**Files:**
- Create: `lib/shared/section_header.dart`
- Test: `test/section_header_test.dart`
- Modify: `lib/features/settings/settings_screen.dart`（5 处 `_SectionHeader(...)`、`_ScanRootHeader`、删除 `_SectionHeader` 类）

**Interfaces:**
- Consumes: `AppSpacing`（Task 1）。
- Produces: `SectionHeader(String title, {Key? key, Widget? trailing})`。

- [ ] **Step 1: Write the failing test**

Create `test/section_header_test.dart`（加 GPL 头）：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/shared/section_header.dart';

import 'support/l10n.dart';

void main() {
  testWidgets('renders the title in the muted role colour', (tester) async {
    await tester.pumpWidget(
      localizedApp(const Scaffold(body: SectionHeader('曲库'))),
    );

    final text = tester.widget<Text>(find.text('曲库'));
    final context = tester.element(find.text('曲库'));
    expect(text.style?.color, Theme.of(context).colorScheme.onSurfaceVariant);
  });

  testWidgets('renders a trailing action', (tester) async {
    await tester.pumpWidget(
      localizedApp(
        const Scaffold(
          body: SectionHeader('曲库', trailing: Icon(Icons.add)),
        ),
      ),
    );

    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/section_header_test.dart`
Expected: FAIL（`section_header.dart` 不存在）。

- [ ] **Step 3: Implement**

Create `lib/shared/section_header.dart`（加 GPL 头）：

```dart
import 'package:flutter/material.dart';

import 'package:flind_player/app/theme/app_tokens.dart';

/// A muted section heading, optionally with a trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    final trailingWidget = trailing;
    if (trailingWidget == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: label,
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(children: [Expanded(child: label), trailingWidget]),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/section_header_test.dart`
Expected: PASS

- [ ] **Step 5: Switch the settings screen over**

在 `lib/features/settings/settings_screen.dart`：
1. 加 `import 'package:flind_player/shared/section_header.dart';`。
2. 把 5 处 `_SectionHeader(l10n.xxx)` 改为 `SectionHeader(l10n.xxx)`。
3. 删除 `class _SectionHeader {...}`（文件末尾）。
4. 把 `_ScanRootHeader.build` 替换为：

```dart
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SectionHeader(
      l10n.scanRoots,
      trailing: IconButton(
        icon: const Icon(Icons.create_new_folder_outlined),
        onPressed: isSyncing ? null : onAdd,
      ),
    );
  }
```

- [ ] **Step 6: Run the settings + widget tests, then analyze**

Run: `flutter test test/settings_screen_test.dart test/section_header_test.dart`
Expected: PASS
Run: `flutter analyze` → No issues

- [ ] **Step 7: Commit**

```bash
git add lib/shared/section_header.dart test/section_header_test.dart lib/features/settings/settings_screen.dart
git commit -m "refactor(ui): share a SectionHeader widget"
```

---

### Task 3: `EmptyState` 共享组件 + 搜索 / 播放器空态

**Files:**
- Create: `lib/shared/empty_state.dart`
- Test: `test/empty_state_test.dart`
- Modify: `lib/features/search/search_screen.dart`（`_SearchHint`、`_NoResults`）
- Modify: `lib/features/player/player_screen.dart`（`_NothingPlaying`）

**Interfaces:**
- Consumes: `ResponsiveCenter`（`lib/shared/responsive_center.dart`）。
- Produces: `EmptyState({Key? key, required IconData icon, required String title, String? message, Widget? action, double iconSize = 64, Color? iconColor})`。

- [ ] **Step 1: Write the failing test**

Create `test/empty_state_test.dart`（加 GPL 头）：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/shared/empty_state.dart';

import 'support/l10n.dart';

void main() {
  testWidgets('renders icon, title, message and action', (tester) async {
    await tester.pumpWidget(
      localizedApp(
        Scaffold(
          body: EmptyState(
            icon: Icons.search,
            title: '标题',
            message: '说明',
            action: const Text('操作'),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.text('标题'), findsOneWidget);
    expect(find.text('说明'), findsOneWidget);
    expect(find.text('操作'), findsOneWidget);
  });

  testWidgets('omits message and action when absent', (tester) async {
    await tester.pumpWidget(
      localizedApp(
        const Scaffold(body: EmptyState(icon: Icons.search, title: '仅标题')),
      ),
    );

    // Only the title renders; no message, no action.
    expect(find.byType(Text), findsOneWidget);
    expect(find.text('仅标题'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/empty_state_test.dart`
Expected: FAIL（`empty_state.dart` 不存在）。

- [ ] **Step 3: Implement**

Create `lib/shared/empty_state.dart`（加 GPL 头）：

```dart
import 'package:flutter/material.dart';

import 'package:flind_player/shared/responsive_center.dart';

/// A centred empty-state panel: an icon, a title, an optional message and an
/// optional action. [ResponsiveCenter] keeps it scroll-safe in short viewports.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.iconSize = 64,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final double iconSize;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final messageText = message;
    final actionWidget = action;
    return ResponsiveCenter(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: iconColor ?? scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (messageText != null) ...[
              const SizedBox(height: 8),
              Text(
                messageText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionWidget != null) ...[
              const SizedBox(height: 24),
              actionWidget,
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/empty_state_test.dart`
Expected: PASS

- [ ] **Step 5: Replace the search and player empty states**

`lib/features/search/search_screen.dart`：
1. 加 `import 'package:flind_player/shared/empty_state.dart';`。
2. `_buildBody` 顶部加 `final l10n = AppLocalizations.of(context);`。
3. 把 `return const _SearchHint();`（≈169）改为：
   `return EmptyState(icon: Icons.search, title: l10n.searchSourcesTitle, message: l10n.searchSourcesHint);`
4. 把 `return const _NoResults();`（≈189）改为：
   `return EmptyState(icon: Icons.search_off, title: l10n.noResults, message: l10n.tryAnotherKeyword);`
5. 删除 `class _SearchHint` 与 `class _NoResults`。

`lib/features/player/player_screen.dart`：
1. 加 `import 'package:flind_player/shared/empty_state.dart';`。
2. 把 `body = const _NothingPlaying();`（≈87）改为：
   `body = EmptyState(icon: Icons.play_circle_outline, title: AppLocalizations.of(context).notPlaying, message: AppLocalizations.of(context).notPlayingHint);`
3. 删除 `class _NothingPlaying`。

- [ ] **Step 6: Run screen tests + analyze**

Run: `flutter test test/search_screen_test.dart test/mini_player_bar_test.dart test/responsive_layout_test.dart test/favorites_ui_test.dart`
Expected: PASS
Run: `flutter analyze` → No issues

- [ ] **Step 7: Commit**

```bash
git add lib/shared/empty_state.dart test/empty_state_test.dart lib/features/search/search_screen.dart lib/features/player/player_screen.dart
git commit -m "refactor(ui): share an EmptyState widget across search and player"
```

---

### Task 4: 曲库空状态改用 `EmptyState`

**Files:**
- Modify: `lib/features/library/library_screen.dart`（`_EmptyLibrary`、`_NoSearchResults`、`_EmptyFavourites`、`_LibraryError`）

**Interfaces:**
- Consumes: `EmptyState`（Task 3）。

- [ ] **Step 1: Write the failing test**

在 `test/library_screen_test.dart` 的 `main()` 内追加一条，并在顶部加 `import 'package:flind_player/shared/empty_state.dart';`（该文件已有 `_app()` helper，`_app()` 即空曲库）：

```dart
  testWidgets('empty library renders a single EmptyState panel', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // The empty library panel is an EmptyState, not a bespoke layout.
    expect(find.byType(EmptyState), findsOneWidget);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/library_screen_test.dart --plain-name "empty library renders"`
Expected: FAIL（`EmptyState` 未在曲库使用；`find.byType(EmptyState)` 找不到）。

- [ ] **Step 3: Replace the library empty-state bodies**

在 `lib/features/library/library_screen.dart` 加 `import 'package:flind_player/shared/empty_state.dart';`，并逐个把 `build` 换成 `EmptyState`。

`_NoSearchResults`：

```dart
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      icon: Icons.search_off,
      title: l10n.noMatchingTracks,
      message: l10n.tryAnotherKeyword,
    );
  }
```

`_EmptyFavourites`：

```dart
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      icon: Icons.favorite_border,
      title: l10n.noFavorites,
      message: l10n.noFavoritesHint,
    );
  }
```

`_EmptyLibrary`：

```dart
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      icon: Icons.library_music_outlined,
      title: l10n.emptyLibraryTitle,
      message: l10n.emptyLibraryHint,
      action: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton.tonalIcon(
            onPressed: onAddFolder,
            icon: const Icon(Icons.create_new_folder_outlined),
            label: Text(l10n.addFolder),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onImport,
            icon: const Icon(Icons.add),
            label: Text(l10n.importLocalMusic),
          ),
        ],
      ),
    );
  }
```

`_LibraryError`：

```dart
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final retry = onRetry;
    return EmptyState(
      icon: Icons.error_outline,
      iconSize: 48,
      iconColor: scheme.error,
      title: title ?? l10n.loadLibraryFailed,
      message: describeError(l10n, error),
      action: retry == null
          ? null
          : OutlinedButton.icon(
              onPressed: retry,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
    );
  }
```

- [ ] **Step 4: Run tests and analyze**

Run: `flutter test test/library_screen_test.dart test/favorites_ui_test.dart`
Expected: PASS
Run: `flutter analyze` → No issues

- [ ] **Step 5: Commit**

```bash
git add lib/features/library/library_screen.dart test/library_screen_test.dart
git commit -m "refactor(ui): use EmptyState for the library empty states"
```

---

### Task 5: 封面圆角统一到 `AppRadius`

**Files:**
- Modify: `lib/features/library/widgets/track_list_items.dart:277-296`（`TrackCover`）
- Modify: `lib/features/player/mini_player_bar.dart:138-139`（`_MiniCover`）
- Modify: `lib/features/player/player_screen.dart:470-471`（`_PlayerCover`）
- Test: `test/track_cover_test.dart`（新建）、`test/mini_player_bar_test.dart`（追加）、`test/favorites_ui_test.dart`（追加 player 封面断言）

**Interfaces:**
- Consumes: `AppRadius`（Task 1）。

- [ ] **Step 1: Write the failing tests**

Create `test/track_cover_test.dart`（加 GPL 头）：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/app/theme/app_tokens.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/features/library/widgets/track_list_items.dart';

import 'support/l10n.dart';

void main() {
  testWidgets('TrackCover rounds to the shared small radius', (tester) async {
    final track = Track(
      source: 'local',
      sourceTrackId: const LocalTrackId('/music/a.mp3'),
      uri: 'local:/music/a.mp3',
      title: 'A',
    );

    await tester.pumpWidget(
      localizedApp(Scaffold(body: TrackCover(track: track, size: 48))),
    );

    final clip = tester.widget<ClipRRect>(find.byType(ClipRRect));
    expect(clip.borderRadius, BorderRadius.circular(AppRadius.sm));
  });
}
```

在 `test/mini_player_bar_test.dart` 顶部加 `import 'package:flind_player/app/theme/app_tokens.dart';`，追加：

```dart
  testWidgets('cover is rounded with the shared small radius', (tester) async {
    final state = PlaybackState(
      isPlaying: false,
      isBuffering: false,
      isCompleted: false,
      position: Duration.zero,
      duration: const Duration(minutes: 3),
      currentTrack: _track('Cover Test'),
    );

    await tester.pumpWidget(_app(state: state));
    await tester.pumpAndSettle();

    final clip = tester.widget<ClipRRect>(
      find
          .descendant(
            of: find.byType(MiniPlayerBar),
            matching: find.byType(ClipRRect),
          )
          .first,
    );
    expect(clip.borderRadius, BorderRadius.circular(AppRadius.sm));
  });
```

在 `test/favorites_ui_test.dart` 的 `Player favourite button` group 内追加：

```dart
    testWidgets('player cover is rounded with the shared large radius', (
      tester,
    ) async {
      final track = _track('Now Playing');
      final state = PlaybackState(
        isPlaying: true,
        isBuffering: false,
        isCompleted: false,
        position: Duration.zero,
        currentTrack: track,
      );

      await tester.pumpWidget(_playerApp(playbackState: state));
      await tester.pumpAndSettle();

      final clip = tester.widget<ClipRRect>(
        find
            .descendant(
              of: find.byType(PlayerScreen),
              matching: find.byType(ClipRRect),
            )
            .first,
      );
      expect(clip.borderRadius, BorderRadius.circular(AppRadius.xl));
    });
```

并在该文件顶部加 `import 'package:flind_player/app/theme/app_tokens.dart';`。

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/track_cover_test.dart test/mini_player_bar_test.dart test/favorites_ui_test.dart`
Expected: FAIL（当前圆角为 4 / 8(相等则通过 mini) / 24）。

> 注：mini 当前已是 8，可能与 `AppRadius.sm` 相等而直接通过；这属于「值不变、来源改为令牌」，其价值是锁定令牌来源，可接受。track_cover(4→8) 与 player(24→20) 会失败。

- [ ] **Step 3: Apply the token**

`track_list_items.dart` 加 `import 'package:flind_player/app/theme/app_tokens.dart';`，把 `TrackCover.build` 中：

```dart
    final useFixedSize = !size.isInfinite;
    final borderRadius = useFixedSize ? size * 0.16 : 4.0;
```

替换为：

```dart
    final useFixedSize = !size.isInfinite;
    final borderRadius = BorderRadius.circular(AppRadius.sm);
```

并把紧随其后的返回改为（去掉多余的 `BorderRadius.circular(...)`）：

```dart
    return ClipRRect(borderRadius: borderRadius, child: child);
```

`mini_player_bar.dart` 加 import，把 `BorderRadius.circular(8)` 改为 `BorderRadius.circular(AppRadius.sm)`。

`player_screen.dart` 加 import，把 `BorderRadius.circular(24)` 改为 `BorderRadius.circular(AppRadius.xl)`。

- [ ] **Step 4: Run tests and analyze**

Run: `flutter test test/track_cover_test.dart test/mini_player_bar_test.dart test/favorites_ui_test.dart`
Expected: PASS
Run: `flutter analyze` → No issues

- [ ] **Step 5: Commit**

```bash
git add lib/features/library/widgets/track_list_items.dart lib/features/player/mini_player_bar.dart lib/features/player/player_screen.dart test/track_cover_test.dart test/mini_player_bar_test.dart test/favorites_ui_test.dart
git commit -m "refactor(ui): unify cover radii on AppRadius"
```

---

### Task 6: 来源标签排版

**Files:**
- Modify: `lib/features/library/widgets/track_list_items.dart:248-253`（`SourceBadge`）
- Test: `test/source_badge_test.dart`（追加）

**Interfaces:**
- Consumes: `AppRadius`（Task 1，可选用于 badge 圆角）。

- [ ] **Step 1: Write the failing test**

在 `test/source_badge_test.dart` 的 `main()` 内追加：

```dart
  testWidgets('SourceBadge uses the medium label role', (tester) async {
    await tester.pumpWidget(
      localizedApp(const Scaffold(body: SourceBadge(source: 'local'))),
    );

    final text = tester.widget<Text>(find.text('本地'));
    final context = tester.element(find.text('本地'));
    expect(
      text.style?.fontSize,
      Theme.of(context).textTheme.labelMedium?.fontSize,
    );
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/source_badge_test.dart --plain-name "medium label role"`
Expected: FAIL（当前用 `labelSmall`，fontSize 不等）。

- [ ] **Step 3: Apply**

在 `SourceBadge` 里把 `theme.textTheme.labelSmall` 改为 `theme.textTheme.labelMedium`。

- [ ] **Step 4: Run tests and analyze**

Run: `flutter test test/source_badge_test.dart`
Expected: PASS
Run: `flutter analyze` → No issues

- [ ] **Step 5: Commit**

```bash
git add lib/features/library/widgets/track_list_items.dart test/source_badge_test.dart
git commit -m "fix(ui): size the source badge on the medium label role"
```

---

### Task 7: 收藏色与迷你播放条进度轨道

**Files:**
- Modify: `lib/features/player/player_screen.dart:727`（收藏色）
- Modify: `lib/features/player/mini_player_bar.dart:58-63`（进度条）
- Test: `test/favorites_ui_test.dart`（追加）、`test/mini_player_bar_test.dart`（追加）

**Interfaces:**
- Consumes: `progressIndicatorTheme.linearTrackColor`（Task 1）。

- [ ] **Step 1: Write the failing tests**

在 `test/favorites_ui_test.dart` 的 `Player favourite button` group 内追加：

```dart
    testWidgets('an active favourite is tinted with the error role', (
      tester,
    ) async {
      final track = _track('Now Playing');
      final favRepo = _InMemoryFavoritesRepository();
      await favRepo.addFavorite(track);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playbackStateProvider.overrideWith(
              (ref) => Stream.value(
                PlaybackState(
                  isPlaying: true,
                  isBuffering: false,
                  isCompleted: false,
                  position: Duration.zero,
                  currentTrack: track,
                ),
              ),
            ),
            favoritesRepositoryProvider.overrideWithValue(favRepo),
            favoritesProvider.overrideWith((ref) => favRepo.watchFavorites()),
          ],
          child: localizedApp(const PlayerScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final icon = tester.widget<Icon>(find.byIcon(Icons.favorite));
      final context = tester.element(find.byIcon(Icons.favorite));
      expect(icon.color, Theme.of(context).colorScheme.error);
    });
```

在 `test/mini_player_bar_test.dart` 追加：

```dart
  testWidgets('progress track colour comes from the theme, not a literal', (
    tester,
  ) async {
    final state = PlaybackState(
      isPlaying: true,
      isBuffering: false,
      isCompleted: false,
      position: const Duration(seconds: 30),
      duration: const Duration(minutes: 3),
      currentTrack: _track('Progress Test'),
    );

    await tester.pumpWidget(_app(state: state));
    await tester.pumpAndSettle();

    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.backgroundColor, isNull);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/favorites_ui_test.dart test/mini_player_bar_test.dart --plain-name "favourite is tinted"` 以及 `--plain-name "progress track colour"`
Expected: FAIL（收藏色为 `Colors.red`；进度条 `backgroundColor` 非空）。

- [ ] **Step 3: Apply**

`player_screen.dart`：把
`color: isFavourite ? Colors.red : scheme.onSurfaceVariant,`
改为
`color: isFavourite ? scheme.error : scheme.onSurfaceVariant,`
并更新上方注释（去掉「stay red」的措辞，改为「跟随主题 error 角色」）。

`mini_player_bar.dart`：删除 `LinearProgressIndicator` 的
`backgroundColor: scheme.surfaceContainerHighest,`
（保留 `value` 与 `minHeight`；轨道色由 `progressIndicatorTheme.linearTrackColor` 提供）。

- [ ] **Step 4: Run tests + analyze**

Run: `flutter test test/favorites_ui_test.dart test/mini_player_bar_test.dart`
Expected: PASS
Run: `flutter analyze` → No issues

- [ ] **Step 5: Commit**

```bash
git add lib/features/player/player_screen.dart lib/features/player/mini_player_bar.dart test/favorites_ui_test.dart test/mini_player_bar_test.dart
git commit -m "fix(ui): theme the favourite tint and the mini progress track"
```

---

### Task 8: 全量回归

**Files:** 无（验证任务）

- [ ] **Step 1: Run the whole suite**

Run: `flutter analyze`
Expected: No issues

Run: `flutter test`
Expected: 全部通过（≥ 817，含本轮新增用例）

- [ ] **Step 2: 目视核对（如有条件）**

在 Linux 桌面 `flutter run -d linux` 下核对：
- 设置页分区标题、扫描根标题为中性色而非主色；
- 输入框（搜索 / 十六进制 / 缓存上限）圆角变大；
- 卡片无阴影、圆角统一；
- 迷你播放条 0 进度时轨道可见；
- 收藏心形为 `error` 色调。

- [ ] **Step 3: 无改动则无需提交；若目视发现偏差，回到对应任务修正并补测试。**
