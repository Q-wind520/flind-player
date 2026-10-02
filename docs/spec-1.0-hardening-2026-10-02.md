# 设计：1.0 加固里程碑（v1.0.0）

- 日期：2026-10-02
- 状态：**草案（待评审）**
- 范围：版本与发布工程、文档—实现同步、1.0 触发型技术债清理、功能覆盖一致性、质量门禁、依赖与工具链冻结、合规与安全复核
- 目标读者：实现者
- 关联：[`docs/architecture.md`](architecture.md)、[`docs/缓存延期问题.md`](缓存延期问题.md)、[`docs/耦合TODO.md`](耦合TODO.md)、[`docs/local-library.md`](local-library.md)、[`docs/packaging.md`](packaging.md)、[`.github/workflows/ci.yml`](../.github/workflows/ci.yml)、[`.github/workflows/release.yml`](../.github/workflows/release.yml)
- 计划：`docs/plan-1.0-hardening-2026-10-02.md`（本文批准后由 writing-plans 产出）

## 1. 背景

功能里程碑 M0–M6 已全部落地；自 `v0.6.1` 起又合入 36 个提交（网易云音乐音源、在线源注册表、同步双语歌词），`pubspec.yaml` 已到 `0.7.0+12` 但**尚未发布**。

两份现行文档已把「进入 1.0 加固期」写成延期项的触发条件：

- `docs/缓存延期问题.md` §四：「出现用户反馈，**或进入 1.0 功能加固期**」。
- `docs/耦合TODO.md` 阶段②触发条件 3：「**进入 1.0 代码加固期**」。

同时，仓库存在若干**文档—实现漂移**与**发布流程缺口**：

- `README.md` 版本 badge 仍为 `0.2.1`，测试数在不同处写 581 / 688（按 `test()`/`testWidgets()` 计数约 711 单测 + 11 集成，**实际数量以实跑为准**），歌词仍写「仅占位」，功能表漏第二音源，并错误描述 CI 触发时机。
- `docs/architecture.md` §5 列的 `lib/app/router.dart`（go_router）与 `features/account/` 在代码中**不存在**；§12.1 依赖表列了 `pubspec.yaml` 中没有的包，D8 的 `flutter_secure_storage` 在 `lib/` 中零引用。
- `.github/workflows/release.yml` 在正式 tag 上**不跑 analyze/test** 直接构建发布；`ci.yml` 只在 `v*-pre*` tag 触发。
- Android release 仍回落 **debug 签名**；正式签名被明确承诺在 1.0 引入。

本设计把上述内容收敛为一个「加固里程碑」，作为 1.0 的发布基线，然后据此生成实施计划。

## 2. 目标与非目标

### 目标

- **发布 v1.0.0**：版本号、CHANGELOG、Android 正式签名、发布门禁全部就位。
- **文档与实现一致**：README / architecture / local-library / packaging 与代码、工作流对齐。
- **清理 1.0 触发型技术债**：缓存延期项与耦合 minor 逐项给出「修 / 说明 / 继续延期」的结论。
- **锁定可发布基线**：依赖与 Flutter 工具链冻结，retracted/危险依赖处理完毕。
- **补合规与安全复核**：GPL-3.0 分发义务、音源 ToS 姿态、隐私与凭证检查。
- **建立质量基线**：analyze/test/构建矩阵实跑 + 手工回归清单，作为 1.0 的验收证据。

### 非目标（明确不做）

