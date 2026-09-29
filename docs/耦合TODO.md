# 主题模块耦合度重构 TODO

> 状态:三个阶段均已实现(2026-09-30,分支 `refactor/decouple-settings-providers`:
> `646276b` ① / `e5882ef` ② / `42ab091` ③ / `e95bd23` 复核修正)。原 2026-09-29
> 复核结论(`settingsRepositoryProvider` 仍在 `cache_providers.dart`、阶段 ① 未执行)已过期。
> 所有阶段均为纯结构重构,无行为变化;验证标准见文末(`flutter analyze` 0 issue,
> `flutter test` 688 全绿)。

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

**必要性判定**:有必要,但**非紧急**。按阶段拆分,低风险先行;②③ 原挂起等触发条件。

> ⚠️ §一 / §二 记录的是**重构前**的耦合现状与原方案,保留作背景对照。
> 实际落地结果(文件名、接口归属、涉及文件数)以 §三 成本汇总的提交号、
> `lib/core/repositories/settings_repository.dart` 与
> `lib/data/providers/settings_repository_provider.dart` 为准。

---

## 二、改动方案

### 阶段 ① 抽取 `data/providers/settings_repository_provider.dart`(低风险)

**改动面**:

| 动作 | 文件 |
|---|---|
| 新建 | `lib/data/providers/settings_repository_provider.dart`:放入 `settingsRepositoryProvider`(自 `cache_providers.dart` 移出,仅 `Provider<SettingsRepository>` 一个符号) |
| 修改 | `lib/data/providers/cache_providers.dart`:`import` settings_repository_provider.dart;移除本文件的 provider 定义;原第 47、57 行引用改为经 import |
| 改 import | `lib/app/theme_mode.dart`、`lib/app/language.dart`、`lib/features/library/library_sort_provider.dart`、`lib/features/library/library_view_provider.dart` —— 仅依赖 `settingsRepositoryProvider`,`cache_providers.dart` 换为 settings_repository_provider.dart |
| 加 import | `lib/features/settings/settings_screen.dart` —— 同时用到 cache 与 settings,新增 settings import、保留 cache import |
| 不动 | `lib/main.dart`、`lib/features/settings/settings_providers.dart`、`lib/features/library/widgets/track_actions_button.dart`、`lib/features/library/widgets/cache_action_button.dart`、`lib/data/providers/playback_providers.dart`、`lib/data/providers/cover_providers.dart` —— 均不使用 `settingsRepositoryProvider`,import 保持指向 `cache_providers.dart` |

> 执行时先 grep 逐一确认上述分类后动手(防止依赖漂移)。
>
> **命名陷阱(2026-09-29 提出,已按建议规避)**:仓库里已存在
> `lib/features/settings/settings_providers.dart`(放 `packageInfoProvider` 等)。
> 原方案的新文件与之**同名不同目录**,IDE 补全与 `import` 极易指错 ——
> 落地时改用 `settings_repository_provider.dart`,冲突未发生。
>
> **与原方案的偏差(执行时按 grep 重新判定)**:原表把 `cover_providers.dart`
> 列为"加 import",但它实际不使用 `settingsRepositoryProvider`,**未改动**;
> 反之原表漏列了 `library_view_provider.dart`(v0.5.0 新增,依赖该 provider),已补入。

**成本**:1 个新文件 + 6 处 import 调整。约 **0.5–1 小时**。
**风险**:低(纯机械 import 替换,测试全绿兜底)。
**硬性要求**: **不做 re-export**。若 `cache_providers.dart` 用 `export` 反向透出,
"改名换面"使 10 处 import 原样保留,本阶段意义归零。

### 阶段 ② 接口隔离拆分 `SettingsRepository`(中等)

**改动面**:

| 接口 | 成员 |
|---|---|
| `CacheSettingsRepository` | `cacheSettings` / `updateCacheSettings` / `watchCacheSettings` |
| `LibrarySettingsRepository` | `librarySort` / `setLibrarySort` / `libraryViews` / `setLibraryView` |
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

> **与原方案的偏差(执行时判定)**:上表的 `LibrarySettingsRepository` 原只列
> `librarySort` / `setLibrarySort`。实际把 `libraryViews` / `setLibraryView`
> 也归入该切片 —— 它们的唯一消费者是 `library_view_provider.dart`,同属"曲库展示"。
> 另把 `AudioCacheStore` 的依赖收窄到 `CacheSettingsRepository`
> (它只用 `cacheSettings()`),而非整个 composite。
>
> 触发条件 1/2 并未发生;本阶段是作为 ① 的收尾一并执行的
> (避免"抽出了 provider 却仍对着上帝接口"这种半途状态)。

