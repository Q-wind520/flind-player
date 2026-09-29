# 曲库界面（LibraryScreen）UI TODO 实施计划

> **状态：已执行完毕并发布（v0.5.0）· 2026-09-29 归档。**
> 下列步骤保留为实施记录，勾选框未逐条回填；**不要**按本文件重新执行。
> 设计见 [`spec-library-screen-ui-2026-09-27.md`](spec-library-screen-ui-2026-09-27.md)，
> 现行描述见 [`docs/widget-tree.md`](../widget-tree.md) 的 LibraryScreen 一节。

**Goal:** 落地曲库界面的 6 项 UI TODO：离线缓存两态、顶部「本地/排序/视图」二级菜单、搜索与新建歌单按页面收窄、单曲「移出歌单/删除歌曲」、按页面持久化的多视图、小红书式瀑布流。

**Architecture:** 新增 `LibraryView`/`LibraryViewScope` 模型与 `LibraryViews` 聚合，经 `SettingsRepository`（shared_preferences）持久化，由 `LibraryViewsNotifier` 暴露。曲目渲染抽出共享 `TrackView`（展柜网格 / 列表 / 瀑布流），顶部菜单改为 Material 3 `MenuAnchor` + `SubmenuButton`。危险的「删除歌曲」由一个 `TrackDeletionService` 编排缓存 / 歌单 / 曲库三步清理。

**Tech Stack:** Flutter 3.47、Dart 3.13、Riverpod 3.4、drift、shared_preferences、flutter_staggered_grid_view。

**Spec:** `docs/archive/spec-library-screen-ui-2026-09-27.md`（执行者需同时阅读本计划与规格）

## Global Constraints

- 视图默认值：全部=`waterfall`、收藏=`showcase`、歌单列表=`showcase`、歌单详情=`list`。
- 歌单列表作用域仅允许 `showcase`/`list`；持久化读到 `waterfall` 必须回落 `showcase`（`LibraryViewScope.sanitize`）。
- 离线缓存行内两态文案：未缓存=「离线缓存」（可点击下载并 pin）；已缓存=「已缓存」（`enabled: false`，不可点击）。
- 搜索框仅在「全部」页常显；「+ 新建歌单」仅在「歌单」页；删除右上角搜索切换按钮。
- 「删除歌曲」不从磁盘删除本地原始文件。
- 排序默认值改为 `TrackSort.recentlyAdded`（未设置过的用户生效；已存储值不变）。
- l10n：模板 `lib/l10n/app_en.arb`，中文 `lib/l10n/app_zh.arb`，改动后运行 `flutter gen-l10n` 并提交生成物。
- 提交信息使用英文 conventional commit。
- 每完成一个任务运行 `flutter test <相关文件>` 与 `dart analyze`（至少 impacted 文件）。

## Review Focus

以下 5 类输入/失败模式规格未显式覆盖，但最可能真实伤到用户；各自绑定到拥有该代码的任务测试中：

1. **删除正在播放的曲目**：删除只动曲库行/歌单/缓存，播放不应中断或抛异常（Task 14）。
2. **封面文件/URL 解析失败**：瀑布流回落 1:1 占位，不抛异常（Task 8）。
3. **持久化视图值损坏，或歌单列表作用域存了 `waterfall`**：回落默认（Task 2）。
4. **切换分区时保留搜索查询**：离开「全部」隐藏搜索框，返回仍显示原结果，且不泄漏到「收藏/歌单」（Task 7）。
5. **400px 下子菜单不溢出**；同步进行中「添加文件夹/重新扫描」不可点击（Task 6）。

---

### Task 1: `LibraryView` 模型

**Files:**
- Create: `lib/core/models/library_view.dart`
- Test: `test/library_view_test.dart`

**Interfaces:**
- Produces:
  - `enum LibraryView { showcase, list, waterfall }`
  - `enum LibraryViewScope { all, favorites, playlists, playlistDetail }`
  - `LibraryViewScope.defaultView` → `LibraryView`
  - `LibraryViewScope.allowedViews` → `Set<LibraryView>`
  - `LibraryViewScope.sanitize(LibraryView) → LibraryView`
  - `LibraryViews`（不可变）：`viewOf(scope) → LibraryView`、`withView(scope, view) → LibraryViews`、`static LibraryViews defaults`、`==`/`hashCode`

- [ ] **Step 1: Write the failing test**

Create `test/library_view_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/library_view.dart';

void main() {
  test('scopes expose the agreed defaults', () {
    expect(LibraryViewScope.all.defaultView, LibraryView.waterfall);
    expect(LibraryViewScope.favorites.defaultView, LibraryView.showcase);
    expect(LibraryViewScope.playlists.defaultView, LibraryView.showcase);
    expect(LibraryViewScope.playlistDetail.defaultView, LibraryView.list);
  });

  test('the playlists scope only allows showcase and list', () {
    expect(
      LibraryViewScope.playlists.allowedViews,
      {LibraryView.showcase, LibraryView.list},
    );
    expect(
      LibraryViewScope.playlists.sanitize(LibraryView.waterfall),
      LibraryView.showcase,
    );
  });

  test('sanitize keeps an allowed view and falls back otherwise', () {
    expect(
      LibraryViewScope.all.sanitize(LibraryView.list),
      LibraryView.list,
    );
    expect(
      LibraryViewScope.playlistDetail.sanitize(LibraryView.waterfall),
      LibraryView.waterfall,
    );
  });

  test('LibraryViews.viewOf returns the stored value or the default', () {
    const views = LibraryViews({
      LibraryViewScope.all: LibraryView.list,
    });
    expect(views.viewOf(LibraryViewScope.all), LibraryView.list);
    expect(views.viewOf(LibraryViewScope.favorites), LibraryView.showcase);
  });

  test('withView sanitizes and keeps other scopes', () {
    final views = LibraryViews.defaults
        .withView(LibraryViewScope.all, LibraryView.list)
        .withView(LibraryViewScope.playlists, LibraryView.waterfall);
    expect(views.viewOf(LibraryViewScope.all), LibraryView.list);
    // waterfall is not allowed for the playlists scope -> falls back.
    expect(views.viewOf(LibraryViewScope.playlists), LibraryView.showcase);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/library_view_test.dart`
Expected: FAIL — `library_view.dart` not found / `LibraryView` undefined.

- [ ] **Step 3: Write minimal implementation**

Create `lib/core/models/library_view.dart`:

```dart
// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.

import 'package:flutter/foundation.dart';

/// How a list of tracks (or playlists) is laid out.
enum LibraryView {
  /// Card grid.
  showcase,

  /// Single-column rows.
  list,

  /// Variable-height masonry, cover aspect ratio preserved.
  waterfall,
}

/// A page whose view is chosen independently and persisted.
enum LibraryViewScope {
  all,
  favorites,
  playlists,
  playlistDetail;

  /// The view shown when nothing valid is stored for this scope.
  LibraryView get defaultView => switch (this) {
    LibraryViewScope.all => LibraryView.waterfall,
    LibraryViewScope.favorites => LibraryView.showcase,
    LibraryViewScope.playlists => LibraryView.showcase,
    LibraryViewScope.playlistDetail => LibraryView.list,
  };

  /// The views this scope offers. The playlists list has no song-cover ratio,
  /// so it has no waterfall.
  Set<LibraryView> get allowedViews => switch (this) {
    LibraryViewScope.playlists => const {
      LibraryView.showcase,
      LibraryView.list,
    },
    _ => const {
      LibraryView.showcase,
      LibraryView.list,
      LibraryView.waterfall,
    },
  };

  /// [view] when allowed, otherwise [defaultView].
  LibraryView sanitize(LibraryView view) =>
      allowedViews.contains(view) ? view : defaultView;
}

/// Every scope's chosen view. Missing scopes fall back to their default.
@immutable
class LibraryViews {
  const LibraryViews(this._views);

  final Map<LibraryViewScope, LibraryView> _views;

  /// Nothing stored: every scope uses its default.
  static const LibraryViews defaults = LibraryViews(<LibraryViewScope, LibraryView>{});

  LibraryView viewOf(LibraryViewScope scope) =>
      _views[scope] ?? scope.defaultView;

  /// A copy with [scope] set to [view] (sanitized for the scope).
  LibraryViews withView(LibraryViewScope scope, LibraryView view) =>
      LibraryViews({..._views, scope: scope.sanitize(view)});

  @override
  bool operator ==(Object other) =>
      other is LibraryViews && mapEquals(_views, other._views);

  @override
  int get hashCode => Object.hashAll(
    LibraryViewScope.values.map((scope) => _views[scope]),
  );

  @override
  String toString() => 'LibraryViews($_views)';
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/library_view_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/models/library_view.dart test/library_view_test.dart
git commit -m "feat(library): add LibraryView model and scope defaults"
```

---

### Task 2: 视图持久化（`SettingsRepository` + `PrefsSettingsRepository` + 更新所有 fake）

**Files:**
- Modify: `lib/core/repositories/settings_repository.dart`
- Modify: `lib/data/repositories/prefs_settings_repository.dart`
- Modify: `test/prefs_settings_repository_test.dart`（新增测试）
- Modify: `test/settings_screen_test.dart:60`、`test/cached_stream_resolver_test.dart:51`、`test/cover_cache_store_test.dart:31`、`test/download_manager_test.dart:38`、`test/home_shell_test.dart:52`、`test/audio_cache_store_test.dart:30`、`test/responsive_layout_test.dart:135`（为每个 `implements SettingsRepository` 的 fake 补两个方法）

**Interfaces:**
- Consumes: `LibraryViews`, `LibraryViewScope`, `LibraryView`（Task 1）。
- Produces:
  - `SettingsRepository.libraryViews() → Future<LibraryViews>`
  - `SettingsRepository.setLibraryView(LibraryViewScope, LibraryView) → Future<void>`
  - `PrefsSettingsRepository.libraryViewKeyPrefix = 'library.view.'`

- [ ] **Step 1: Write the failing test**

Append to `test/prefs_settings_repository_test.dart` (add imports at top: `import 'package:flind_player/core/models/library_view.dart';`):

```dart
  test('libraryViews defaults to the scope defaults when nothing is stored',
      () async {
    final repository = PrefsSettingsRepository();
    addTearDown(repository.dispose);

    final views = await repository.libraryViews();
    expect(views.viewOf(LibraryViewScope.all), LibraryView.waterfall);
    expect(views.viewOf(LibraryViewScope.playlistDetail), LibraryView.list);
  });

  test('libraryViews round-trips a stored choice', () async {
    final repository = PrefsSettingsRepository();
    addTearDown(repository.dispose);

    await repository.setLibraryView(LibraryViewScope.all, LibraryView.list);

    final views = await repository.libraryViews();
    expect(views.viewOf(LibraryViewScope.all), LibraryView.list);
  });

  test('libraryViews falls back for a corrupt stored value', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'library.view.all': 'hologram',
    });
    final repository = PrefsSettingsRepository();
    addTearDown(repository.dispose);

    final views = await repository.libraryViews();
    expect(views.viewOf(LibraryViewScope.all), LibraryView.waterfall);
  });

  test('libraryViews sanitizes a waterfall stored for the playlists scope',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'library.view.playlists': 'waterfall',
    });
    final repository = PrefsSettingsRepository();
    addTearDown(repository.dispose);

    final views = await repository.libraryViews();
    expect(views.viewOf(LibraryViewScope.playlists), LibraryView.showcase);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/prefs_settings_repository_test.dart`