- **不做 Android 本地曲库**（决策 D1）：不改文档声称的实现，改为**降级文档声明**，保留现有目录扫描路径，`MediaStoreAdapter` 推迟。
- **不做登录**：Bilibili QR / 网易云 `MUSIC_U` 均不做，维持匿名能力边界（README 已注明留 v1.1）。
- **不做依赖大版本升级**：`file_picker` 12→13、`permission_handler` 12→13 等放 1.1（决策 F2）。
- **不做架构重构**：本里程碑只做结构性小改与文档同步。
- **不做 Web**（架构 D11 → v2）；**不做 Apple 签名 / 公证 / TestFlight**。
- **不以 Google Play 审核通过为发布门槛**：仅产出 AAB 并补齐隐私文档。
- **不做歌词磁盘缓存 / 逐字歌词**（沿用现状）。
- **不修 P5**（`freedBytes`/`evictedCount` 展示口径与并发软上限，已知行为）。

## 3. 已确认的语义决策

1. **D1**：Android 本地曲库**降级文档声明**。README 与 `local-library.md` 明确「Android 本地曲库延后」，`local_library_scanner.dart:271` 的 `TODO(android-m2)` 改为指向该延期声明；不改实现。
2. **Android 正式签名纳入 1.0**；keystore 与仓库 secrets 是否就绪是 **Phase 1 前置动作**，未就绪则先补齐再打正式 tag。
3. **产出 AAB 但不以 Play 审核为门槛**；仅补齐隐私政策文档。
4. **缓存 9 项（C1）处理深度**：修廉价且安全项（M5 提示区分成败、M6 离线标题用歌名、M7 确认弹窗去重、M8 启动直接删旧层 2、M3 过期注释更正），其余（M1/M2/M4/M9/P2）在代码处补「为何安全 / 触发条件」注释并保留延期。
5. **耦合 minor（C2）**：顺手清 m3（过时注释）、m4（复用共享 fake）、m5（死 fixture）；m1/m2 记录为已知不修。
6. **集成测试（E3）不进 CI**：建立 `docs/` 手工回归基线（11 个 integration_test 用例 + 平台清单）。
7. **依赖策略（F2）**：1.0 只处理 retracted 的 `objective_c` 与 `tray_manager` vendored override；大版本升级放 1.1。

## 4. 工作流

工作流之间基本独立，可并行；编号 A–F 与现状证据对应。

### A. 版本与发布工程

| # | 事项 | 现状证据 | 结论 |
|---|---|---|---|
| A1 | 版本号统一到 `1.0.0+13` 并冻结 | `pubspec.yaml:4` = `0.7.0+12`；README badge `0.2.1`；`packaging.md:18-29` 示例 `0.5.0` | 必做 |
| A2 | macOS/iOS 版本元数据与 pubspec 对齐 | `macos/...project.pbxproj:410-412`、`ios/...:414-416` 硬编码 `MARKETING_VERSION=1.0` / `CURRENT_PROJECT_VERSION=1` | 必做 |
| A3 | 建立 `CHANGELOG.md`，补 `1.0.0`（归纳 `v0.6.1..HEAD` 36 个提交） | 仓库无 CHANGELOG | 必做 |
| A4 | **发布门禁**：让正式 tag 在构建前跑 analyze + test | `release.yml:3-6,325-327` 无测试 job；`ci.yml:7-10` 仅 `v*-pre*`；`README.md:249` 描述错误 | 必做（见 §6） |
| A5 | Android 正式签名落地 | `android/app/build.gradle.kts:56-70` 回落 debug | 必做（Phase 1 前置） |
| A6 | 升级路径说明：签名变更导致旧版不可覆盖安装 | `release.yml:391-397`、`README.md:212-213` 仍写 `0.1.x`/`0.2.x` | 必做 |
| A7 | `dist/` 旧产物清理与忽略确认 | `dist/` 未被 git 跟踪（`.gitignore` 已含 `/dist/`） | 顺手 |
| A8 | 是否开启 `minifyEnabled`/`shrinkResources` | `build.gradle.kts:66-69` 关闭 | 评估后定（默认不改） |

### B. 文档与元数据同步

