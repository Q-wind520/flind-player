# 1.0 加固里程碑 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把已实现的功能收敛成一个可正式发布的 v1.0.0：正式签名、发布门禁、文档与实现一致、1.0 触发的技术债有结论、依赖与合规复核完成。

**Architecture:** 按阶段推进；每个阶段结束时仓库都处于可构建、可测试状态。依赖/工具链最先冻结，发布工程与版本号其次，随后是技术债代码修复（TDD），再是文档与合规同步，最后统一验证并发布。

**Tech Stack:** Flutter 3.47.x / Dart 3.13；Riverpod、drift、just_audio + audio_service、GitHub Actions；测试用 `flutter_test` + 仓库既有 fake（`test/support/fake_settings_repository.dart`）。

**Spec:** `docs/spec-1.0-hardening-2026-10-02.md`

## Global Constraints

- 版本号 `1.0.0+13`；Dart SDK `^3.13.3`；CI 固定 Flutter `3.47.3`（`.github/workflows/*.yml`）。
- 非目标：不做 Android 本地曲库、不做登录、不做依赖大版本升级（`file_picker` 13 / `permission_handler` 13）、不做架构重构、不改 P5、不开启 Android minify/shrink。
- 每个代码改动后：`flutter analyze` 0 issue、`flutter test` 全绿。
- 文档中的每个「声称」都必须先 grep 代码再改（禁止只改一处文档造成新漂移）。
- GPL 文件头：所有手写 Dart 文件保留/补齐 `// Flind Player - cross-platform music player` 头；生成文件（`*.g.dart`、`lib/l10n/app_localizations*.dart`）豁免。
- 提交信息沿用仓库 `type(scope): 描述` 风格。

## Review Focus

以下是规范暗示、但没有单个任务测试覆盖、且最可能被用户撞见的失效模式（各任务需在自己的步骤里钉住对应的项）：

1. **旧预览版升级**：签名从 debug key 切到正式 key，旧安装无法覆盖升级 → 必须卸载重装且本地数据清空（→ Task 9、Task 28）。
2. **Android 用户以为本地曲库可用**：文档曾声称 MediaStore 支持 → 降级声明必须覆盖 README / local-library.md / 代码 TODO（→ Task 21）。
3. **正式 tag 带病发布**：当前正式发布无 analyze/test 门禁（→ Task 7）。
4. **清空离线缓存失败却提示成功**：M5 的行为（→ Task 11）。
5. **离线列表显示裸 sourceTrackId**：M6 的可读性（→ Task 12）。
6. **Apple 构建静默失败仍发布**：macOS/iOS `continue-on-error`（→ Task 28）。

---

## Phase 1 — 基线

### Task 1: 建立 analyze/test 基线

**Files:** 无（只记录输出）

- [ ] **Step 1: 跑分析**

```bash
cd "/home/qwind/Projects/Flind Player"
flutter analyze
```

记录问题数（预期 0）。

- [ ] **Step 2: 跑测试**

```bash
flutter test
```

记录通过数。**以本步输出为准**校准 README 宣称的测试数（不要沿用 581/688/711）。

- [ ] **Step 3: 保存基线到备忘录**

把两条命令的最终计数写进 Task 19（README 刷新）将要使用的数字里，先记在当前会话/草稿，不提交任何文件。

---

## Phase 2 — 依赖与工具链

### Task 2: 升级 retracted 依赖并重锁（F2）

**Files:**
- Modify: `pubspec.lock`

**Interfaces:**
- Produces: 无 retracted 依赖的锁定版本，供后续所有任务使用。

- [ ] **Step 1: 确认现状**

```bash
flutter pub outdated | grep -i retracted
```
预期显示 `objective_c 9.6.1 (retracted)`。

- [ ] **Step 2: 升级该传递依赖**

```bash
flutter pub upgrade objective_c
```
若 Pub 报无法解析，改为 `flutter pub upgrade`。

- [ ] **Step 3: 验证锁文件**

```bash
grep -A4 "^  objective_c:" pubspec.lock
```
预期 version 为 `9.6.2`（或更高、非 retracted）。

- [ ] **Step 4: 回归**

```bash
flutter analyze && flutter test
```
预期均通过。

- [ ] **Step 5: 提交**

```bash
git add pubspec.lock
git commit -m "chore(deps): move off the retracted objective_c 9.6.1"
```

### Task 3: 记录 tray_manager override 结论（F1）

**背景（已确认）：** 上游 `0.7.0` 是基于 `nativeapi` 的**整体重写**，旧的 `0.5.x` API 被移到 `package:tray_manager/legacy.dart` 且标记 `@Deprecated`，Linux 构建依赖也发生变化。删除本仓库的 vendored `0.5.3` override 需要一次破坏性迁移 → **1.0 保留 override，迁移推迟到 1.1**。

**Files:**
- Modify: `pubspec.yaml:92-102`（更新注释说明推迟原因）

- [ ] **Step 1: 更新 `pubspec.yaml` 的 override 注释**

把现有注释块替换为：

```yaml
# -----------------------------------------------------------------------------
# Local patch: tray_manager's Windows plugin does not dismiss the tray context
# menu when clicking outside (leanflutter/tray_manager#63). The vendored copy in
# packages/tray_manager applies the upstream fix (PR #93).
#
# 1.0 复核结论（2026-10-02）：上游 0.7.0 是迁移到 nativeapi 的整体重写，
# 旧 API 移到 legacy.dart 且已废弃，Linux 构建依赖也改变。删除本 override
# 需要一次破坏性迁移，故推迟到 1.1，1.0 维持 0.5.3 vendored 版本。
# -----------------------------------------------------------------------------
```

- [ ] **Step 2: 确认依赖仍解析**

```bash
flutter pub get && flutter analyze
```

- [ ] **Step 3: 提交**

```bash
git add pubspec.yaml
git commit -m "docs(deps): record why the tray_manager override stays for 1.0"
```

