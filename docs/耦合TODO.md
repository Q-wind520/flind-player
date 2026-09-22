# 主题模块耦合度重构 TODO

> 状态:分析完成,方案已定,尚未动手。
> 原则:**不改动任何代码,直到本文件中的某一阶段被显式触发执行。**
> 所有阶段均为纯结构重构,无行为变化;验证标准见文末。

---

## 一、问题背景与现状

`AppTheme` / `AppThemeMode` 枚举内部耦合极低(仅依赖 `material` / 纯枚举),
但**接线层**存在三处结构性耦合:

```text
lib/app/theme_mode.dart  ──► lib/data/providers/cache_providers.dart   ⚠️ ①
lib/app/language.dart    ──► lib/data/providers/cache_providers.dart   ⚠️ ①
lib/features/library/library_sort_provider.dart ──► cache_providers.dart ⚠️ ①

core/repositories/settings_repository.dart ── 10 方法"上帝接口"          ⚠️ ②
   └─ 8 个测试文件各自复制 _FakeSettingsRepository 并 stub 主题方法       ⚠️ ③
```

`cache_providers.dart` 内部本体是 `dart:io` + `path_provider` + Bilibili 客户端
/WBI 签名/限流 + 数据库 + 下载管理器/流解析器。`settingsRepositoryProvider`(跨
领域设置依赖)被塞在这个缓存域文件里,导致主题/语言/设置为了取一个设置 provider
而 import 整个数据层依赖图。

**当前影响**:无运行时成本(Riverpod provider 惰性)、无现有测试失败。成本是
维护性、滞后性的——在"新增设置类型 / 主题功能扩展 / 新人排查设置代码"时显形。

**必要性判定**:有必要,但**非紧急**。按阶段拆分,低风险先行;②③ 挂起等触发条件。

---

## 二、改动方案

### 阶段 ① 抽取 `data/providers/settings_providers.dart`(低风险,推荐现在做)

**改动面**:

| 动作 | 文件 |
|---|---|
| 新建 | `lib/data/providers/settings_providers.dart`:放入 `settingsRepositoryProvider`(自 `cache_providers.dart` 移出,仅 `Provider<SettingsRepository>` 一个符号) |
| 修改 | `lib/data/providers/cache_providers.dart`:`import` settings_providers.dart;移除本文件的 provider 定义;第 47、57 行引用改为经 import |
| 改 import | `lib/app/theme_mode.dart`、`lib/app/language.dart`、`lib/features/library/library_sort_provider.dart` —— 仅依赖 `settingsRepositoryProvider`,`cache_providers.dart` 换为 `settings_providers.dart` |
| 加 import | `lib/data/providers/cover_providers.dart`、`lib/features/settings/settings_screen.dart` —— 同时用到 cache 与 settings,新增 settings import、保留 cache import |
| 不动 | `lib/main.dart`、`lib/features/settings/settings_providers.dart`、`lib/features/library/widgets/track_actions_button.dart`、`lib/features/library/widgets/cache_action_button.dart`、`lib/data/providers/playback_providers.dart` —— 均不使用 `settingsRepositoryProvider`,import 保持指向 `cache_providers.dart` |

> 执行时先 grep 逐一确认上述分类后动手(防止依赖漂移)。

**成本**:1 个新文件 + 5 处 import 调整。约 **0.5–1 小时**。
**风险**:低(纯机械 import 替换,测试全绿兜底)。
**硬性要求**: **不做 re-export**。若 `cache_providers.dart` 用 `export` 反向透出,
"改名换面"使 10 处 import 原样保留,本阶段意义归零。

### 阶段 ② 接口隔离拆分 `SettingsRepository`(中等,挂起)

**改动面**:

| 接口 | 成员 |
|---|---|
| `CacheSettingsRepository` | `cacheSettings` / `updateCacheSettings` / `watchCacheSettings` |
| `LibrarySettingsRepository` | `librarySort` / `setLibrarySort` |
| `AppearanceSettingsRepository` | `appLanguage` / `setAppLanguage` / `appThemeMode` / `setAppThemeMode` |

- `PrefsSettingsRepository` 改为 `implements CacheSettingsRepository, LibrarySettingsRepository, AppearanceSettingsRepository`。
- **`settingsRepositoryProvider` 保持单一 provider 不变** —— 测试 override 点不增加。
- 测试 fakes:按需仅实现所需接口切片(缓存测试不再 stub 主题/语言/排序)。

**成本**:接口文件 + 实现文件 + 8 个测试文件的 fake 收窄。约 **1–2 小时**。
**风险**:中(涉及测试文件;测试覆盖足以兜底)。
**触发条件**(任一满足再执行):
1. 计划新增设置类型(如播放偏好、缓存策略选项);
2. 主题功能要扩展(自定义强调色、跟随壁纸等);
3. 进入 1.0 代码加固期。

### 阶段 ③ 测试 fake 抽公共(可与 ② 合并,或独立)

**改动面**:
- 新建 `test/support/fake_settings_repository.dart`(按阶段②的小接口实现);
- 8 个测试文件(`audio_cache_store_test` / `cached_stream_resolver_test` /
  `cover_service_test` / `cover_cache_store_test` / `download_manager_test` /
  `home_shell_test` / `responsive_layout_test` / `settings_screen_test`)改为引用共享 fake。

**目的**:消除 8 份复制导致的**漂移风险**(接口语义变化时漏改某一份)。

**成本**:约 **0.5–1 小时**。**风险**:低–中。

---

## 三、成本汇总

| 阶段 | 改动面 | 风险 | 耗时 | 状态 |
|---|---|---|---|---|
| ① 抽取 settings 提供者文件 | 1 新文件 + 5 处 import | 低 | 0.5–1h | ⏸ 可立即执行 |
| ② 接口隔离 | 2 生产文件 + 8 测试文件 | 中 | 1–2h | ⏸ 等触发条件 |
| ③ 共享测试 fake | 9 测试文件 | 低–中 | 0.5–1h | ⏸ 随 ② 或独立 |
| **合计** | — | — | **2–4h**(分阶段,非连续) | — |

## 四、明确不做

- 不改 `AppTheme` / `AppThemeMode` 内部 —— 已足够干净,保持。
- 拆分回 `CacheSettings` 位置不动(属缓存域,不属主题模块)。
- 不做多 provider 拆分 —— 只拆**接口**,不拆**提供者合成点**。

## 五、验证标准(每阶段执行后)

1. `flutter analyze` 0 error;
2. `flutter test` 全绿;
3. diff 仅含 import 调整与接口声明变化,无行为逻辑变更。