Expected: FAIL — `libraryViews` is not defined.

- [ ] **Step 3: Extend the interface**

In `lib/core/repositories/settings_repository.dart`, add the import `import 'package:flind_player/core/models/library_view.dart';` and these members near `librarySort`:

```dart
  /// Every scope's persisted library view, falling back to per-scope defaults.
  Future<LibraryViews> libraryViews();

  /// Persists [view] for [scope] (sanitized for that scope).
  Future<void> setLibraryView(LibraryViewScope scope, LibraryView view);
```

- [ ] **Step 4: Implement in `PrefsSettingsRepository`**

In `lib/data/repositories/prefs_settings_repository.dart`, add `import 'package:flind_player/core/models/library_view.dart';` and:

```dart
  /// Preferences key prefix for a scope's library view.
  static const String libraryViewKeyPrefix = 'library.view.';

  static String _libraryViewKey(LibraryViewScope scope) =>
      '$libraryViewKeyPrefix${scope.name}';

  @override
  Future<LibraryViews> libraryViews() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final views = <LibraryViewScope, LibraryView>{};
      for (final scope in LibraryViewScope.values) {
        final name = prefs.getString(_libraryViewKey(scope));
        if (name == null) continue;
        final parsed = LibraryView.values.asNameMap()[name];
        if (parsed == null) continue;
        views[scope] = scope.sanitize(parsed);
      }
      return LibraryViews(views);
    } catch (error) {
      debugPrint('PrefsSettingsRepository: libraryViews read failed: $error');
      return LibraryViews.defaults;
    }
  }

  @override
  Future<void> setLibraryView(LibraryViewScope scope, LibraryView view) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_libraryViewKey(scope), scope.sanitize(view).name);
  }
```

- [ ] **Step 5: Update every `SettingsRepository` fake**

In each of these files add the same two overrides to the fake class listed, plus the import `import 'package:flind_player/core/models/library_view.dart';`:

- `test/settings_screen_test.dart` → `_FakeSettingsRepository` (line ~60)
- `test/cached_stream_resolver_test.dart` → `_FakeSettingsRepository` (line ~51)
- `test/cover_cache_store_test.dart` → `_FakeSettingsRepository` (line ~31)
- `test/download_manager_test.dart` → `_FakeSettingsRepository` (line ~38)
- `test/home_shell_test.dart` → `_FakeSettingsRepository` (line ~52)
- `test/audio_cache_store_test.dart` → `FakeSettingsRepository` (line ~30)
- `test/responsive_layout_test.dart` → `_FakeSettingsRepository` (line ~135)

```dart
  @override
  Future<LibraryViews> libraryViews() async => LibraryViews.defaults;

  @override
  Future<void> setLibraryView(LibraryViewScope scope, LibraryView view) async {}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/prefs_settings_repository_test.dart test/settings_screen_test.dart test/home_shell_test.dart`
Expected: PASS. Then run `dart analyze` and confirm no `missing_override` errors.

- [ ] **Step 7: Commit**

```bash
git add lib/core/repositories/settings_repository.dart \
  lib/data/repositories/prefs_settings_repository.dart \
  test/prefs_settings_repository_test.dart test/settings_screen_test.dart \
  test/cached_stream_resolver_test.dart test/cover_cache_store_test.dart \
  test/download_manager_test.dart test/home_shell_test.dart \
  test/audio_cache_store_test.dart test/responsive_layout_test.dart
git commit -m "feat(settings): persist per-scope library views"
```

---

### Task 3: `libraryViewsProvider` 状态

**Files:**
- Create: `lib/features/library/library_view_provider.dart`
- Test: `test/library_view_provider_test.dart`

**Interfaces:**
- Consumes: `SettingsRepository.libraryViews()` / `setLibraryView()`（Task 2）、`settingsRepositoryProvider`（`lib/data/providers/cache_providers.dart`）。
- Produces:
  - `class LibraryViewsNotifier extends AsyncNotifier<LibraryViews>`，含 `setView(LibraryViewScope, LibraryView) → Future<void>`
  - `final libraryViewsProvider = AsyncNotifierProvider<LibraryViewsNotifier, LibraryViews>(LibraryViewsNotifier.new)`

- [ ] **Step 1: Write the failing test**

Create `test/library_view_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/library_view.dart';
import 'package:flind_player/core/repositories/settings_repository.dart';
import 'package:flind_player/data/providers/cache_providers.dart';
import 'package:flind_player/features/library/library_view_provider.dart';

class _FakeSettings implements SettingsRepository {
  LibraryViews _views = LibraryViews.defaults;

  @override
  Future<LibraryViews> libraryViews() async => _views;

  @override
  Future<void> setLibraryView(LibraryViewScope scope, LibraryView view) async {
    _views = _views.withView(scope, view);
  }

  @override
  Future<CacheSettings> cacheSettings() async => CacheSettings.defaults;
  @override
  Future<void> updateCacheSettings(CacheSettings settings) async {}
  @override
  Stream<CacheSettings> watchCacheSettings() => const Stream.empty();
  @override
  Future<TrackSort> librarySort() async => TrackSort.recentlyAdded;
  @override
  Future<void> setLibrarySort(TrackSort sort) async {}
  @override
  Future<AppLanguage> appLanguage() async => AppLanguage.system;
  @override
  Future<void> setAppLanguage(AppLanguage language) async {}
  @override
  Future<AppThemeMode> appThemeMode() async => AppThemeMode.system;
  @override
  Future<void> setAppThemeMode(AppThemeMode mode) async {}
}

void main() {
  test('build reads the persisted views', () async {
    final container = ProviderContainer(
      overrides: [settingsRepositoryProvider.overrideWithValue(_FakeSettings())],
    );
    addTearDown(container.dispose);

    final views = await container.read(libraryViewsProvider.future);
    expect(views.viewOf(LibraryViewScope.all), LibraryView.waterfall);
  });

  test('setView persists and emits the new value', () async {
    final fake = _FakeSettings();
    final container = ProviderContainer(
      overrides: [settingsRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    await container.read(libraryViewsProvider.future);
    await container
        .read(libraryViewsProvider.notifier)
        .setView(LibraryViewScope.all, LibraryView.list);

    final views = container.read(libraryViewsProvider).value!;
    expect(views.viewOf(LibraryViewScope.all), LibraryView.list);
  });

  test('setView sanitizes an unsupported choice', () async {
    final container = ProviderContainer(
      overrides: [settingsRepositoryProvider.overrideWithValue(_FakeSettings())],
    );
    addTearDown(container.dispose);

    await container.read(libraryViewsProvider.future);
    await container
        .read(libraryViewsProvider.notifier)
        .setView(LibraryViewScope.playlists, LibraryView.waterfall);

    final views = container.read(libraryViewsProvider).value!;
    expect(views.viewOf(LibraryViewScope.playlists), LibraryView.showcase);
  });
}
```

Add the missing imports the fake needs at the top of the test file:

```dart
import 'package:flind_player/core/models/app_language.dart';
import 'package:flind_player/core/models/app_theme_mode.dart';
import 'package:flind_player/core/models/track_sort.dart';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/library_view_provider_test.dart`
Expected: FAIL — `library_view_provider.dart` not found.

- [ ] **Step 3: Write minimal implementation**

Create `lib/features/library/library_view_provider.dart`:

```dart
// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flind_player/core/models/library_view.dart';
import 'package:flind_player/data/providers/cache_providers.dart';

/// Persisted per-scope library views, seeded from [SettingsRepository].
class LibraryViewsNotifier extends AsyncNotifier<LibraryViews> {
  @override
  Future<LibraryViews> build() async {
    return ref.watch(settingsRepositoryProvider).libraryViews();
  }

  /// Persists [view] for [scope] and emits the updated set.
  Future<void> setView(LibraryViewScope scope, LibraryView view) async {
    final repository = ref.read(settingsRepositoryProvider);
    final sanitized = scope.sanitize(view);
    await repository.setLibraryView(scope, sanitized);
    final current = state.value ?? LibraryViews.defaults;
    state = AsyncData(current.withView(scope, sanitized));
  }
}

/// The user's chosen view for every library scope.
final libraryViewsProvider =
    AsyncNotifierProvider<LibraryViewsNotifier, LibraryViews>(
      LibraryViewsNotifier.new,
    );
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/library_view_provider_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/library/library_view_provider.dart test/library_view_provider_test.dart
git commit -m "feat(library): add libraryViews provider"
```

---

### Task 4: 排序默认值改为「最近添加」

**Files:**
- Modify: `lib/data/repositories/prefs_settings_repository.dart:95-105`
- Modify: `lib/data/providers/library_providers.dart:47`
- Modify: `lib/features/library/library_screen.dart:373,708`
- Modify: `lib/core/models/track_sort.dart:20-24`
- Modify: `test/prefs_settings_repository_test.dart`（新增用例）

**Interfaces:**
- Produces: `TrackSort.recentlyAdded` 成为宿主默认排序。

- [ ] **Step 1: Write the failing test**

Append to `test/prefs_settings_repository_test.dart`:

```dart
  test('librarySort defaults to recentlyAdded', () async {
    final repository = PrefsSettingsRepository();
    addTearDown(repository.dispose);

    expect(await repository.librarySort(), TrackSort.recentlyAdded);
  });
```

Add `import 'package:flind_player/core/models/track_sort.dart';` at the top.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/prefs_settings_repository_test.dart`
Expected: FAIL — value is `TrackSort.title`.

- [ ] **Step 3: Change the defaults**

In `lib/data/repositories/prefs_settings_repository.dart` (`librarySort`):

```dart
      if (name == null) return TrackSort.recentlyAdded;
      return TrackSort.values.asNameMap()[name] ?? TrackSort.recentlyAdded;
```

and in the catch:

```dart
      return TrackSort.recentlyAdded;
```

In `lib/data/providers/library_providers.dart:47`:

```dart
  final sort = ref.watch(librarySortProvider).value ?? TrackSort.recentlyAdded;
```

In `lib/features/library/library_screen.dart` replace both `?? TrackSort.title` with `?? TrackSort.recentlyAdded` (lines ~373 in `_buildHeaderRow`, ~708 in `_buildFavouritesBody`).

In `lib/core/models/track_sort.dart`, move the "default" note: change the `title` doc to `/// Title, case-insensitive A -> Z.` and the `recentlyAdded` doc to `/// Most recently added first (`createdAt` descending). The default.`