### Task 4: 冻结工具链基线（F3）

**Files:**
- Modify: `.github/workflows/ci.yml:32` / `.github/workflows/release.yml:27`（仅在需要时）

- [ ] **Step 1: 读取本地 Flutter 版本**

```bash
flutter --version
```

- [ ] **Step 2: 与 CI pin 对比**

若本地 stable 版本 ≠ `3.47.3`：把 `ci.yml` / `release.yml` 中所有 `flutter-version: 3.47.3` 统一为实际使用的稳定版本（`grep -n "flutter-version" .github/workflows/*.yml`）。若一致，跳到 Step 4。

- [ ] **Step 3: 校验工作流仍通过**

```bash
flutter pub get
flutter analyze
flutter test
```

- [ ] **Step 4: 记录基线**

在 `docs/spec-1.0-hardening-2026-10-02.md` 的 §3 追加一行，写入 Step 1 输出的 Flutter / Dart 实际版本号与「CI pin 一致」的结论。若未改工作流则只提交该文档改动。

```bash
git add docs/spec-1.0-hardening-2026-10-02.md .github/workflows
git commit -m "chore(ci): freeze the Flutter toolchain baseline"
```
（无改动则跳过提交。）

---

## Phase 3 — 发布工程

### Task 5: 版本号统一到 1.0.0+13（A1/A2）

**Files:**
- Modify: `pubspec.yaml:4`
- Modify: `macos/Runner.xcodeproj/project.pbxproj`（版本配置）
- Modify: `ios/Runner.xcodeproj/project.pbxproj`（版本配置）

- [ ] **Step 1: `pubspec.yaml`**

```yaml
version: 1.0.0+13
```

- [ ] **Step 2: 核对 Apple 版本元数据**

```bash
grep -n "MARKETING_VERSION\|CURRENT_PROJECT_VERSION" macos/Runner.xcodeproj/project.pbxproj ios/Runner.xcodeproj/project.pbxproj
```
把各配置的 `MARKETING_VERSION` 设为 `$(FLUTTER_BUILD_NAME)`、`CURRENT_PROJECT_VERSION` 设为 `$(FLUTTER_BUILD_NUMBER)`，使构建版本由 pubspec 驱动（当前硬编码 `1.0` / `1`）。**只改 `Release` 相关配置，`Profile`/`Debug` 保持模板默认。**

- [ ] **Step 3: 跑生成与解析**

```bash
flutter pub get
flutter analyze
```

- [ ] **Step 4: 提交**

```bash
git add pubspec.yaml macos/Runner.xcodeproj/project.pbxproj ios/Runner.xcodeproj/project.pbxproj
git commit -m "chore(release): bump to 1.0.0+13 and drive Apple versions from pubspec"
```

### Task 6: 建立 CHANGELOG.md（A3）

**Files:**
- Create: `CHANGELOG.md`

- [ ] **Step 1: 写入内容**

```markdown
# Changelog

本文件记录 Flind Player 面向用户的变更。1.0.0 是首个正式发布；此前的 0.1–0.7 均为预览版，未逐版记录。

## [1.0.0] - 2026-10-02

首个正式发布。功能范围在 0.7.0 基础上加固，并补齐正式签名与发布门禁。

### 新增

- 网易云音乐在线音源（匿名）：搜索、播放、歌词。
- 同步歌词视图：时间轴高亮、自动滚动、双语（原文 + 翻译）。
- 搜索支持多在线音源切换。

### 变更

- 在线音源改为统一注册表，搜索 / 流解析 / 歌词路由不再按源硬编码。
- Android 正式签名（此前使用 debug 签名）。

### 修复

- 封面改为远程优先、按主机注入 Referer/UA，并保留下载/缓存兜底。
- 网易云 CDN 流地址统一升级为 https。

### 文档

- 修正 README / 架构文档中与实际实现不一致的描述。
- 明确 Android 本地曲库延后（1.1）。
```

- [ ] **Step 2: 提交**

```bash
git add CHANGELOG.md
git commit -m "docs: add CHANGELOG with the 1.0.0 entry"
```

### Task 7: 正式发布加入 analyze/test 门禁（A4）

**Files:**
- Modify: `.github/workflows/release.yml`

- [ ] **Step 1: 在 `permissions` 之后、`build-linux` 之前加入门禁 job**

```yaml
  analyze-and-test:
    name: Analyze and test
    runs-on: ubuntu-latest
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v7
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          flutter-version: 3.47.3
      - name: Cache pub packages
        uses: actions/cache@v6
        with:
          path: ~/.pub-cache
          key: ${{ runner.os }}-pub-${{ hashFiles('**/pubspec.lock') }}
          restore-keys: |
            ${{ runner.os }}-pub-
      - name: Install dependencies
        run: flutter pub get
      - name: Analyze
        run: flutter analyze
      - name: Test
        run: flutter test
```

- [ ] **Step 2: 让五个 build job 依赖门禁**

在每个 build job 的 `steps:` 之前加一行 `needs: analyze-and-test`（共 5 处：`build-linux`、`build-windows`、`build-macos`、`build-ios`、`build-android`）。

```bash
grep -n "needs: analyze-and-test" .github/workflows/release.yml
```
预期恰好 5 行。

- [ ] **Step 3: 语法自检**

```bash
python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/release.yml')); print('ok')"
```

- [ ] **Step 4: 提交**

```bash
git add .github/workflows/release.yml
git commit -m "ci(release): gate formal releases on analyze and test"
```

### Task 8: Android 正式签名落地与验证（A5）

**性质：** 维护者动作 + 仓库侧验证。keystore 与 secrets 是仓库外机密，不能由代码生成。

**Files:**
- Verify: `android/app/build.gradle.kts`
- Create: `docs/release-checklist-1.0.md`（本任务的记录载体；Task 27 会继续补充）