| # | 事项 | 现状证据 | 结论 |
|---|---|---|---|
| B1 | README 全面刷新：版本、测试数、歌词状态、第二音源、CI 描述、签名措辞、docs 索引 | `README.md:13,17,249,299,212-213,266-276` | 必做 |
| B2 | `architecture.md` 与代码对齐：删除不存在的 `router.dart`/`account/` 描述，修正 §12.1 依赖表与 D8，补 netease/歌词定位 | `docs/architecture.md:106-141,393-410,52` | 必做 |
| B3 | `local-library.md` 明确 Android 本地曲库延后（决策 D1） | `docs/local-library.md:21-37,462-464` 声称 MediaStore 支持 | 必做 |
| B4 | GPL 文件头策略：补 `lib/app/l10n.dart`；对生成文件（`app_database.g.dart`、`lib/l10n/app_localizations*.dart`）明确豁免并记录 | 129/134 带头 | 必做 |
| B5 | 文档索引/归档：netease spec+plan 是否移入 `archive/`；两份延期文档在 C 完成后更新状态 | `docs/` 目录 | 顺手 |

### C. 1.0 触发型技术债

| # | 事项 | 现状证据 | 结论 |
|---|---|---|---|
| C1 | 缓存延期 9 项（M1–M9）逐项处理，P2 补注释，P5 不修 | `docs/缓存延期问题.md` §一/§二 | 按决策 4 执行 |
| C2 | 耦合 minor m1–m5 | `docs/耦合TODO.md:143-154` | 按决策 5 执行 |
| C3 | `TODO(android-m2)` 改为指向 D1 延期声明 | `lib/data/sources/local/local_library_scanner.dart:271` | 必做（随 D1） |

### D. 功能覆盖一致性

| # | 事项 | 现状证据 | 结论 |
|---|---|---|---|
| D1 | Android 本地曲库降级声明 | `README.md:108`（只把不支持标注给 iOS）、`docs/local-library.md:21-37` | 必做（决策 1） |
| D2 | 平台能力矩阵核对（本地库/播放/系统集成）与实际实现一致 | `README.md:100-110`、`docs/architecture.md:332-344` | 必做 |
| D3 | 音源与歌词能力边界（匿名、Bilibili 公开收藏夹）与 UI/文档一致 | `docs/netease-source.md`、`docs/bilibili-source.md` | 核对 |
| D4 | 远程禁用 / capability 钩子确认真实可运维 | `docs/architecture.md:193-197` | 核对 |

### E. 质量门禁与验证

| # | 事项 | 结论 |
|---|---|---|
| E1 | `flutter analyze` 零 issue（**实跑确认**，不留推断） | 必做基线 |
| E2 | `flutter test` 全绿（**实跑确认**）+ 校准 README 数字 | 必做基线 |
| E3 | `integration_test/`（11 用例）手工回归基线文档，不进 CI | 必做 |
| E4 | 覆盖率基线（`dart-collect-coverage`） | 可选 |
| E5 | 五平台 release 构建矩阵实跑 + Linux/Windows 打包脚本冒烟 | 必做 |
| E6 | 手工回归清单：缓存极限淘汰、流过期 403 自愈、断网启动、覆盖升级数据保留 | 必做 |

### F. 依赖、工具链、合规与安全

| # | 事项 | 现状证据 | 结论 |
|---|---|---|---|
| F1 | `tray_manager` vendored override：确认上游 `0.7.0` 是否已含 PR #93，能删则删 | `pubspec.yaml:38,92-100`、`flutter pub outdated` | 必做 |
| F2 | 处理 retracted `objective_c 9.6.1`；大版本升级推迟 | `flutter pub outdated` | 必做 |
| F3 | 工具链基线冻结：CI Flutter `3.47.3`、`.metadata` revision 核对 | `.github/workflows/*.yml:32` | 必做 |
| F4 | GPL-3.0 合规复核：对应源码指向、AppImage 内 libmpv/FFmpeg LGPL 说明、Windows MSVC 再分发、第三方许可清单 | `release.yml:355-373`、`docs/packaging.md:46` | 必做 |
| F5 | 安全/隐私：确认无凭证落盘（当前无登录）、权限申请时机与文案、网络请求隐私披露 | 代码 + 文档 | 必做 |
| F6 | 音源 ToS/风控姿态复核（律师函背景、远程禁用、不做带凭证公共代理） | `docs/bilibili-source.md`、`docs/netease-source.md` | 核对 |