### 阶段 ③ 测试 fake 抽公共(可与 ② 合并,或独立)

**改动面**:
- 新建 `test/support/fake_settings_repository.dart`(按阶段②的小接口实现)+ 其自测
  `test/support/fake_settings_repository_test.dart`;
- 原列 8 个测试文件,执行时 grep 发现**第 9 份复制**
  (`track_deletion_service_test.dart`),连同 `cache_relocator_test` /
  `download_manager_cover_test` / `library_view_provider_test` /
  `offline_cache_providers_test` 一并迁移 —— 实测共 **13** 个测试文件引用共享 fake:
  `audio_cache_store_test` / `cached_stream_resolver_test` / `cache_relocator_test` /
  `cover_cache_store_test` / `cover_service_test` / `download_manager_cover_test` /
  `download_manager_test` / `home_shell_test` / `library_view_provider_test` /
  `offline_cache_providers_test` / `responsive_layout_test` / `settings_screen_test` /
  `track_deletion_service_test`。

**目的**:消除 9 份复制导致的**漂移风险**(接口语义变化时漏改某一份)。

**成本**:约 **0.5–1 小时**。**风险**:低–中。

> 切片隔离靠 `noSuchMethod` + 每切片 mixin 实现,并配
> `test/settings_repository_segregation_test.dart` 的**全切片 throw matrix**
> 证明:调用未实现的切片会在运行期抛错,而非静默通过(复核阶段补齐,
> 原先只证明了 cache 一个切片)。

---

## 三、成本汇总

| 阶段 | 改动面 | 风险 | 耗时 | 状态 |
|---|---|---|---|---|
| ① 抽取 settings 提供者文件 | 1 新文件 + 6 处 import | 低 | 0.5–1h | ✅ `646276b` |
| ② 接口隔离 | 2 生产文件 + 8 测试文件 | 中 | 1–2h | ✅ `e5882ef` |
| ③ 共享测试 fake | 10 测试文件 + 1 support 文件 | 低–中 | 0.5–1h | ✅ `42ab091` |
| **合计** | — | — | **2–4h**(分阶段,非连续) | ✅ 复核修正 `e95bd23` |

## 四、明确不做

- 不改 `AppTheme` / `AppThemeMode` 内部 —— 已足够干净,保持。
- 拆分回 `CacheSettings` 位置不动(属缓存域,不属主题模块)。
- 不做多 provider 拆分 —— 只拆**接口**,不拆**提供者合成点**。

## 五、复核遗留的 minor(未修,按需再取)

`e95bd23` 复核无 Critical,唯一的 Important(切片隔离只证明了 cache 一个切片)
已修。以下 4 项 minor 按"不修"处理,记录在此备查:

| # | 事项 | 位置 | 说明 |
|---|---|---|---|
| m1 | 缓存类测试仍绑定完整 composite fake | `test/*_test.dart`(仅 `track_deletion_service_test` 收窄) | 未用 `FakeCacheSettings` 单切片,切片隔离的收益在这些文件里没兑现 |
| m2 | 共享 fake 暴露了当前无人读取的成员 | `test/support/fake_settings_repository.dart` `writes` / `sort` / `views` | 预留给将来断言语义,当前无测试读 |
| m3 | provider 文件的文档注释仍用缓存域措辞 | `lib/data/providers/settings_repository_provider.dart` 首行 "including the offline cache configuration" | 该文件现在是跨域设置提供者,首句框架已过时(第二段的动机说明仍准确) |
| m4 | `_CacheSliceFake` 重复了 cache mixin | `test/settings_repository_segregation_test.dart` | 应复用 `support/fake_settings_repository.dart` 的 `FakeCacheSettings` |
| m5 | 死的设置 fixture | `test/cover_cache_store_test.dart` | `settings` 构造后仅 `line 176` 改值、**从未注入**;层 2 固定 256 MiB 不读设置,故该 fixture 无作用(重构前遗留) |

## 六、验证标准(每阶段执行后)

1. `flutter analyze` 0 error;
2. `flutter test` 全绿;
3. diff 仅含 import 调整与接口声明变化,无行为逻辑变更。