- [ ] **Step 1: 确认 Gradle 已支持正式签名**

```bash
grep -n "key.properties\|signingConfig" android/app/build.gradle.kts
```
预期已有 `hasReleaseSigning` 分支（无需改代码）。

- [ ] **Step 2: 维护者动作（记录到 checklist）**

在 `docs/release-checklist-1.0.md` 写明并逐项勾选：

```markdown
## Android 正式签名

- [ ] keystore 已生成：`keytool -genkeypair -v -keystore android/app/keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias flind`
- [ ] 仓库 secrets 已配置：`ANDROID_KEYSTORE_BASE64` / `ANDROID_KEYSTORE_PASSWORD` / `ANDROID_KEY_ALIAS` / `ANDROID_KEY_PASSWORD`
- [ ] 本地 `android/key.properties` 指向 keystore（gitignored）
- [ ] `flutter build apk --release` 后 `apksigner verify --print-certs` 显示的是正式证书（非 Android Debug）
```

- [ ] **Step 3: 若本地已有 keystore，验证签名**

```bash
flutter build apk --release --split-per-abi
apksigner verify --print-certs build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```
预期证书 CN 非 `Android Debug`。

- [ ] **Step 4: 提交 checklist**

```bash
git add docs/release-checklist-1.0.md
git commit -m "docs(release): start the 1.0 release checklist with Android signing"
```

### Task 9: 升级路径与产物文案（A6/A7）

**Files:**
- Modify: `.github/workflows/release.yml:359-397`（release body 预览版说明）
- Modify: `docs/packaging.md`（版本示例）

- [ ] **Step 1: 替换 release body 的预览版段落**

把 `0.1.x 使用调试签名…正式签名将在 1.0 引入` 段落替换为：

```markdown
> **1.0.0 签名变更**：1.0.0 起使用正式签名。此前 0.1–0.7 预览版使用 debug 签名，
> 两者证书不同、**不支持覆盖安装**：升级前请先卸载旧版本再安装 1.0.0。卸载不会
> 删除 `~/.local/share`（Linux）/ `%APPDATA%`（Windows）下的本地数据，但 Android
> 上卸载会清除应用数据（曲库索引、收藏、播放队列、离线缓存）。
>
> **1.0.0 signing change**: 1.0.0 is signed with the release key. Preview builds
> (0.1–0.7) used the debug key; signatures are incompatible, so uninstall the
> preview build before installing 1.0.0.
```

- [ ] **Step 2: 更新 `docs/packaging.md` 的版本示例**

把示例命令里的 `--version 0.5.0` 统一改为 `--version 1.0.0`（三处 linux 脚本 + 一处 Windows 示例）。

- [ ] **Step 3: 提交**

```bash
git add .github/workflows/release.yml docs/packaging.md
git commit -m "docs(release): document the 1.0 signing change and upgrade path"
```

---

## Phase 4 — 技术债（1.0 触发型）

### Task 10: M8 — 启动直接删旧层 2，不再搬迁

**Files:**
- Modify: `lib/data/cache/cache_relocator.dart:53-57,99-123`
- Modify: `lib/main.dart`（relocator 调用处，传 `coverStore`/`legacyCoverRoot` 的行）
- Test: `test/cache_relocator_test.dart`

**Interfaces:**
- Produces: `CacheRelocator` 不再接收 `coverStore` / `legacyCoverRoot`；`relocate()` 仍只负责音频搬迁 + 旧层 2 清理。

- [ ] **Step 1: 改测试（先红）**

把第二个测试「moves legacy layer-2 covers into the new root and rewrites paths」改为断言**旧目录被删除**：

```dart
test('deletes the legacy layer-2 cover directory', () async {
  final legacyCover = Directory(p.join(root.path, 'cover_cache'))..createSync();
  File(p.join(legacyCover.path, 'a.jpg')).writeAsBytesSync(<int>[1, 2, 3]);

  final relocator = CacheRelocator(
    database: db,
    audioStore: audioStore,
    legacyAudioRoot: Directory(p.join(root.path, 'audio_cache')),
  );
  await relocator.relocate();

  expect(legacyCover.existsSync(), isFalse);
});
```
（同时删除旧测试里构造 `coverStore:` / `legacyCoverRoot:` 的参数。）

- [ ] **Step 2: 运行确认失败**

```bash
flutter test test/cache_relocator_test.dart
```
预期：编译失败（构造参数不再接受）或断言失败。

- [ ] **Step 3: 改实现**

`lib/data/cache/cache_relocator.dart`：

```dart
  Future<void> relocate() async {
    await _relocateAudio();
    _deleteLegacyCovers();
  }

  /// Layer 2 is session-scoped and wiped at startup, so relocating it into the
  /// new root is wasted I/O. Remove the legacy directory instead.
  void _deleteLegacyCovers() {
    final legacy = _legacyCover;
    if (legacy == null || !legacy.existsSync()) return;
    try {
      legacy.deleteSync(recursive: true);
    } catch (error) {
      debugPrint('CacheRelocator: legacy cover cleanup failed: $error');
    }
  }
```

同时：删除 `_relocateCovers()` 方法；从构造函数与字段移除 `coverStore` / `_coverStore`；若 `cover_cache_store.dart` 与 `CoverCacheCompanion` 不再被引用则删除对应 import（保留 `Value`，音频搬迁仍用）。

- [ ] **Step 4: 更新 `lib/main.dart` 调用处**

移除传给 `CacheRelocator` 的 `coverStore:` 与 `legacyCoverRoot:` 参数（保留 `database`、`audioStore`、`legacyAudioRoot`）。

- [ ] **Step 5: 跑测试与分析**

```bash
flutter analyze && flutter test test/cache_relocator_test.dart
```
预期全绿；`analyze` 无 unused import/field。

- [ ] **Step 6: 提交**