Also update the doc on `SettingsRepository.librarySort` to say "falling back to [TrackSort.recentlyAdded]".

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/prefs_settings_repository_test.dart test/library_screen_test.dart test/favorites_ui_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/data/repositories/prefs_settings_repository.dart \
  lib/data/providers/library_providers.dart \
  lib/features/library/library_screen.dart \
  lib/core/models/track_sort.dart \
  lib/core/repositories/settings_repository.dart \
  test/prefs_settings_repository_test.dart
git commit -m "feat(library): default sort order to recently added"
```

---

### Task 5: 离线缓存两态（+ 移除 `cachedUnpinned`）

**Files:**
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`
- Regenerate: `lib/l10n/app_localizations.dart`, `app_localizations_en.dart`, `app_localizations_zh.dart`
- Modify: `lib/features/library/widgets/track_actions_button.dart`
- Modify: `test/library_screen_test.dart:394-408`
- Modify: `test/library_view_provider_test.dart`（无需改动）

**Interfaces:**
- Produces: `AppLocalizations.cacheOffline`；行内缓存项两态且已缓存不可点击。

- [ ] **Step 1: Write the failing test**

Replace the `'online track actions menu has cache option'` test in `test/library_screen_test.dart` with:

```dart
  testWidgets('uncached online track shows the offline-cache action', (
    tester,
  ) async {
    await tester.pumpWidget(_app(tracks: [_biliTrack('Online Song')]));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TrackActionsButton));
    await tester.pumpAndSettle();

    expect(find.text('离线缓存'), findsOneWidget);
    expect(find.text('已缓存'), findsNothing);
  });

  testWidgets('cached online track shows a disabled cached label', (
    tester,
  ) async {
    final track = _biliTrack('Online Song');
    await tester.pumpWidget(
      _app(
        tracks: [track],
        cacheEntry: (ref, t) async => CachedAudio(
          id: 1,
          source: t.source,
          sourceTrackId: 'BV_Online Song:-1',
          filePath: '/cache/audio.m4a',
          bytes: 1024,
          qualityId: 'q',
          pinned: false,
          cachedAt: DateTime(2026),
          lastAccessedAt: DateTime(2026),
          coverBytes: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TrackActionsButton));
    await tester.pumpAndSettle();

    expect(find.text('已缓存'), findsOneWidget);
    expect(find.text('离线缓存'), findsNothing);
    // `_TrackAction` is private to the widget, so erase the type argument.
    final item = tester.widget<PopupMenuItem<dynamic>>(
      find.ancestor(
        of: find.text('已缓存'),
        matching: find.byType(PopupMenuItem),
      ),
    );
    expect(item.enabled, isFalse);
  });
```

`_app` must learn an optional `cacheEntry` override. Change the signature in `test/library_screen_test.dart:148-181`:

```dart
Widget _app({
  List<Track> tracks = const <Track>[],
  List<Track> favourites = const <Track>[],
  LibrarySyncState syncState = LibrarySyncState.idle,
  FutureOr<List<Track>> Function(Ref ref, String query)? search,
  Stream<DownloadProgress> progress = const Stream<DownloadProgress>.empty(),
  TrackSort sort = TrackSort.title,
  Future<CachedAudio?> Function(Ref ref, Track track)? cacheEntry,
}) {
  final favRepo = _InMemoryFavoritesRepository();
  for (final track in favourites) {
    favRepo.toggleFavorite(track);
  }
  return ProviderScope(
    overrides: [
      libraryTracksProvider.overrideWith((ref) => Stream.value(tracks)),
      playbackStateProvider.overrideWith(
        (ref) => Stream.value(PlaybackState.idle),
      ),
      librarySyncStateProvider.overrideWith((ref) => Stream.value(syncState)),
      downloadProgressProvider.overrideWith((ref) => progress),
      audioCacheEntryProvider.overrideWith(
        cacheEntry ?? (ref, track) async => null,
      ),
      favoritesRepositoryProvider.overrideWithValue(favRepo),
      favoritesProvider.overrideWith((ref) => favRepo.watchFavorites()),
      librarySortProvider.overrideWith(() => _FakeLibrarySortNotifier(sort)),
      if (search != null) librarySearchProvider.overrideWith(search),
    ],
    child: localizedApp(
      MediaQuery(
        data: const MediaQueryData(size: Size(400, 800)),
        child: const LibraryScreen(),
      ),
    ),
  );
}
```

Add `import 'package:flind_player/data/cache/audio_cache_store.dart';` to the test.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/library_screen_test.dart`
Expected: FAIL — text is 「缓存到本地」/「已缓存（未固定）」.

- [ ] **Step 3: Add/remove l10n keys**

In `lib/l10n/app_zh.arb` replace line:

```json
  "cachedUnpinned": "已缓存（未固定）",
```

with:

```json
  "cacheOffline": "离线缓存",
```

In `lib/l10n/app_en.arb` replace:

```json
  "cachedUnpinned": "Cached (not pinned)",
```

with:

```json
  "cacheOffline": "Download",
```

Then run `flutter gen-l10n`.

- [ ] **Step 4: Implement the two states**

In `lib/features/library/widgets/track_actions_button.dart`, add an (as-yet unused) plumbing field so later tasks can pass it without a forward reference:

```dart
  const TrackActionsButton({
    super.key,
    required this.track,
    this.showSaveToLibrary = false,
    this.onSaveToLibrary,
    this.playlistId,
    this.showDeleteTrack = false,
  });

  // ... existing fields ...
  /// Whether to show the "删除歌曲" menu item (added in Task 14).
  final bool showDeleteTrack;