## 5. 验收标准（Definition of Done）

1. `flutter analyze` 0 issue；`flutter test` 全绿（实跑输出为准）。
2. Linux / Windows / Android release 构建通过；Linux/Windows 打包脚本冒烟通过；macOS / iOS 至少手工确认一次成功（是否移除 `continue-on-error` 由实跑结果决定）。
3. `pubspec.yaml` 版本为 `1.0.0+13`；`CHANGELOG.md` 含 1.0.0 条目；macOS/iOS 版本元数据与之一致。
4. Android 正式签名验证通过（`apksigner verify` / AAB 签名检查）；release notes 说明签名变更与升级路径。
5. 正式 tag 的发布流程在构建前执行 analyze + test 门禁（决策见 §6）。
6. README / architecture / local-library / packaging 与代码、工作流、依赖表一致；docs 索引完整。
7. C1/C2 每项有结论（修复或带原因保留）；`TODO(android-m2)` 指向 D1 声明。
8. `integration_test` 手工回归基线文档存在且通过；E6 清单通过。
9. F1/F2 处理完毕，依赖可解析、无 retracted；GPL 与隐私复核清单完成。
10. 发布 `v1.0.0`，资产列表完整（Linux deb/rpm/AppImage/tar.gz、Windows setup/zip、macOS zip、iOS ipa、Android APK/AAB）。

## 6. 发布门禁方案

当前正式 tag 直接构建发布，无测试门禁（`release.yml:3-6`），这是 1.0 最主要的流程风险。

- **推荐**：在 `release.yml` 增加一个 `analyze-and-test` job，并让所有 build job `needs` 它；这样正式发布天然带门禁，`continue-on-error` 的 Apple job 不受影响。
- **保底流程**：先打 `v1.0.0-pre+1` 走 CI 全绿，再打正式 `v1.0.0`。
- 二者不互斥：推荐同时执行，pre tag 用于验证，release 门禁用于防呆。

## 7. 风险与对策

| 风险 | 等级 | 对策 |
|---|---|---|
| 签名切换到正式 key 后旧安装不可覆盖升级 | 高 | release notes + README + 应用内「关于」明确提示；首次正式版说明 |
| Android 本地库降级若漏改某处文档，用户误解为已支持 | 中 | D1 单独作为 checklist 项，grep `README`/`local-library`/architecture 全量核对 |
| 清理缓存/耦合 minor 引入回归 | 中 | 每项配对应测试；缓存涉及驱逐/配额时补极限场景测试 |
| retracted 依赖拖到发布日才暴露 | 中 | F2 在 Phase 1 处理并实跑 `pub get` / 构建 |
| 正式发布无测试门禁导致带病发布 | 高 | §6 门禁方案；pre tag 双保险 |
| 文档声称与实现继续漂移 | 中 | B2 以「grep 代码再改文档」为准；验收第 6 条 |

## 8. 文档产物

实现完成后应更新/新增：

- 新增 `CHANGELOG.md`
- 新增 `docs/plan-1.0-hardening-2026-10-02.md`（本 spec 批准后产出）
- 更新 `README.md`、`docs/architecture.md`、`docs/local-library.md`、`docs/packaging.md`
- 更新 `docs/缓存延期问题.md`、`docs/耦合TODO.md` 状态
- 新增 `docs/manual-regression-1.0.md`（E3/E6 手工回归基线）
- 归档 `docs/spec-netease-source-2026-10-01.md` / `plan-netease-source-2026-10-01.md`（B5）