```bash
git add lib/data/cache/cache_relocator.dart lib/main.dart test/cache_relocator_test.dart
git commit -m "fix(cache): delete the legacy layer-2 cover dir instead of relocating it (M8)"
```

### Task 11: M5 — 清空离线缓存区分成败

**Files:**
- Modify: `lib/data/providers/offline_cache_providers.dart:46-92`
- Modify: `lib/features/settings/settings_screen.dart`（`_confirmClearOffline` 尾部）
- Modify: `lib/l10n/app_en.arb`、`lib/l10n/app_zh.arb`
- Test: `test/offline_cache_providers_test.dart`、`test/settings_screen_test.dart`

**Interfaces:**
- Produces: `OfflineCacheMaintenance.onClearAll` 变为 `Future<bool> Function()`（成功 `true`，任一步失败 `false`）。`onRemove` 保持不变。

- [ ] **Step 1: 写 provider 失败测试（先红）**

在 `test/offline_cache_providers_test.dart` 的 `offlineCacheMaintenanceProvider` 组内新增：

```dart
test('onClearAll returns false when a delete throws', () async {
  final store = _ThrowingStore();
  final container = ProviderContainer(
    overrides: [audioCacheStoreProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);

  final result =
      await container.read(offlineCacheMaintenanceProvider).onClearAll();

  expect(result, isFalse);
});
```
其中 `_ThrowingStore` 是测试文件内的最小 fake：`entries()` 返回一条 `pinned: true` 的行，`remove()` 抛异常（按现有 `AudioCacheStore` 的 fake 风格补全其余成员）。

- [ ] **Step 2: 运行确认失败**

```bash
flutter test test/offline_cache_providers_test.dart
```
预期：`onClearAll` 返回类型不匹配 / 断言失败。

- [ ] **Step 3: 改 provider**

`offline_cache_providers.dart`：字段改为
```dart
  /// Deletes every pinned entry. Returns `false` when any delete failed.
  final Future<bool> Function() onClearAll;
```
实现改为
```dart
    onClearAll: () async {
      try {
        final entries = await store.entries();
        for (final entry in entries.where((e) => e.pinned)) {
          await store.remove(entry.id);
        }
        return true;
      } catch (error) {
        debugPrint('OfflineCacheMaintenance: clearAll failed: $error');
        return false;
      }
    },
```

- [ ] **Step 4: 加 l10n key**

`app_en.arb`：
```json
  "offlineCacheClearFailed": "Could not clear the offline cache.",
```
`app_zh.arb`：
```json
  "offlineCacheClearFailed": "清空离线缓存失败。",
```

- [ ] **Step 5: 改设置页分支**

`_confirmClearOffline` 尾部：
```dart
    final messenger = ScaffoldMessenger.of(context);
    final freed = ref.read(offlineCacheUsageProvider).value ?? 0;
    final ok = await ref.read(offlineCacheMaintenanceProvider).onClearAll();
    ref.invalidate(offlineCacheEntriesProvider);
    ref.invalidate(offlineCacheUsageProvider);
    ref.invalidate(combinedCacheUsageProvider);
    ref.invalidate(audioCacheUsageProvider);
    ref.invalidate(audioCacheEntryCountProvider);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? l10n.offlineCacheCleared(formatMegabytes(freed))
              : l10n.offlineCacheClearFailed,
        ),
      ),
    );
```

- [ ] **Step 6: 扩展 widget 测试**

在 `test/settings_screen_test.dart` 的 `_FakeCacheStore` 上加一个可切换的失败标记（使 `remove` 抛异常），新增/扩展现有用例断言出现 `find.text('清空离线缓存失败。')`。

- [ ] **Step 7: 生成 l10n 并跑测试**

```bash
flutter gen-l10n
flutter analyze && flutter test test/offline_cache_providers_test.dart test/settings_screen_test.dart
```

- [ ] **Step 8: 提交**

```bash
git add lib/data/providers/offline_cache_providers.dart lib/features/settings/settings_screen.dart lib/l10n/app_en.arb lib/l10n/app_zh.arb test/offline_cache_providers_test.dart test/settings_screen_test.dart
git commit -m "fix(settings): distinguish offline-cache clear failure from success (M5)"
```

### Task 12: M6 — 离线列表标题用歌名

**Files:**
- Modify: `lib/features/settings/settings_screen.dart`（`_OfflineCacheSection` 列表与确认框）
- Test: `test/settings_screen_test.dart`

**Interfaces:**
- Consumes: `libraryTracksProvider`（`StreamProvider<List<Track>>`）、`Track.uri`。
- Produces: 离线条目显示 `track.title`，缺失时回落 `entry.sourceTrackId`。

- [ ] **Step 1: 加 widget 测试（先红）**

在 `test/settings_screen_test.dart` 现有离线缓存用例基础上，让 `_app(tracks: [...])` 提供一个 `Track(uri: 'bilibili:BV1', title: 'Song A', ...)`，断言 `find.text('Song A')` 命中、并断言确认框正文包含 `'Song A'`。

- [ ] **Step 2: 运行确认失败**

```bash
flutter test test/settings_screen_test.dart
```
预期：仍显示 `BV1`，找不到 `Song A`。

- [ ] **Step 3: 改实现**

在 `_OfflineCacheSection` 的 `build` 中先建索引：
```dart
final tracksByUri = <String, Track>{
  for (final t in ref.watch(libraryTracksProvider).value ?? const <Track>[])
    t.uri: t,
};
```
列表项与确认框统一取：
```dart
final label =
    tracksByUri['${entry.source}:${entry.sourceTrackId}']?.title ??
    entry.sourceTrackId;
```
`title: Text(label)`、`content: Text(l10n.removeDownloadBody(label))`。补 `Track` 与 `library_providers.dart` 的 import。

- [ ] **Step 4: 跑测试**

```bash
flutter analyze && flutter test test/settings_screen_test.dart
```

- [ ] **Step 5: 提交**