```

Then replace the cache `PopupMenuItem` block and delete `_cacheIcon`/`_cacheLabel`:

```dart
        if (!isLocal)
          PopupMenuItem<_TrackAction>(
            value: _TrackAction.cache,
            enabled: cacheEntry == null,
            child: Row(
              children: [
                Icon(
                  cacheEntry == null
                      ? Icons.download_outlined
                      : Icons.download_done,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(cacheEntry == null ? l10n.cacheOffline : l10n.cached),
              ],
            ),
          ),
```

Remove the now-unused `import 'package:flind_player/data/cache/audio_cache_store.dart';` if `CachedAudio` is no longer referenced by name (it is not: only `cacheEntry == null`).

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/library_screen_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/l10n lib/features/library/widgets/track_actions_button.dart test/library_screen_test.dart
git commit -m "feat(library): collapse offline-cache row to two states"
```

---

### Task 6: 顶部「更多」菜单改为二级菜单（本地 / 排序 / 视图）

**Files:**
- Modify: `lib/features/library/library_screen.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`（新增 `menuLocal`/`menuSort`/`menuView`/`viewShowcase`/`viewList`/`viewWaterfall`）
- Regenerate l10n
- Modify: `test/library_screen_test.dart`

**Interfaces:**
- Consumes: `libraryViewsProvider`（Task 3）、`LibraryViewScope`/`LibraryView`（Task 1）。
- Produces: `_LibraryScreenState._scopeForSection(LibrarySection) → LibraryViewScope`、顶层函数 `String _viewLabel(AppLocalizations, LibraryView)`。

- [ ] **Step 1: Write the failing test**

Replace `'the header row shows the selector and two icons'` and `'under iOS ...'` menu assertions in `test/library_screen_test.dart`, and add:

```dart
  testWidgets('the more menu exposes local, sort and view submenus', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        tracks: [
          _track('Alpha', id: 1),
          _biliTrack('Online', id: 2),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('library_more_menu')));
    await tester.pumpAndSettle();

    expect(find.text('本地'), findsOneWidget);
    expect(find.text('排序'), findsOneWidget);
    expect(find.text('视图'), findsOneWidget);

    await tester.tap(find.text('本地'));
    await tester.pumpAndSettle();
    expect(find.text('添加文件夹'), findsOneWidget);
    expect(find.text('重新扫描'), findsOneWidget);
    expect(find.text('导入文件'), findsOneWidget);
  });

  testWidgets('the view submenu on 全部 offers all three views', (
    tester,
  ) async {
    await tester.pumpWidget(_app(tracks: [_track('Alpha', id: 1)]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('library_more_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('视图'));
    await tester.pumpAndSettle();

    expect(find.text('展柜视图'), findsOneWidget);
    expect(find.text('列表视图'), findsOneWidget);
    expect(find.text('瀑布流视图'), findsOneWidget);
  });

  testWidgets('the more menu does not overflow at 400 px', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(tracks: [_track('Alpha', id: 1)]));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library_more_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('排序'));
    await tester.pumpAndSettle();

    expect(find.text('最近添加'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sync-disabled local actions are not tappable', (tester) async {
    await tester.pumpWidget(
      _app(
        tracks: [_track('Alpha', id: 1)],
        syncState: const LibrarySyncState(
          phase: LibrarySyncPhase.scanning,
          discovered: 1,
          processed: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library_more_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('本地'));
    await tester.pumpAndSettle();

    final addFolder = tester.widget<MenuItemButton>(
      find.ancestor(of: find.text('添加文件夹'), matching: find.byType(MenuItemButton)),
    );
    expect(addFolder.onPressed, isNull);
  });
```

Add `import 'package:flutter/material.dart';` already present. `MenuItemButton` is from material.

Also `_app` must override `libraryViewsProvider` so tests don't hit `SharedPreferences`. Add to overrides in `_app`:

```dart
      libraryViewsProvider.overrideWith(_FakeLibraryViewsNotifier.new),
```

and at the bottom of the test file:

```dart
class _FakeLibraryViewsNotifier extends LibraryViewsNotifier {
  @override
  Future<LibraryViews> build() async => LibraryViews.defaults;
}
```

with `import 'package:flind_player/core/models/library_view.dart';` and `import 'package:flind_player/features/library/library_view_provider.dart';`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/library_screen_test.dart`
Expected: FAIL — `library_more_menu` is still a `PopupMenuButton`; no 「本地」.

- [ ] **Step 3: Add l10n keys**

Add to both arb files (after `tabPlaylists`):

```json
  "menuLocal": "本地",
  "menuSort": "排序",
  "menuView": "视图",
  "viewShowcase": "展柜视图",
  "viewList": "列表视图",
  "viewWaterfall": "瀑布流视图",
```

English:

```json
  "menuLocal": "Local",
  "menuSort": "Sort",
  "menuView": "View",
  "viewShowcase": "Showcase view",
  "viewList": "List view",
  "viewWaterfall": "Waterfall view",
```

Run `flutter gen-l10n`.

- [ ] **Step 4: Implement the menu**

In `lib/features/library/library_screen.dart`:

1. Add imports: `import 'package:flind_player/core/models/library_view.dart';`, `import 'package:flind_player/features/library/library_view_provider.dart';`.
2. Delete `enum _LibraryAction { ... }` (lines 46-64) and `Future<void> _onAction(...)` (lines 152-171).
3. Add a controller field and dispose:
   ```dart
   final MenuController _menuController = MenuController();
   ```
   and in `dispose()`: `_menuController.dispose();`
4. Replace the `Align(alignment: centerLeft, child: PopupMenuButton<_LibraryAction>(...))` block in `_buildHeaderRow` with:
   ```dart
               Align(
                 alignment: Alignment.centerLeft,
                 child: _buildMoreMenu(
                   hasLocalLibrary: hasLocalLibrary,
                   isSyncing: isSyncing,
                   currentSort: currentSort,
                 ),
               ),
   ```
5. Add the builder + helpers (as methods of `_LibraryScreenState`):
   ```dart
   static LibraryViewScope _scopeForSection(LibrarySection section) =>
       switch (section) {
         LibrarySection.all => LibraryViewScope.all,
         LibrarySection.favorites => LibraryViewScope.favorites,
         LibrarySection.playlists => LibraryViewScope.playlists,
       };

   Widget _buildMoreMenu({
     required bool hasLocalLibrary,
     required bool isSyncing,
     required TrackSort currentSort,
   }) {
     final l10n = AppLocalizations.of(context);
     final scope = _scopeForSection(_section);
     final views =
         ref.watch(libraryViewsProvider).value ?? LibraryViews.defaults;
     final currentView = views.viewOf(scope);

     return MenuAnchor(
       controller: _menuController,
       menuChildren: <Widget>[
         if (hasLocalLibrary)
           SubmenuButton(
             menuChildren: <Widget>[
               MenuItemButton(
                 leadingIcon: const Icon(Icons.create_new_folder_outlined),
                 onPressed: isSyncing
                     ? null
                     : () {
                         _menuController.close();
                         unawaited(_addFolder());
                       },
                 child: Text(l10n.addFolder),
               ),
               MenuItemButton(
                 leadingIcon: const Icon(Icons.refresh),
                 onPressed: isSyncing
                     ? null
                     : () {
                         _menuController.close();
                         _startSync();
                       },
                 child: Text(l10n.rescan),
               ),
               MenuItemButton(
                 leadingIcon: const Icon(Icons.add),
                 onPressed: () {
                   _menuController.close();
                   unawaited(_importFiles());
                 },
                 child: Text(l10n.importFiles),
               ),
             ],
             child: Text(l10n.menuLocal),
           ),
         SubmenuButton(
           menuChildren: <Widget>[
             for (final sort in TrackSort.values)
               MenuItemButton(
                 leadingIcon: sort == currentSort ? const Icon(Icons.check) : null,
                 onPressed: () {
                   _menuController.close();
                   unawaited(
                     ref.read(librarySortProvider.notifier).setSort(sort),
                   );
                 },
                 child: Text(_sortLabel(l10n, sort)),
               ),
           ],
           child: Text(l10n.menuSort),
         ),
         SubmenuButton(
           menuChildren: <Widget>[
             for (final view in scope.allowedViews)
               MenuItemButton(
                 leadingIcon: view == currentView ? const Icon(Icons.check) : null,
                 onPressed: () {
                   _menuController.close();
                   unawaited(
                     ref.read(libraryViewsProvider.notifier).setView(scope, view),
                   );
                 },
                 child: Text(_viewLabel(l10n, view)),
               ),
           ],
           child: Text(l10n.menuView),
         ),
         MenuItemButton(
           leadingIcon: const Icon(Icons.cloud_outlined),
           onPressed: () {
             _menuController.close();
             unawaited(_openBilibiliFavorites());
           },
           child: Text(l10n.browseBiliFavorites),
         ),
       ],
       builder: (context, controller, child) => IconButton(
         key: const Key('library_more_menu'),
         tooltip: '',
         icon: const Icon(Icons.more_vert),
         onPressed: () =>
             controller.isOpen ? controller.close() : controller.open(),
       ),
     );
   }
   ```
6. Delete `_SortRow` (lines ~918-939). Keep `String _sortLabel(...)`.
7. Add a top-level function next to `_sortLabel`:
   ```dart
   String _viewLabel(AppLocalizations l10n, LibraryView view) => switch (view) {
     LibraryView.showcase => l10n.viewShowcase,
     LibraryView.list => l10n.viewList,
     LibraryView.waterfall => l10n.viewWaterfall,
   };
   ```
8. Update the header-reservation comment/right side so the selector centring math matches the new right side (temporary: right reserved stays `48 + (hasLocalLibrary ? 96 : 48) + 8` until Task 7; Task 7 adjusts it).

- [ ] **Step 5: Update the existing header/iOS tests**

- `'the header row shows the selector and two icons'` → assert `find.byKey(const Key('library_more_menu'))` and `find.byIcon(Icons.search)` (still present until Task 7) but **not** `PopupMenuButton`.
- `'under iOS ...'` → replace the `PopupMenuButton` predicate with `find.byKey(const Key('library_more_menu'))`; after opening the menu, the local submenu is absent (no 「本地」), and 「浏览 B 站收藏夹」 is present.

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/library_screen_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/l10n lib/features/library/library_screen.dart test/library_screen_test.dart
git commit -m "feat(library): restructure overflow menu into submenus"
```

---

### Task 7: 搜索与新建歌单按页面收窄

**Files:**
- Modify: `lib/features/library/library_screen.dart`
- Modify: `lib/features/library/widgets/playlists_section.dart`（移除 `query`）
- Modify: `test/library_screen_test.dart`
- Modify: `test/playlist_ui_test.dart`（若引用了搜索）

**Interfaces:**
- Consumes: 无新增。
- Produces: `PlaylistsSection({required VoidCallback onOpenFavorites})`（删除 `query` 字段）。

- [ ] **Step 1: Write the failing tests**

In `test/library_screen_test.dart`:

```dart
  testWidgets('the search field is always visible on 全部', (tester) async {
    await tester.pumpWidget(_app(tracks: [_track('Alpha', id: 1)]));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.search), findsNothing); // no toggle button
  });

  testWidgets('the search field is hidden on 收藏 and 歌单', (tester) async {
    await tester.pumpWidget(_app(tracks: [_track('Alpha', id: 1)]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('收藏'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('歌单'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('the new-playlist button is only shown on 歌单', (tester) async {
    await tester.pumpWidget(_app(tracks: [_track('Alpha', id: 1)]));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('library_add_playlist')), findsNothing);

    await tester.tap(find.text('歌单'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('library_add_playlist')), findsOneWidget);
  });

  testWidgets('a query is retained when leaving and returning to 全部', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        tracks: [_track('Local Song', id: 1)],
        search: (ref, query) async =>
            query == 'Hit' ? <Track>[_biliTrack('Search Hit')] : <Track>[],
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Hit');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('Search Hit'), findsOneWidget);

    await tester.tap(find.text('收藏'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('全部'));
    await tester.pumpAndSettle();
    expect(find.text('Search Hit'), findsOneWidget);
  });
```

Delete the obsolete tests that toggle search or search favourites: `'typing a query shows search results and hides the full list'` (rewrite without `_openSearch`), `'a search with no matches ...'`, `'favourites filter with search ...'`, `'favourites filter with search and no matches ...'`, and remove the `_openSearch` helper. The retained search tests just `enterText` on the always-visible field.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/library_screen_test.dart`
Expected: FAIL — search field hidden until toggled; `+` always shown.

- [ ] **Step 3: Implement**

In `lib/features/library/library_screen.dart`:

1. Remove `bool _searchOpen = false;`, `_toggleSearch()`, and the search `IconButton` (key `library_search_button`). Keep `_searchController`, `_query`, `_onSearchChanged`, `_clearSearch`.
2. In `build`, change `if (hasLocalLibrary) _buildSearchField(),` to:
   ```dart
   if (hasLocalLibrary && _section == LibrarySection.all) _buildSearchField(),
   ```
3. In `_buildSearchField`, drop the `_searchOpen` branch and the `AnimatedSize`; return the `Padding(child: ValueListenableBuilder(...))` directly. Fix `hintText` to `l10n.searchLibrary`.
4. In the header's right `Align`, replace the `Row(children: [...search, add...])` with:
   ```dart
                   Align(
                     alignment: Alignment.centerRight,
                     child: _section == LibrarySection.playlists
                         ? IconButton(
                             key: const Key('library_add_playlist'),
                             tooltip: '',
                             icon: const Icon(Icons.add),
                             onPressed: _createPlaylist,
                           )
                         : const SizedBox.shrink(),
                   ),
   ```
5. Update the reservation math:
   ```dart
   final rightReserved =
       _section == LibrarySection.playlists ? 48.0 : 0.0;
   final reserved = 48.0 + rightReserved + 8.0;
   ```
6. In `_buildSectionBody`, remove `query: _query` from `PlaylistsSection(...)`; in `_buildFavouritesBody`, remove the `if (_query.isNotEmpty) { ... }` filtering block (keep the plain `_trackDisplay(sorted, ...)`); delete `_NoFavouritesSearchResults` (lines ~1126-1159).

In `lib/features/library/widgets/playlists_section.dart`, delete the `query` field/param and the `filtered` computation; iterate `custom` directly.

In `test/playlist_ui_test.dart`, if a test taps search from the playlists page, update it to not do so (search is gone there).

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/library_screen_test.dart test/playlist_ui_test.dart test/favorites_ui_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/library/library_screen.dart lib/features/library/widgets/playlists_section.dart \
  test/library_screen_test.dart test/playlist_ui_test.dart test/favorites_ui_test.dart
git commit -m "feat(library): scope search to 全部 and new-playlist to 歌单"
```

---

### Task 8: 瀑布流卡片（依赖 + 宽高比 provider + 卡片）

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/features/library/cover_aspect_ratio_provider.dart`
- Create: `lib/features/library/widgets/waterfall_track_card.dart`
- Test: `test/waterfall_track_card_test.dart`

**Interfaces:**
- Consumes: `TrackCover`（`lib/features/library/widgets/track_list_items.dart`）、`TrackActionsButton`。
- Produces:
  - `final coverAspectRatioProvider = FutureProvider.family<double, String>`
  - `class WaterfallTrackCard extends ConsumerWidget`

- [ ] **Step 1: Add the dependency**

Run: `flutter pub add flutter_staggered_grid_view`
Expected: `pubspec.yaml` gains the dependency and `pubspec.lock` updates.

（若离线拉取失败：跳过本依赖，改为在 `TrackView` 中用 `CustomScrollView` + 两列 `Column` 自排；本任务其余代码不变。）

- [ ] **Step 2: Write the failing test**

Create `test/waterfall_track_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/providers/persistence_providers.dart';
import 'package:flind_player/features/library/cover_aspect_ratio_provider.dart';
import 'package:flind_player/features/library/widgets/cache_action_button.dart';
import 'package:flind_player/features/library/widgets/waterfall_track_card.dart';

import 'support/l10n.dart';

Track _track({String? coverPath}) => Track(
  id: 1,
  source: 'local',
  sourceTrackId: LocalTrackId('/music/a.mp3'),
  uri: 'local:/music/a.mp3',
  title: 'Alpha',
  artist: 'Artist A',
  coverPath: coverPath,
);

/// The card embeds `TrackActionsButton`, which watches favourites + cache.
List<Override> get _childOverrides => [
  isFavoriteProvider.overrideWith((ref, uri) async => false),
  audioCacheEntryProvider.overrideWith((ref, track) async => null),
];

void main() {
  testWidgets('cover height follows the resolved aspect ratio', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._childOverrides,
          coverAspectRatioProvider.overrideWith((ref, key) async => 0.5),
        ],
        child: localizedApp(
          Scaffold(
            body: SizedBox(
              width: 200,
              child: WaterfallTrackCard(
                track: _track(coverPath: '/covers/a.jpg'),
                isCurrent: false,
                isPlaying: false,
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AspectRatio), findsOneWidget);
    final aspect = tester.widget<AspectRatio>(find.byType(AspectRatio));
    expect(aspect.aspectRatio, 0.5);
  });

  testWidgets('an unresolvable cover falls back to 1:1 without throwing', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _childOverrides,
        child: localizedApp(
          Scaffold(
            body: SizedBox(
              width: 200,
              child: WaterfallTrackCard(
                track: _track(coverPath: '/missing/never.jpg'),
                isCurrent: false,
                isPlaying: false,
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final aspect = tester.widget<AspectRatio>(find.byType(AspectRatio));
    expect(aspect.aspectRatio, 1.0);
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/waterfall_track_card_test.dart`
Expected: FAIL — files not found.

- [ ] **Step 4: Implement the aspect-ratio provider**

Create `lib/features/library/cover_aspect_ratio_provider.dart`:

```dart
// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.

import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Resolves the width/height ratio of a cover (`path` or `http` URL).
///
/// Reuses Flutter's image cache through the matching [ImageProvider], so the
/// waterfall card's own image load is not duplicated. Falls back to `1.0` for
/// a missing or undecodable image and caches the resolved value per key.
final coverAspectRatioProvider = FutureProvider.family<double, String>((
  ref,
  source,
) async {
  if (source.isEmpty) return 1.0;
  final ImageProvider<Object> provider = source.startsWith('http')
      ? NetworkImage(source)
      : FileImage(File(source));

  final completer = Completer<double>();
  final stream = provider.resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      if (!completer.isCompleted) {
        final height = info.image.height;
        completer.complete(height == 0 ? 1.0 : info.image.width / height);
      }
    },
    onError: (error, stackTrace) {
      if (!completer.isCompleted) completer.complete(1.0);
    },
  );
  stream.addListener(listener);
  ref.onDispose(() => stream.removeListener(listener));
  return completer.future;
});
```

- [ ] **Step 5: Implement the card**

Create `lib/features/library/widgets/waterfall_track_card.dart`:

```dart
// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/features/library/cover_aspect_ratio_provider.dart';
import 'package:flind_player/features/library/widgets/track_actions_button.dart';
import 'package:flind_player/features/library/widgets/track_list_items.dart';
import 'package:flind_player/l10n/app_localizations.dart';

/// A masonry card whose cover keeps its intrinsic aspect ratio.
class WaterfallTrackCard extends ConsumerWidget {
  const WaterfallTrackCard({
    required this.track,
    required this.isCurrent,
    required this.isPlaying,
    required this.onTap,
    this.playlistId,
    this.showDeleteTrack = false,
    this.unavailable = false,
    super.key,
  });

  final Track track;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback onTap;
  final int? playlistId;
  final bool showDeleteTrack;
  final bool unavailable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    final coverKey = (track.coverPath?.isNotEmpty ?? false)
        ? track.coverPath!
        : (track.coverUrl ?? '');
    final ratio = coverKey.isEmpty
        ? 1.0
        : (ref.watch(coverAspectRatioProvider(coverKey)).value ?? 1.0);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: unavailable ? null : onTap,
        child: Opacity(
          opacity: unavailable ? 0.55 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  AspectRatio(
                    aspectRatio: ratio,
                    child: TrackCover(track: track, size: double.infinity),
                  ),
                  if (isPlaying)
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(
                          Icons.graphic_eq,
                          size: 14,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: TrackActionsButton(
                      track: track,
                      playlistId: playlistId,
                      showDeleteTrack: showDeleteTrack,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      unavailable
                          ? l10n.trackUnavailable
                          : track.artist ?? l10n.unknownArtist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    SourceBadge(source: track.source),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

> `TrackActionsButton.showDeleteTrack` already exists as a no-op from Task 5, so `WaterfallTrackCard` compiles now; Task 14 gives it behavior.

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/waterfall_track_card_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/features/library/cover_aspect_ratio_provider.dart \
  lib/features/library/widgets/waterfall_track_card.dart test/waterfall_track_card_test.dart
git commit -m "feat(library): add waterfall track card and cover ratio provider"
```

---

### Task 9: 共享 `TrackView`（展柜 / 列表 / 瀑布流）

**Files:**
- Create: `lib/features/library/widgets/track_view.dart`
- Modify: `lib/features/library/library_screen.dart`
- Test: `test/track_view_test.dart`

**Interfaces:**
- Consumes: `WaterfallTrackCard`（Task 8）、`TrackTile`/`TrackCard`（`track_list_items.dart`）、`LibraryView`（Task 1）。
- Produces:
  - `class TrackView extends StatelessWidget`，构造：
    `TrackView({required List<Track> tracks, required LibraryView view, required String? currentUri, required bool isPlaying, required void Function(int index) onPlay, int? playlistId, bool showDeleteTrack = false})`

- [ ] **Step 1: Write the failing test**

Create `test/track_view_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/library_view.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/providers/persistence_providers.dart';
import 'package:flind_player/features/library/widgets/cache_action_button.dart';
import 'package:flind_player/features/library/widgets/track_list_items.dart';
import 'package:flind_player/features/library/widgets/track_view.dart';

import 'support/l10n.dart';

Track _track(int i) => Track(
  id: i,
  source: 'local',
  sourceTrackId: LocalTrackId('/music/$i.mp3'),
  uri: 'local:/music/$i.mp3',
  title: 'Song $i',
);

/// Rows/cards embed `TrackActionsButton`, which watches favourites + cache.
Widget _wrap(Widget child) => ProviderScope(
  overrides: [
    isFavoriteProvider.overrideWith((ref, uri) async => false),
    audioCacheEntryProvider.overrideWith((ref, track) async => null),
  ],
  child: localizedApp(Scaffold(body: child)),
);

void main() {
  testWidgets('list view renders TrackTile rows', (tester) async {
    await tester.pumpWidget(
      _wrap(
        TrackView(
          tracks: [_track(1), _track(2)],
          view: LibraryView.list,
          currentUri: null,
          isPlaying: false,
          onPlay: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TrackTile), findsNWidgets(2));
    expect(find.byType(TrackCard), findsNothing);
    expect(find.byType(MasonryGridView), findsNothing);
  });

  testWidgets('showcase view renders TrackCard grid', (tester) async {
    await tester.pumpWidget(
      _wrap(
        TrackView(
          tracks: [_track(1), _track(2)],
          view: LibraryView.showcase,
          currentUri: null,
          isPlaying: false,
          onPlay: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TrackCard), findsNWidgets(2));
    expect(find.byType(TrackTile), findsNothing);
  });

  testWidgets('waterfall view renders a MasonryGridView', (tester) async {
    await tester.pumpWidget(
      _wrap(
        TrackView(
          tracks: [_track(1), _track(2)],
          view: LibraryView.waterfall,
          currentUri: null,
          isPlaying: false,
          onPlay: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MasonryGridView), findsOneWidget);
  });

  testWidgets('onPlay reports the tapped index', (tester) async {
    final played = <int>[];
    await tester.pumpWidget(
      _wrap(
        TrackView(
          tracks: [_track(1), _track(2)],
          view: LibraryView.list,
          currentUri: null,
          isPlaying: false,
          onPlay: played.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Song 2'));
    expect(played, [1]);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/track_view_test.dart`
Expected: FAIL — `track_view.dart` not found.

- [ ] **Step 3: Implement `TrackView`**

Create `lib/features/library/widgets/track_view.dart`:

```dart
// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import 'package:flind_player/core/models/library_view.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/features/library/widgets/track_list_items.dart';
import 'package:flind_player/features/library/widgets/waterfall_track_card.dart';

/// Renders [tracks] in the layout chosen by [view].
class TrackView extends StatelessWidget {
  const TrackView({
    super.key,
    required this.tracks,
    required this.view,
    required this.currentUri,
    required this.isPlaying,
    required this.onPlay,
    this.playlistId,
    this.showDeleteTrack = false,
  });

  final List<Track> tracks;
  final LibraryView view;
  final String? currentUri;
  final bool isPlaying;
  final void Function(int index) onPlay;
  final int? playlistId;
  final bool showDeleteTrack;

  @override
  Widget build(BuildContext context) {
    return switch (view) {
      LibraryView.list => _list(),
      LibraryView.showcase => _grid(),
      LibraryView.waterfall => _waterfall(),
    };
  }

  Widget _list() {
    return ListView.builder(
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        final isCurrent = currentUri != null && track.uri == currentUri;
        return TrackTile(
          track: track,
          isCurrent: isCurrent,
          isPlaying: isCurrent && isPlaying,
          unavailable: track.id == null,
          playlistId: playlistId,
          showDeleteTrack: showDeleteTrack,
          onTap: () => onPlay(index),
        );
      },
    );
  }

  Widget _grid() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        childAspectRatio: 0.82,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        final isCurrent = currentUri != null && track.uri == currentUri;
        return TrackCard(
          track: track,
          isCurrent: isCurrent,
          isPlaying: isCurrent && isPlaying,
          unavailable: track.id == null,
          playlistId: playlistId,
          showDeleteTrack: showDeleteTrack,
          onTap: () => onPlay(index),
        );
      },
    );
  }

  Widget _waterfall() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 180).round().clamp(2, 6);
        return MasonryGridView.count(
          padding: const EdgeInsets.all(12),
          crossAxisCount: columns,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          itemCount: tracks.length,
          itemBuilder: (context, index) {
            final track = tracks[index];
            final isCurrent = currentUri != null && track.uri == currentUri;
            return WaterfallTrackCard(
              track: track,
              isCurrent: isCurrent,
              isPlaying: isCurrent && isPlaying,
              unavailable: track.id == null,
              playlistId: playlistId,
              showDeleteTrack: showDeleteTrack,
              onTap: () => onPlay(index),
            );
          },
        );
      },
    );
  }
}
```

- [ ] **Step 4: Refactor `LibraryScreen` to use `TrackView`; add `showDeleteTrack` to `TrackTile`/`TrackCard`**

In `lib/features/library/widgets/track_list_items.dart`, add `this.showDeleteTrack = false` + `final bool showDeleteTrack;` to both `TrackTile` and `TrackCard`, and forward it (`TrackActionsButton(track: track, playlistId: playlistId, showDeleteTrack: showDeleteTrack)`).

In `lib/features/library/library_screen.dart`:

1. Add `import 'package:flind_player/features/library/widgets/track_view.dart';`.
2. Change `_trackDisplay` to accept the owning section and delegate:
   ```dart
   Widget _trackDisplay(
     List<Track> tracks,
     String? currentUri,
     bool isPlaying,
     LibrarySection section,
   ) {
     final scope = _scopeForSection(section);
     final view = (ref.watch(libraryViewsProvider).value ??
             LibraryViews.defaults)
         .viewOf(scope);
     return TrackView(
       tracks: tracks,
       view: view,
       currentUri: currentUri,
       isPlaying: isPlaying,
       onPlay: (index) => _play(tracks, index),
       showDeleteTrack: true,
     );
   }
   ```
3. Update call sites: in `_buildSectionBody`, `_trackDisplay(tracks, currentUri, isPlaying)` → `_trackDisplay(tracks, currentUri, isPlaying, section)` (both the search-results and library branches; both use `section`, which is `LibrarySection.all` there). In `_buildFavouritesBody`, pass `LibrarySection.favorites`.
4. Delete `_trackList` and `_trackGrid` (lines ~751-790).

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/track_view_test.dart test/library_screen_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/library/widgets/track_view.dart lib/features/library/library_screen.dart \
  test/track_view_test.dart test/library_screen_test.dart
git commit -m "refactor(library): extract TrackView renderer for all view modes"
```

---

### Task 10: 歌单列表页视图（`PlaylistCard` + `PlaylistsSection`）

**Files:**
- Create: `lib/features/library/widgets/playlist_card.dart`
- Modify: `lib/features/library/widgets/playlists_section.dart`
- Modify: `lib/features/library/library_screen.dart`
- Test: `test/playlist_ui_test.dart`

**Interfaces:**
- Consumes: `LibraryView`（Task 1）、`playlistCoverProvider` / `playlistTracksProvider`（`playlist_providers.dart`）。
- Produces:
  - `class PlaylistCard extends ConsumerWidget`
  - `PlaylistsSection({required LibraryView view, required VoidCallback onOpenFavorites})`

- [ ] **Step 1: Write the failing test**

In `test/playlist_ui_test.dart`, add `import 'package:flind_player/features/library/widgets/playlist_card.dart';` and append a new group before the final `}` of `main()`:

```dart
  group('playlists view', () {
    testWidgets('歌单列表默认展柜，可切换为列表', (tester) async {
      _setSize(tester, 400, 800);
      final repo = _FakePlaylistRepository(
        playlists: [
          _playlist(2, 'Road Trip', PlaylistKind.custom),
          _playlist(3, 'Workout', PlaylistKind.custom),
        ],
      );

      await tester.pumpWidget(_app(playlistRepo: repo));
      await tester.pumpAndSettle();
      await _openPlaylists(tester);

      // Default for the playlists scope is showcase: favourites + 2 cards.
      expect(find.byType(PlaylistCard), findsNWidgets(3));
      expect(find.byType(ListTile), findsNothing);

      await tester.tap(find.byKey(const Key('library_more_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(testL10n().menuView));
      await tester.pumpAndSettle();
      // The playlists scope offers no waterfall.
      expect(find.text(testL10n().viewWaterfall), findsNothing);
      await tester.tap(find.text(testL10n().viewList));
      await tester.pumpAndSettle();

      expect(find.byType(PlaylistCard), findsNothing);
      expect(find.text('Road Trip'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
```

Also add the `libraryViewsProvider` override to the `_app` helper in this file (its overrides list ends with `playlistRepositoryProvider.overrideWithValue(repo)`):

```dart
      libraryViewsProvider.overrideWith(_FakeLibraryViewsNotifier.new),
```

and at the bottom:

```dart
class _FakeLibraryViewsNotifier extends LibraryViewsNotifier {
  @override
  Future<LibraryViews> build() async => LibraryViews.defaults;
}
```

with imports `import 'package:flind_player/core/models/library_view.dart';` and `import 'package:flind_player/features/library/library_view_provider.dart';`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/playlist_ui_test.dart`
Expected: FAIL — `PlaylistCard` not defined.

- [ ] **Step 3: Implement `PlaylistCard`**

Create `lib/features/library/widgets/playlist_card.dart`:

```dart
// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flind_player/data/providers/playlist_providers.dart';
import 'package:flind_player/l10n/app_localizations.dart';
import 'package:flind_player/shared/cover_image.dart';

/// One playlist as a card (cover + name + song count).
class PlaylistCard extends ConsumerWidget {
  const PlaylistCard({
    super.key,
    required this.playlistId,
    required this.name,
    required this.onTap,
    this.fallbackIcon = Icons.queue_music,
  });

  final int playlistId;
  final String name;
  final VoidCallback onTap;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final cover = ref.watch(playlistCoverProvider(playlistId)).value;
    final count = ref.watch(playlistTracksProvider(playlistId)).value?.length;
    final path = cover?.coverPath;
    final url = cover?.coverUrl;
    final hasCover =
        (path != null && path.isNotEmpty) || (url != null && url.isNotEmpty);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                color: scheme.surfaceContainerHighest,
                child: hasCover
                    ? CoverImage(
                        path: path,
                        url: url,
                        size: double.infinity,
                        errorBuilder: (context, error, stackTrace) =>
                            Icon(fallbackIcon, size: 40),
                      )
                    : Icon(fallbackIcon, size: 40),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    count == null ? '' : l10n.playlistTrackCount(count),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Add the showcase branch to `PlaylistsSection`**

In `lib/features/library/widgets/playlists_section.dart`:

1. Add `import 'package:flind_player/core/models/library_view.dart';` and `import 'package:flind_player/features/library/widgets/playlist_card.dart';`.
2. Change the constructor to `required this.view` (no `query`).
3. In `build`, branch:
   ```dart
    if (view == LibraryView.showcase) {
      return GridView.count(
        padding: const EdgeInsets.all(12),
        crossAxisCount: 2,
        childAspectRatio: 0.82,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        children: [
          PlaylistCard(
            playlistId: favoritesPlaylistId,
            name: l10n.tabFavorites,
            fallbackIcon: Icons.favorite,
            onTap: onOpenFavorites,
          ),
          for (final playlist in custom)
            PlaylistCard(
              playlistId: playlist.id,
              name: playlist.name,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) =>
                      PlaylistDetailScreen(playlistId: playlist.id),
                ),
              ),
            ),
        ],
      );
    }
    // list branch: existing ListView(favorites row + playlist rows)
   ```
   (Keep the existing list branch; make it the fall-through.)

- [ ] **Step 5: Pass the view from `LibraryScreen`**

In `_buildSectionBody`, replace the `PlaylistsSection(...)` call:

```dart
      final playlistsView =
          (ref.watch(libraryViewsProvider).value ?? LibraryViews.defaults)
              .viewOf(LibraryViewScope.playlists);
      return PlaylistsSection(
        view: playlistsView,
        onOpenFavorites: () => _selectSection(LibrarySection.favorites),
      );
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/playlist_ui_test.dart test/library_screen_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/library/widgets/playlist_card.dart lib/features/library/widgets/playlists_section.dart \
  lib/features/library/library_screen.dart test/playlist_ui_test.dart
git commit -m "feat(library): add showcase view for the playlists list"
```

---

### Task 11: 歌单详情页的视图菜单与渲染

**Files:**
- Create: `lib/features/library/widgets/library_view_menu_button.dart`
- Modify: `lib/features/library/playlist_detail_screen.dart`
- Test: `test/playlist_ui_test.dart`

**Interfaces:**
- Consumes: `libraryViewsProvider`（Task 3）、`TrackView`（Task 9）、`LibraryViewScope.playlistDetail`。
- Produces: `class LibraryViewMenuButton extends ConsumerStatefulWidget`，构造 `LibraryViewMenuButton({required LibraryViewScope scope, IconData icon = Icons.grid_view_rounded})`，key `library_view_menu`。

- [ ] **Step 1: Write the failing test**

In `test/playlist_ui_test.dart`, add `import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';` and append to the `playlists view` group:

```dart
    testWidgets('歌单详情页提供视图菜单并可切换为瀑布流', (tester) async {
      _setSize(tester, 400, 800);
      final repo = _FakePlaylistRepository(
        playlists: [_playlist(2, 'Road Trip', PlaylistKind.custom)],
        tracks: {
          2: [_track('Alpha'), _track('Beta')],
        },
      );

      await tester.pumpWidget(_app(playlistRepo: repo));
      await tester.pumpAndSettle();
      await _openPlaylists(tester);

      // Default showcase: tap the playlist card to push its detail screen.
      await tester.tap(find.text('Road Trip'));
      await tester.pumpAndSettle();

      // Detail screen default view is list.
      expect(find.byType(TrackTile), findsNWidgets(2));
      expect(find.byKey(const Key('library_view_menu')), findsOneWidget);

      await tester.tap(find.byKey(const Key('library_view_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(testL10n().viewWaterfall));
      await tester.pumpAndSettle();

      expect(find.byType(MasonryGridView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
```

Add `import 'package:flind_player/features/library/widgets/track_list_items.dart';` for `TrackTile` if not already imported.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/playlist_ui_test.dart`
Expected: FAIL — no `library_view_menu`.

- [ ] **Step 3: Implement `LibraryViewMenuButton`**

Create `lib/features/library/widgets/library_view_menu_button.dart`:

```dart
// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flind_player/core/models/library_view.dart';
import 'package:flind_player/features/library/library_view_provider.dart';
import 'package:flind_player/l10n/app_localizations.dart';

/// An AppBar button that switches the view for [scope].
class LibraryViewMenuButton extends ConsumerStatefulWidget {
  const LibraryViewMenuButton({
    super.key,
    required this.scope,
    this.icon = Icons.grid_view_rounded,
  });

  final LibraryViewScope scope;
  final IconData icon;

  @override
  ConsumerState<LibraryViewMenuButton> createState() =>
      _LibraryViewMenuButtonState();
}

class _LibraryViewMenuButtonState
    extends ConsumerState<LibraryViewMenuButton> {
  final MenuController _controller = MenuController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final views =
        ref.watch(libraryViewsProvider).value ?? LibraryViews.defaults;
    final current = views.viewOf(widget.scope);

    return MenuAnchor(
      controller: _controller,
      menuChildren: <Widget>[
        for (final view in widget.scope.allowedViews)
          MenuItemButton(
            leadingIcon: view == current ? const Icon(Icons.check) : null,
            onPressed: () {
              _controller.close();
              ref
                  .read(libraryViewsProvider.notifier)
                  .setView(widget.scope, view);
            },
            child: Text(_viewLabel(l10n, view)),
          ),
      ],
      builder: (context, controller, child) => IconButton(
        key: const Key('library_view_menu'),
        tooltip: l10n.menuView,
        icon: Icon(widget.icon),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}
```

Add the shared `_viewLabel` helper to this file (top-level, private):

```dart
String _viewLabel(AppLocalizations l10n, LibraryView view) => switch (view) {
  LibraryView.showcase => l10n.viewShowcase,
  LibraryView.list => l10n.viewList,
  LibraryView.waterfall => l10n.viewWaterfall,
};
```

- [ ] **Step 4: Wire the playlist detail screen**

In `lib/features/library/playlist_detail_screen.dart`:

1. Add imports: `import 'package:flind_player/core/models/library_view.dart';`, `import 'package:flind_player/features/library/library_view_provider.dart';`, `import 'package:flind_player/features/library/widgets/library_view_menu_button.dart';`, `import 'package:flind_player/features/library/widgets/track_view.dart';`.
2. Add to the `AppBar.actions` (after the existing actions):
   ```dart
          const LibraryViewMenuButton(
            scope: LibraryViewScope.playlistDetail,
          ),
   ```
3. Replace `_memberList(ref, tracks)` with a view-driven renderer:
   ```dart
   Widget _memberList(WidgetRef ref, List<Track> tracks) {
     final view =
         (ref.watch(libraryViewsProvider).value ?? LibraryViews.defaults)
             .viewOf(LibraryViewScope.playlistDetail);
     return TrackView(
       tracks: tracks,
       view: view,
       currentUri: null,
       isPlaying: false,
       onPlay: (index) => _play(ref, tracks, index),
       playlistId: playlistId,
       showDeleteTrack: true,
     );
   }
   ```
   Delete the existing `LayoutBuilder`/`GridView`/`ListView` body of `_memberList`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/playlist_ui_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/library/widgets/library_view_menu_button.dart \
  lib/features/library/playlist_detail_screen.dart test/playlist_ui_test.dart
git commit -m "feat(library): add view menu to playlist detail"
```

---

### Task 12: `removeTrackFromAllPlaylists`

**Files:**
- Modify: `lib/core/repositories/playlist_repository.dart`
- Modify: `lib/data/repositories/drift_playlist_repository.dart`
- Modify: `test/playlist_ui_test.dart:143`（`_FakePlaylistRepository`）
- Test: `test/playlist_repository_test.dart`

**Interfaces:**
- Produces: `PlaylistRepository.removeTrackFromAllPlaylists(String uri) → Future<void>`

- [ ] **Step 1: Write the failing test**

Append to `test/playlist_repository_test.dart` (inside `main`, after the member tests):

```dart
  test('removeTrackFromAllPlaylists drops the uri everywhere', () async {
    final a = await repository.createPlaylist(name: 'A');
    final b = await repository.createPlaylist(name: 'B');
    final track = localTrack(path: '/music/shared.flac');
    await repository.addTrack(a.id, track);
    await repository.addTrack(b.id, track);
    await repository.addTrack(favoritesPlaylistId, track);

    await repository.removeTrackFromAllPlaylists(track.uri);

    expect(await repository.containsTrack(a.id, track.uri), isFalse);
    expect(await repository.containsTrack(b.id, track.uri), isFalse);
    expect(
      await repository.containsTrack(favoritesPlaylistId, track.uri),
      isFalse,
    );
    // The pool row is untouched.
    expect(await repository.playlistTracks(a.id), isEmpty);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/playlist_repository_test.dart`
Expected: FAIL — `removeTrackFromAllPlaylists` undefined.

- [ ] **Step 3: Implement**

In `lib/core/repositories/playlist_repository.dart`, after `removeTrack`:

```dart
  /// Removes the member with [uri] from every playlist (including the built-in
  /// favourites). The pool row is left untouched.
  Future<void> removeTrackFromAllPlaylists(String uri);
```

In `lib/data/repositories/drift_playlist_repository.dart`:

```dart
  @override
  Future<void> removeTrackFromAllPlaylists(String uri) async {
    await (_db.delete(_db.playlistTracks)..where((pt) => pt.uri.equals(uri)))
        .go();
  }
```

In `test/playlist_ui_test.dart`, add to `_FakePlaylistRepository` (mirror the existing `removeTrack` style and emit updated streams):

```dart
  @override
  Future<void> removeTrackFromAllPlaylists(String uri) async {
    for (final entry in _tracks.entries) {
      entry.value.removeWhere((track) => track.uri == uri);
      _trackController(entry.key).add(List.unmodifiable(entry.value));
    }
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/playlist_repository_test.dart test/playlist_ui_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/repositories/playlist_repository.dart \
  lib/data/repositories/drift_playlist_repository.dart \
  test/playlist_repository_test.dart test/playlist_ui_test.dart
git commit -m "feat(playlist): remove a track from all playlists"
```

---

### Task 13: `TrackDeletionService`

**Files:**
- Create: `lib/data/services/track_deletion_service.dart`
- Create: `lib/data/providers/deletion_providers.dart`
- Test: `test/track_deletion_service_test.dart`

**Interfaces:**
- Consumes: `AudioCacheStore.lookup/remove`、`PlaylistRepository.removeTrackFromAllPlaylists`（Task 12）、`MusicLibraryRepository.deleteTrack`、`cacheSourceTrackId`（`lib/data/cache/cache_keys.dart`）。
- Produces:
  - `class TrackDeletionService`，含 `deleteEverywhere(Track track) → Future<void>`
  - `final trackDeletionServiceProvider = Provider<TrackDeletionService>(...)`

- [ ] **Step 1: Write the failing test**

Create `test/track_deletion_service_test.dart`:

```dart
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/app_language.dart';
import 'package:flind_player/core/models/app_theme_mode.dart';
import 'package:flind_player/core/models/library_view.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/models/track_sort.dart';
import 'package:flind_player/core/repositories/settings_repository.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/cache/audio_cache_store.dart';
import 'package:flind_player/data/database/app_database.dart';
import 'package:flind_player/data/database/playlist_defaults.dart';
import 'package:flind_player/data/repositories/drift_music_library_repository.dart';
import 'package:flind_player/data/repositories/drift_playlist_repository.dart';
import 'package:flind_player/data/services/track_deletion_service.dart';

class _NoopSettings implements SettingsRepository {
  @override
  Future<CacheSettings> cacheSettings() async => CacheSettings.defaults;
  @override
  Future<void> updateCacheSettings(CacheSettings settings) async {}
  @override
  Stream<CacheSettings> watchCacheSettings() => const Stream.empty();
  @override
  Future<TrackSort> librarySort() async => TrackSort.recentlyAdded;
  @override
  Future<void> setLibrarySort(TrackSort sort) async {}
  @override
  Future<LibraryViews> libraryViews() async => LibraryViews.defaults;
  @override
  Future<void> setLibraryView(LibraryViewScope scope, LibraryView view) async {}
  @override
  Future<AppLanguage> appLanguage() async => AppLanguage.system;
  @override
  Future<void> setAppLanguage(AppLanguage language) async {}
  @override
  Future<AppThemeMode> appThemeMode() async => AppThemeMode.system;
  @override
  Future<void> setAppThemeMode(AppThemeMode mode) async {}
}

Track _track({int? id}) => Track(
  id: id,
  source: 'local',
  sourceTrackId: LocalTrackId('/music/a.mp3'),
  uri: 'local:/music/a.mp3',
  title: 'Alpha',
);

void main() {
  late AppDatabase db;
  late Directory cacheDir;
  late AudioCacheStore cache;
  late DriftMusicLibraryRepository library;
  late DriftPlaylistRepository playlists;
  late TrackDeletionService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    cacheDir = Directory.systemTemp.createTempSync('deletion_test');
    cache = AudioCacheStore(
      database: db,
      baseDir: cacheDir,
      settings: _NoopSettings(),
    );
    library = DriftMusicLibraryRepository(db);
    playlists = DriftPlaylistRepository(db);
    service = TrackDeletionService(
      cache: cache,
      playlists: playlists,
      library: library,
    );
  });

  tearDown(() async {
    await db.close();
    if (cacheDir.existsSync()) cacheDir.deleteSync(recursive: true);
  });

  test('deletes the library row, all memberships and the cache entry',
      () async {
    final track = _track();
    final id = await library.upsertTrack(track);
    final withId = track.copyWith(id: id);
    final playlist = await playlists.createPlaylist(name: 'A');
    await playlists.addTrack(playlist.id, withId);
    await playlists.addTrack(favoritesPlaylistId, withId);

    final file = File('${cacheDir.path}/local/a.m4a')
      ..createSync(recursive: true)
      ..writeAsBytesSync([1, 2, 3]);
    await cache.insert(
      source: 'local',
      sourceTrackId: cacheSourceTrackId(withId),
      filePath: file.path,
      bytes: 3,
      qualityId: 'q',
      pinned: true,
      contentHash: 'hash-a',
    );

    await service.deleteEverywhere(withId);

    expect(await library.findByUri(withId.uri), isNull);
    expect(await playlists.containsTrack(playlist.id, withId.uri), isFalse);
    expect(await cache.lookup('local', cacheSourceTrackId(withId)), isNull);
    expect(file.existsSync(), isFalse);
  });

  test('an unavailable track (id == null) still clears memberships',
      () async {
    final track = _track();
    final playlist = await playlists.createPlaylist(name: 'A');
    await playlists.addTrack(playlist.id, track);

    await service.deleteEverywhere(track);

    expect(await playlists.containsTrack(playlist.id, track.uri), isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/track_deletion_service_test.dart`
Expected: FAIL — `track_deletion_service.dart` not found.

- [ ] **Step 3: Implement the service**

Create `lib/data/services/track_deletion_service.dart`:

```dart
// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/repositories/music_library_repository.dart';
import 'package:flind_player/core/repositories/playlist_repository.dart';
import 'package:flind_player/data/cache/audio_cache_store.dart';
import 'package:flind_player/data/cache/cache_keys.dart';

/// Permanently removes a track from the app: every playlist membership, the
/// library row and the offline cache. Local files on disk are never touched.
class TrackDeletionService {
  TrackDeletionService({
    required AudioCacheStore cache,
    required PlaylistRepository playlists,
    required MusicLibraryRepository library,
  }) : _cache = cache,
       _playlists = playlists,
       _library = library;

  final AudioCacheStore _cache;
  final PlaylistRepository _playlists;
  final MusicLibraryRepository _library;

  /// Deletes [track] from playlists, library and cache. Idempotent: a missing
  /// cache entry or library row is skipped.
  Future<void> deleteEverywhere(Track track) async {
    final entry = await _cache.lookup(track.source, cacheSourceTrackId(track));
    if (entry != null) {
      await _cache.remove(entry.id);
    }
    await _playlists.removeTrackFromAllPlaylists(track.uri);
    final id = track.id;
    if (id != null) {
      await _library.deleteTrack(id);
    }
  }
}
```

- [ ] **Step 4: Add the provider**

Create `lib/data/providers/deletion_providers.dart`:

```dart
// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flind_player/data/providers/cache_providers.dart';
import 'package:flind_player/data/providers/database_providers.dart';
import 'package:flind_player/data/providers/playlist_providers.dart';
import 'package:flind_player/data/services/track_deletion_service.dart';

/// Permanently removes a track from playlists, library and cache.
final trackDeletionServiceProvider = Provider<TrackDeletionService>(
  (ref) => TrackDeletionService(
    cache: ref.watch(audioCacheStoreProvider),
    playlists: ref.watch(playlistRepositoryProvider),
    library: ref.watch(musicLibraryRepositoryProvider),
  ),
);
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/track_deletion_service_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/data/services/track_deletion_service.dart lib/data/providers/deletion_providers.dart \
  test/track_deletion_service_test.dart
git commit -m "feat(library): add track deletion service"
```

---

### Task 14: 单曲菜单「移出歌单 / 删除歌曲」

**Files:**
- Modify: `lib/features/library/widgets/track_actions_button.dart`
- Modify: `lib/features/library/widgets/track_list_items.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`
- Regenerate l10n
- Test: `test/library_screen_test.dart`

**Interfaces:**
- Consumes: `trackDeletionServiceProvider`（Task 13）。
- Produces:
  - `TrackActionsButton.showDeleteTrack`（bool，默认 false）
  - `TrackTile.showDeleteTrack` / `TrackCard.showDeleteTrack`

- [ ] **Step 1: Add l10n keys**

In `lib/l10n/app_zh.arb`, change `"removeFromPlaylist": "从歌单移除",` to `"removeFromPlaylist": "移出歌单",` and add:

```json
  "deleteTrack": "删除歌曲",
  "deleteTrackTitle": "删除歌曲？",
  "deleteTrackBody": "将从所有歌单移除，并从曲库删除《{title}》及其离线缓存（如有）。此操作不可撤销。",
  "trackDeleted": "已删除《{title}》",
```

In `lib/l10n/app_en.arb` add:

```json
  "deleteTrack": "Delete song",
  "deleteTrackTitle": "Delete song?",
  "deleteTrackBody": "This removes \"{title}\" from every playlist, deletes it from the library, and removes its offline cache (if any). This cannot be undone.",
  "trackDeleted": "Deleted \"{title}\"",
```

Run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing tests**

Add to `test/library_screen_test.dart`:

```dart
  testWidgets('全部 track menu offers delete but not remove-from-playlist', (
    tester,
  ) async {
    await tester.pumpWidget(_app(tracks: [_track('Alpha', id: 1)]));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TrackActionsButton));
    await tester.pumpAndSettle();

    expect(find.text('删除歌曲'), findsOneWidget);
    expect(find.text('移出歌单'), findsNothing);
  });

  testWidgets('deleting asks for confirmation, then removes the row', (
    tester,
  ) async {
    final deleted = <String>[];
    await tester.pumpWidget(
      _app(
        tracks: [_track('Alpha', id: 1)],
        deleteTrack: (track) async => deleted.add(track.uri),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TrackActionsButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除歌曲'));
    await tester.pumpAndSettle();

    expect(find.text('删除歌曲？'), findsOneWidget);
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(deleted, ['local:/music/Alpha.mp3']);
  });

  testWidgets('deleting the currently playing track does not throw', (
    tester,
  ) async {
    final track = _track('Alpha', id: 1);
    await tester.pumpWidget(
      _app(
        tracks: [track],
        currentTrack: track,
        deleteTrack: (t) async {},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TrackActionsButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除歌曲'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
```

`_app` gains two parameters and the matching overrides:

```dart
  Track? currentTrack,
  Future<void> Function(Track track)? deleteTrack,
```

and in the overrides list:

```dart
      playbackStateProvider.overrideWith(
        (ref) => Stream.value(
          currentTrack == null
              ? PlaybackState.idle
              : PlaybackState.idle.copyWith(currentTrack: currentTrack),
        ),
      ),
      if (deleteTrack != null)
        trackDeletionServiceProvider.overrideWithValue(
          _FakeDeletionService(deleteTrack),
        ),
```

Add this fake at the bottom of the test file:

```dart
class _FakeDeletionService implements TrackDeletionService {
  _FakeDeletionService(this._onDelete);

  final Future<void> Function(Track track) _onDelete;

  @override
  Future<void> deleteEverywhere(Track track) => _onDelete(track);
}
```

Add imports: `import 'package:flind_player/data/providers/deletion_providers.dart';` and `import 'package:flind_player/data/services/track_deletion_service.dart';`.

- [ ] **Step 3: Add the menu item and the delete behavior to `TrackActionsButton`**

In `lib/features/library/widgets/track_actions_button.dart` (`showDeleteTrack` already exists as a no-op from Task 5):

1. Add `deleteTrack` to the enum: `enum _TrackAction { favorite, cache, saveToLibrary, addToPlaylist, removeFromPlaylist, deleteTrack }`.
2. In `itemBuilder`, after the `removeFromPlaylist` item:
   ```dart
        if (showDeleteTrack)
          PopupMenuItem<_TrackAction>(
            value: _TrackAction.deleteTrack,
            child: Row(
              children: [
                const Icon(Icons.delete_outline, size: 20),
                const SizedBox(width: 12),
                Text(l10n.deleteTrack),
              ],
            ),
          ),
   ```
3. In `_onSelected` add `case _TrackAction.deleteTrack: _deleteTrack(context, ref);`
4. Add:
   ```dart
   Future<void> _deleteTrack(BuildContext context, WidgetRef ref) async {
     final l10n = AppLocalizations.of(context);
     final confirmed = await showDialog<bool>(
       context: context,
       builder: (dialogContext) => AlertDialog(
         title: Text(l10n.deleteTrackTitle),
         content: Text(l10n.deleteTrackBody(track.title)),
         actions: [
           TextButton(
             onPressed: () => Navigator.of(dialogContext).pop(false),
             child: Text(l10n.cancel),
           ),
           FilledButton(
             style: FilledButton.styleFrom(
               backgroundColor: Theme.of(dialogContext).colorScheme.error,
               foregroundColor: Theme.of(dialogContext).colorScheme.onError,
             ),
             onPressed: () => Navigator.of(dialogContext).pop(true),
             child: Text(l10n.delete),
           ),
         ],
       ),
     );
     if (confirmed != true) return;
     try {
       await ref.read(trackDeletionServiceProvider).deleteEverywhere(track);
       ref.invalidate(audioCacheEntryProvider(track));
       ref.invalidate(audioCacheUsageProvider);
       ref.invalidate(libraryTracksProvider);
       ref.invalidate(favoritesProvider);
       ref.invalidate(playlistsProvider);
       final id = playlistId;
       if (id != null) ref.invalidate(playlistTracksProvider(id));
       if (context.mounted) {
         ScaffoldMessenger.of(context)
           ..hideCurrentSnackBar()
           ..showSnackBar(
             SnackBar(content: Text(l10n.trackDeleted(track.title))),
           );
       }
     } catch (error) {
       if (context.mounted) showErrorSnackBar(context, error);
     }
   }
   ```
6. Add imports: `package:flind_player/data/providers/deletion_providers.dart`, `.../cache_providers.dart`, `.../library_providers.dart`, `.../persistence_providers.dart`, `.../playlist_providers.dart`.

- [ ] **Step 4: Confirm the renderers already forward `showDeleteTrack`**

Task 9 added `showDeleteTrack` to `TrackTile`/`TrackCard` and made `TrackView` pass `showDeleteTrack: true` from `LibraryScreen`; Task 11 passes it from the playlist detail screen. Re-open `lib/features/library/widgets/track_list_items.dart` to confirm both forward it to `TrackActionsButton`; no new edit is expected here.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/library_screen_test.dart test/waterfall_track_card_test.dart test/playlist_ui_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/l10n lib/features/library/widgets/track_actions_button.dart test/library_screen_test.dart
git commit -m "feat(library): add remove-from-playlist and delete-song actions"
```

---

### Task 15: 文档更新

**Files:**
- Modify: `docs/widget-tree.md`

**Interfaces:** 无。

- [ ] **Step 1: Update the widget tree**

In `docs/widget-tree.md`, in the library section: replace the flat overflow-menu description with the 本地/排序/视图 submenus, note that search is 全部-only and the `+` button 歌单-only, and list the three view renderers (`TrackView`) and their per-scope defaults.

- [ ] **Step 2: Verify docs build (markdown only)**

Run: `git diff --check`
Expected: no whitespace errors.

- [ ] **Step 3: Full verification**

Run: `flutter test`
Expected: all tests PASS.

Run: `dart analyze`
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add docs/widget-tree.md
git commit -m "docs: update library widget tree for the UI redesign"
```

---

## Self-Review

- **Spec coverage:**
  - 需求 1（缓存两态）→ Task 5。
  - 需求 2（本地/排序二级菜单 + 排序默认）→ Task 4、Task 6。
  - 需求 3（搜索/新建歌单收窄）→ Task 7。
  - 需求 4（移出歌单/删除歌曲）→ Task 12、13、14。
  - 需求 5（视图系统）→ Task 1、2、3、6、9、10、11。
  - 需求 6（瀑布流）→ Task 8、9。
  - 持久化 / l10n / 依赖 / 测试 / 文档 → Task 2、3、5、6、14（l10n）、Task 8（依赖）、Task 15（文档）。
  - Review Focus 5 项 → Task 2（3）、Task 6（5）、Task 7（4）、Task 8（2）、Task 14（1）。
- **Placeholder scan:** 无 TBD/“稍后实现”；所有代码步骤含可执行代码；测试步骤含断言。
- **Type consistency:** `LibraryViews`/`LibraryViewScope`/`LibraryView` 签名在 Task 1 定义并在 2/3/6/9/10/11 一致引用；`removeTrackFromAllPlaylists`（Task 12）在 Task 13 一致调用；`showDeleteTrack`（Task 14 定义）在 Task 8/9/11 一致传递。
- **跨任务注意：** `TrackActionsButton.showDeleteTrack` 的占位参数在 Task 5 加入（当次尚无行为），Task 8/9/11 直接传递，Task 14 才补上菜单项与行为，故无前向引用。Task 8 依赖 `flutter_staggered_grid_view`；若离线不可得，按 Task 8 Step 1 的备用方案改用自研均衡列，`TrackView` 接口不变。