```bash
git add lib/features/settings/settings_screen.dart test/settings_screen_test.dart
git commit -m "fix(settings): show track titles in the offline cache list (M6)"
```

### Task 13: M7 — 四个确认弹窗去重

**Files:**
- Modify: `lib/features/settings/settings_screen.dart`
- Test: `test/settings_screen_test.dart`（既有测试必须保持通过，字符串不变）

**Interfaces:**
- Produces: 顶层私有 helper `_confirmDestructive(BuildContext, {title, message, confirmLabel}) → Future<bool>`。

- [ ] **Step 1: 先跑既有测试建立绿基线**

```bash
flutter test test/settings_screen_test.dart
```
预期全绿（覆盖四个弹窗的用例分别在既有文件中）。

- [ ] **Step 2: 加入 helper**

在 `settings_screen.dart` 顶层（其余私有 widget 之前）：
```dart
/// Shared destructive-confirmation dialog used by the four cache/library
/// delete actions. Returns `true` only when the user confirms.
Future<bool> _confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
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
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed == true;
}
```

- [ ] **Step 3: 迁移四个调用点**

逐个替换（保持 key 与现状一致，测试依赖这些字符串）：

1. `_confirmRemoveDownload`：
```dart
final confirmed = await _confirmDestructive(
  context,
  title: l10n.removeDownloadTitle,
  message: l10n.removeDownloadBody(entry.sourceTrackId),
  confirmLabel: l10n.delete,
);
if (!confirmed || !context.mounted) return;
```
（若 Task 12 已落地，正文改用 Task 12 的 `label`。）
2. `_confirmClearOffline`：
```dart
final confirmed = await _confirmDestructive(
  context,
  title: l10n.clearOfflineTitle,
  message: l10n.clearOfflineBody,
  confirmLabel: l10n.clear,
);
```
3. `_CacheLocationDialog._confirmClear`：
```dart
final confirmed = await _confirmDestructive(
  context,
  title: l10n.clearCacheTitle,
  message: l10n.clearCacheBody,
  confirmLabel: l10n.clear,
);
```
4. `_LibrarySectionState._confirmRemoveRoot`：
```dart
final confirmed = await _confirmDestructive(
  context,
  title: l10n.deleteScanRootTitle,
  message: l10n.deleteScanRootBody(root.path),
  confirmLabel: l10n.delete,
);
```


- [ ] **Step 4: 跑测试与分析**

```bash
flutter analyze && flutter test test/settings_screen_test.dart
```
预期全绿。

- [ ] **Step 5: 提交**

```bash
git add lib/features/settings/settings_screen.dart
git commit -m "refactor(settings): share one destructive-confirm dialog (M7)"
```

### Task 14: C1 延期项补充代码注释（M1/M2/M3/M4/M9/P2）

**性质：** 纯注释，不改行为。目的：让「为何安全 / 触发条件」留在代码处。

**Files:**
- Modify: `lib/data/cache/audio_cache_store.dart`（M1、M9）
- Modify: `lib/data/services/cover_service.dart`（M2、M3、M4）
- Modify: `lib/data/cache/download_manager.dart`（P2）

- [ ] **Step 1: M1（`audio_cache_store.dart` 驱逐循环，`_deleteCoverFile(coverPath)` 前）**

```dart
        // 1.0 复核（M1）：封面删除暂时不做引用检查。`coverFileFor` 以
        // sha1(source:trackId) 命名且表上有 UNIQUE(source, source_track_id)，
        // 正常路径下每行封面唯一（当前不可达）；若将来两行共享同一 cover_path，
        // 需在此补与音频相同的 stillReferenced 检查。
```

- [ ] **Step 2: M9（`audio_cache_store.dart` `insert` 的 `resolvedPath`/`resolvedBytes` 附近）**

```dart
    // 1.0 复核（M9）：文件不可读时 contentHash 用 Value.absent()，但
    // filePath/bytes 仍是具体值；罕见情况下 upsert 会用不可读路径覆盖已有行。
    // 该行会由下次 checkIntegrity 删除，属自愈的临时脏状态（已知，不修）。
```

- [ ] **Step 3: M2（`cover_service.dart` `_writeLayer1Cover` 末尾 `enforceLimit()` 前）**

```dart
    // 1.0 复核（M2）：`enforceLimit()` 理论上可能把刚写入封面的这一行驱逐
    // （仅当该行非 pinned、加封面后恰好超限、且它是最旧一行）。触发概率极低，
    // 返回路径会被 `existsSync` 自愈；若将来出现悬空封面，改为排除本行 id。
```

- [ ] **Step 4: M3（`cover_service.dart` 类文档项 3/4 与 `_inFlightByUrl` 注释）**

更正类注释，去掉「层 1 也走 URL 去重」的暗示；在 `_inFlightByUrl` 注释补一句：
```dart
  /// 1.0 复核（M3）：当前仅层 2 的 `_storeDownload` 使用本表去重；层 1
  /// （`_ensureLayer1`）直接 `_downloader.download`，同一 `pic` 且各分 P 音频
  /// 都已缓存时可能重复下载一次。属可接受的重复，不修。
```

- [ ] **Step 5: M4（`cover_service.dart` 两处复用 `_bytesOf` 的点）**

```dart
      // 1.0 复核（M4）：复用已存在的封面字节时跳过 isDecodableImage 校验——
      // 仅当文件事后被外部损坏时才会把坏图写进层 1，与既有行为一致（已知，不修）。
```

- [ ] **Step 6: P2（`download_manager.dart` `_estimateBytes`）**

把现有文档注释扩为：
```dart
  /// 1.0 复核（P2）：[StreamInfo] 不透出长度，故预检恒为 0，超配额的大文件会先
  /// 整段下载再在下载后 `ensureSpace(bytes)` 处失败，白费带宽。修法需给 StreamInfo
  /// 增加长度字段并让各 resolver 填充，属 API 变更，1.0 不做（见 spec 非目标）。
  int _estimateBytes(StreamInfo info) => 0;
```

- [ ] **Step 7: 验证并提交**

```bash
flutter analyze && flutter test
git add lib/data/cache/audio_cache_store.dart lib/data/services/cover_service.dart lib/data/cache/download_manager.dart
git commit -m "docs(cache): record why M1/M2/M3/M4/M9/P2 stay deferred"
```

### Task 15: C2 m3 — 修正 provider 文档注释

**Files:**
- Modify: `lib/data/providers/settings_repository_provider.dart:21`

- [ ] **Step 1: 替换首行注释**

```dart
/// Persisted user settings across cache, library and appearance domains.
```

- [ ] **Step 2: 验证并提交**

```bash
flutter analyze && flutter test test/settings_repository_provider_test.dart
git add lib/data/providers/settings_repository_provider.dart
git commit -m "docs(settings): make the settings-provider doc cross-domain (m3)"
```

### Task 16: C2 m4 — 复用共享 cache fake

**Files:**
- Modify: `test/settings_repository_segregation_test.dart:26-41,64`

- [ ] **Step 1: 删除 `_CacheSliceFake` 并改用共享 fake**

在文件顶部加 `import 'support/fake_settings_repository.dart';`，并定义：
```dart
class _CacheSliceFake extends FakeSettingsBase with FakeCacheSettings {}
```
把第 64 行的使用改为 `settings: _CacheSliceFake()`（构造方式不变，因为它已是共享 mixin 的薄封装）。

- [ ] **Step 2: 验证并提交**

```bash
flutter analyze && flutter test test/settings_repository_segregation_test.dart
git add test/settings_repository_segregation_test.dart
git commit -m "test(settings): reuse the shared cache fake in the segregation test (m4)"
```

### Task 17: C2 m5 — 删除死的设置 fixture

**Files:**
- Modify: `test/cover_cache_store_test.dart:32,38,176`（及不再使用的 import）

- [ ] **Step 1: 删除 fixture**

删除 `late FakeSettingsRepository settings;` 声明、`settings = FakeSettingsRepository();` 初始化、以及测试 `does not read the user cache limit` 内的 `settings.current = ...` 赋值；清理仅为此服务的 import。

- [ ] **Step 2: 在测试内保留意图说明**

```dart
    // Layer 2 is fixed at 256 MiB and never reads the user's cache limit by
    // construction, so there is nothing to inject here (m5: dead fixture removed).
```

- [ ] **Step 3: 验证并提交**

```bash
flutter analyze && flutter test test/cover_cache_store_test.dart
git add test/cover_cache_store_test.dart
git commit -m "test(cache): drop the dead settings fixture (m5)"
```

### Task 18: C2 m1/m2 — 记录为已知不修

**Files:**
- Modify: `docs/耦合TODO.md` §五

- [ ] **Step 1: 更新 §五 表格**

在 §五 表格底部加一行结论：

```markdown
> **1.0 复核（2026-10-02）**：m3 / m4 / m5 已处理（见 Task 15/16/17）。m1（缓存类测试仍绑定完整
> composite fake）与 m2（共享 fake 暴露 `writes`/`sort`/`views` 等当前无人读取的成员）判定为
> **已知，不修**：m1 是测试便利而非行为风险，m2 是为将来断言语义预留，删除反而要改动多个测试。
```

- [ ] **Step 2: 提交**

```bash
git add docs/耦合TODO.md
git commit -m "docs: close out the settings-decoupling minors for 1.0"
```

---

## Phase 5 — 文档与功能覆盖同步

### Task 19: README 全面刷新（B1）

**Files:**
- Modify: `README.md`

- [ ] **Step 1: 逐处修正（先 grep 再改）**

```bash
grep -n "0.2.1\|581\|688\|仅占位\|Bilibili 主入口\|push 到 \`master\`\|0.2.x 预览版签名\|netease" README.md
```

按以下结论替换：
1. 版本 badge（`:13`）`version-0.2.1` → `version-1.0.0`。
2. 测试 badge（`:17`）改用 Task 1 实跑得到的通过数，文案形如 `tests-（Task 1 的数） passing`。
3. 「功能特性」表增加网易云音乐与同步歌词两项；「技术栈」保持。
4. 「项目状态」中歌词从「仅占位」改为「已落地：同步高亮 + 双语（网易云源供词）」；M0–M6 列表补网易云音源。
5. 「支持平台」把 Web 行保留 v2；Android 行明确「本地曲库延后（1.1）」；iOS/macOS 行不变。
6. 「触发发布工作流」段落：把「push 到 `master` 及 PR 时运行」改为「CI 仅在 `v*-pre*` tag 运行；正式 tag 由 Release 工作流在 analyze+test 门禁后构建发布」。
7. 「0.2.x 预览版签名」段落替换为 Task 9 的 1.0 签名/升级文案。
8. 「文档」表补 `netease-source.md`、`spec-1.0-hardening-2026-10-02.md`、`plan-1.0-hardening-2026-10-02.md`、`manual-regression-1.0.md`、`release-checklist-1.0.md`。
9. 「验证基线」段落的测试数改为 Task 1 实跑数与 integration_test 实际数。

- [ ] **Step 2: 检查 markdown 渲染**

```bash
grep -c "0.2.1" README.md
```
预期 `0`（除非历史 changelog 明确提及）。

- [ ] **Step 3: 提交**

```bash
git add README.md
git commit -m "docs(readme): refresh version, tests, sources and release workflow"
```

### Task 20: 架构文档同步（B2）

**Files:**
- Modify: `docs/architecture.md`

- [ ] **Step 1: 先核对代码事实**

```bash
ls lib/app/router.dart 2>/dev/null; ls -d lib/features/account 2>/dev/null
grep -rn "go_router\|flutter_secure_storage\|on_audio_query_pluse\|media_kit:" lib pubspec.yaml
```

- [ ] **Step 2: 修正 §5 目录结构**

删除 `app/router.dart`（go_router）与 `features/account/` 的描述（当前不存在）；如保留占位，改为明确标注「预留，1.1」。修正 `data/services` 下列出 `cover_service.dart`（当前实际在 `lib/data/services/`）。

- [ ] **Step 3: 修正 §12.1 依赖表**

删除代码中不存在的包（`go_router`、`flutter_secure_storage`、`on_audio_query_pluse`、`media_kit`、`audio_service_win`/`smtc_windows` 若未使用），补 `crypto` / `pointycastle`（网易云 weapi/eapi）；每条以 `pubspec.yaml` 为准。

- [ ] **Step 4: 修正 D8**

把「凭证存储 = flutter_secure_storage」标注为**未实现（登录留 1.1）**，或删除该决策条目，避免与代码矛盾。

- [ ] **Step 5: 验证无残留矛盾**

```bash
grep -n "go_router\|flutter_secure_storage\|router.dart\|features/account" docs/architecture.md
```
预期无未标注的过时引用。

- [ ] **Step 6: 提交**

```bash
git add docs/architecture.md
git commit -m "docs(architecture): align directory, deps and credential notes with code"
```

### Task 21: 本地曲库文档 + Android 降级 + 能力矩阵（B3/D1/D2/D3）

**Files:**
- Modify: `docs/local-library.md`
- Modify: `README.md`（平台能力表述，若 Task 19 未覆盖）
- Modify: `lib/data/sources/local/local_library_scanner.dart:271-275`

- [ ] **Step 1: `local-library.md` Android 降级**

在 §2.1 明确：「**Android 本地曲库延后到 1.1**。当前实现只做目录遍历（`LocalLibraryScanner`），未接入 `MediaStore`；Android 上 `file_picker.getDirectoryPath()` 返回 `content://`，`dart:io` 无法遍历，故 Android 本地库在 1.0 不可用。」并修正 §2.2 / 依赖表 / 边界表中「宣称已支持」的表述为计划项。

- [ ] **Step 2: 改代码 TODO**

`local_library_scanner.dart:271` 注释改为：
```dart
    // TODO(android-1.1): Android 本地曲库延后（见 docs/local-library.md §2.1 与
    // docs/spec-1.0-hardening-2026-10-02.md D1）。1.1 起接入 MediaStore 适配器，
    // 并把候选文件喂给同一抽取池；此处隔离的发现层即为该平台接缝预留。
```

- [ ] **Step 3: 核对能力矩阵（D2/D3）**

逐条 grep 代码核对 README 平台表与 architecture §9 系统集成表；网易云/Bilibili 收藏夹/歌词范围以 `lib/features` 与 `lib/data/sources` 实现为准，文档不符即改文档（不改代码）。

- [ ] **Step 4: 验证并提交**

```bash
flutter analyze
git add docs/local-library.md README.md docs/architecture.md lib/data/sources/local/local_library_scanner.dart
git commit -m "docs(library): scope Android local library out of 1.0 (D1)"
```

### Task 22: GPL 文件头策略（B4）

**Files:**
- Modify: `lib/app/l10n.dart`
- Modify: `docs/architecture.md` §12.3（记录豁免）

- [ ] **Step 1: 给手写文件补头**

在 `lib/app/l10n.dart` 顶部插入与其它文件一致的 15 行 GPL 头。

- [ ] **Step 2: 记录生成文件豁免**

在 `architecture.md` §12.3 末尾加：「由工具生成、不手工编辑的文件（drift `*.g.dart`、`lib/l10n/app_localizations*.dart`）豁免文件头；后者由 `flutter gen-l10n` 生成且不纳入版本控制。」

- [ ] **Step 3: 验证并提交**

```bash
flutter analyze
git add lib/app/l10n.dart docs/architecture.md
git commit -m "docs(license): add the GPL header to l10n.dart and note generated-file exemption"
```

### Task 23: 归档已发布设计与计划（B5）

**Files:**
- Move: `docs/spec-netease-source-2026-10-01.md`、`docs/plan-netease-source-2026-10-01.md` → `docs/archive/`
- Modify: 引用它们的地方

- [ ] **Step 1: 找引用**

```bash
grep -rn "spec-netease-source-2026-10-01\|plan-netease-source-2026-10-01" docs README.md
```

- [ ] **Step 2: 移动并修引用**

```bash
git mv docs/spec-netease-source-2026-10-01.md docs/archive/
git mv docs/plan-netease-source-2026-10-01.md docs/archive/
```
更新所有引用为 `docs/archive/...`，并在两份文件头部状态行标注「已实现并发布（v1.0.0），2026-10-02 归档」。

- [ ] **Step 3: 提交**

```bash
git add -A docs
git commit -m "docs: archive the shipped netease source spec and plan"
```

---

## Phase 6 — 合规、安全与音源

### Task 24: GPL-3.0 合规复核（F4）

**Files:**
- Modify: `docs/release-checklist-1.0.md`

- [ ] **Step 1: 逐项核对并记录**

在 checklist 增加：
```markdown
## GPL-3.0 合规

- [ ] Release body 含对应源码指向（`.github/workflows/release.yml` 的 GPL 段落）——已存在，确认 tag 正确。
- [ ] AppImage 包内包含 libmpv/FFmpeg 的 LGPL-2.1+ 许可说明（`packaging/linux/build-appimage.sh`）。
- [ ] Windows 包内注明随包的 MSVC 运行时可再分发（`docs/packaging.md`）。
- [ ] 仓库根 `LICENSE` 为 GPL-3.0 全文；README License 段指向正确。
```

- [ ] **Step 2: 验证并提交**

```bash
grep -l "GNU General Public License" LICENSE >/dev/null && echo "LICENSE ok"
git add docs/release-checklist-1.0.md
git commit -m "docs(release): add the GPL-3.0 compliance checklist"
```

### Task 25: 隐私与安全复核（F5）

**Files:**
- Modify: `docs/release-checklist-1.0.md`

- [ ] **Step 1: 核对无凭证落盘**

```bash
grep -rn "secure_storage\|SESSDATA\|MUSIC_U\|password\|token" lib --include='*.dart' || echo "no credential code"
```
预期无凭证实现（登录留 1.1）。将结论写入 checklist。

- [ ] **Step 2: 记录权限与网络披露**

在 checklist 增加：
```markdown
## 隐私与安全

- [ ] 当前无登录实现，代码中无凭证持久化（已 grep 确认）。
- [ ] 权限仅用于音频读取/通知/网络（`lib/platform/permissions/`）；申请时机与文案复核。
- [ ] 网络只访问 Bilibili / 网易云；README 与应用内无夸大隐私声明。
```

- [ ] **Step 3: 提交**

```bash
git add docs/release-checklist-1.0.md
git commit -m "docs(release): add the privacy and credential checklist"
```

### Task 26: 音源 ToS/风控姿态复核（F6）

**Files:**
- Modify: `docs/release-checklist-1.0.md`

- [ ] **Step 1: 复核两份音源文档的法务/风控章节**

```bash
grep -n "法务\|ToS\|风控\|律师\|禁用\|代理\|凭证" docs/bilibili-source.md docs/netease-source.md
```
确认：不做带凭证公共代理、支持远程禁用、个人使用姿态。把结论与最新复核日期写入 checklist。

- [ ] **Step 2: 提交**

```bash
git add docs/release-checklist-1.0.md
git commit -m "docs(release): record the source ToS review"
```

---

## Phase 7 — 回归与发布

### Task 27: 手工回归基线（E3/E6）

**Files:**
- Create: `docs/manual-regression-1.0.md`

- [ ] **Step 1: 写文档**

```markdown
# 1.0 手工回归基线

`integration_test/` 不在 CI 门禁内，需在真机 / 桌面上手动执行。以下为发布前必跑项。

## 自动化冒烟

- [ ] `flutter test integration_test`（记录通过数，应覆盖目录下全部用例）。

## 手工场景

- [ ] 缓存极限淘汰：把缓存上限调到最小，播放/下载若干曲目，确认 LRU 生效、pinned 不被淘汰、无崩溃。
- [ ] 流过期自愈：播放 Bilibili 曲目至 token 失效（或模拟 403），确认自动刷新并回到原进度。
- [ ] 断网启动：断网启动已缓存曲目可播放；未缓存曲目给出可理解的失败而非崩溃。
- [ ] 覆盖升级数据保留：在同一签名内升级，确认曲库索引、收藏、队列、离线缓存保留。
- [ ] 清空离线缓存：失败路径显示错误提示（M5）。
- [ ] 离线列表：显示歌名而非裸 ID（M6）。

## 矩阵

- [ ] Linux 桌面、Android 真机、Windows 桌面；macOS/iOS 至少各一次构建产物可启动。
```

- [ ] **Step 2: 提交**

```bash
git add docs/manual-regression-1.0.md
git commit -m "docs(release): add the 1.0 manual regression baseline"
```

### Task 28: 构建矩阵实跑（E5）

**Files:** 无（只记录结果到 `docs/release-checklist-1.0.md`）

- [ ] **Step 1: 本地能跑的**

```bash
flutter build linux --release
flutter build apk --release --split-per-abi
packaging/linux/build-deb.sh --version 1.0.0
packaging/linux/build-appimage.sh --version 1.0.0
```

- [ ] **Step 2: 本地跑不了的交给 CI**

先打预发布 tag，让 CI 覆盖 Windows / macOS / iOS 与打包冒烟：

```bash
git tag v1.0.0-pre+1 && git push origin v1.0.0-pre+1
```
记录各 job 结果；macOS/iOS 若仍失败，评估是否移除 `continue-on-error` 或接受为已知（写入 checklist）。

- [ ] **Step 3: 记录并提交**

```bash
git add docs/release-checklist-1.0.md
git commit -m "docs(release): record the pre-release build matrix results"
```

### Task 29: 最终验证并发布 v1.0.0

**Files:** 无

- [ ] **Step 1: 最终门禁**

```bash
flutter analyze
flutter test
```
预期 0 issue / 全绿，且与 Task 1 基线一致或更好。

- [ ] **Step 2: 对照 spec §5 DoD 逐条勾选**（`docs/release-checklist-1.0.md`）

确认 10 条验收标准全部满足；未满足的必须在 checklist 写明「已知/接受」。

- [ ] **Step 3: 打正式 tag**

```bash
git tag v1.0.0
git push origin v1.0.0
```
Release 工作流会在 `analyze-and-test` 门禁后构建并发布。

- [ ] **Step 4: 复核 Release 资产**

确认资产包含：Linux deb/rpm/AppImage/tar.gz、Windows setup/zip、macOS zip、iOS ipa、Android APK/AAB；release body 的签名变更说明正确。

---

## Self-Review 记录

- **Spec coverage：** A1→T5、A2→T5、A3→T6、A4→T7、A5→T8、A6/A7→T9；B1→T19、B2→T20、B3/D1→T21、B4→T22、B5→T23；C1→T10-T14、C2→T15-T18；D2/D3→T21；E1/E2→T1/T29、E3/E6→T27、E5→T28；F1→T3、F2→T2、F3→T4、F4→T24、F5→T25、F6→T26。
- **P5 不修、P2 仅注释、M1/M2/M3/M4/M9 仅注释** 与 spec §3 决策 4 一致。
- **类型一致性：** `onClearAll` 在 provider、screen、测试三处统一为 `Future<bool>`；`_confirmDestructive` 返回 `Future<bool>`；`CacheRelocator` 构造参数在实现、main、测试三处同步删除。
- **Review Focus** 六项均已分配到 Task（见文件顶部）。
