# 贡献指南 / Contributing

> 面向开发者。用户下载与使用请看 [README](README.md)。

感谢参与 Flind Player。本文档汇总开发环境、构建、发布、测试、代码结构与文档索引。提交前请确保 `flutter analyze` 零问题、`flutter test` 全绿。

## 📖 目录

- [开发环境](#-开发环境)
- [快速开始](#-快速开始)
- [App 标识](#-app-标识)
- [本地构建](#-本地构建)
- [图标管线](#-图标管线)
- [测试与验证](#-测试与验证)
- [签名发布（Android）](#-签名发布android)
- [发布工作流与 CI](#-发布工作流与-ci)
- [代码结构](#-代码结构)
- [文档索引](#-文档索引)
- [项目状态](#-项目状态)
- [技术栈](#-技术栈)
- [提交约定](#-提交约定)

## 🧰 开发环境

- **Flutter** 3.47.x / **Dart** 3.13+（CI 固定 `3.47.5`）。
- **Linux 构建依赖**：`libgtk-3-dev`、`libmpv-dev`、`libayatana-appindicator3-dev`、`libsecret-1-dev`。
- **图标管线额外依赖**：`ffmpeg`、`python3`、ImageMagick（`convert`）、dev 依赖 `flutter_launcher_icons`。
- 依赖声明见 [`pubspec.yaml`](pubspec.yaml)；Analyzer 规则见 [`analysis_options.yaml`](analysis_options.yaml)。

## 🚀 快速开始

```bash
flutter pub get
flutter run -d linux        # Linux 桌面需要系统 libmpv（见上方依赖）
```

常用平台：`-d linux`、`-d windows`、`-d macos`；Android/iOS 需连接设备或模拟器。

## 📦 App 标识

| 目标 | 标识 |
| --- | --- |
| Dart 包 | `flind_player` |
| Android applicationId | `top.qwind.app.flind_player` |
| iOS / macOS bundle ID | `top.qwind.app.flindPlayer` |
| Linux application ID | `top.qwind.app.flind_player` |

## 🔨 本地构建

<details>
<summary><b>🐧 Linux 桌面</b>（libgtk-3 + libmpv + libayatana-appindicator3 + libsecret）</summary>

```bash
sudo apt-get install -y libgtk-3-dev libmpv-dev libayatana-appindicator3-dev libsecret-1-dev
flutter build linux --release
# 产物：build/linux/x64/release/bundle/
```

安装包（deb / rpm / AppImage）：见 [`docs/packaging.md`](docs/packaging.md)。

</details>

<details>
<summary><b>🪟 Windows 桌面</b>（内置 mpv，无需系统库）</summary>

```bash
flutter build windows --release
# 产物：build/windows/x64/runner/Release/（运行 flind_player.exe）
```

> **mpv 预编译包**：首次构建时 `media_kit_libs_windows_audio` 会从
> `https://github.com/media-kit/libmpv-win32-audio-build/releases/download/2023-09-24/`
> 下载 `mpv-dev-x86_64-20230924-git-652a1dd.7z`（约 5 MB）并校验 MD5
> （`cd738e16e2a19626d7cfa48801524f8c`）。国内网络可能下载失败（表现为构建时报
> "Integrity check failed"），此时用任意方式手动下载该归档放入
> `build/windows/x64/` 后重新构建即可（CMake 校验通过后不会再下载）。CI 中用
> `actions/cache` 缓存该归档，升级 `media_kit_libs_windows_audio` 时请同步更新
> 工作流中的归档文件名与缓存 key。

</details>

<details>
<summary><b>🤖 Android</b>（按架构拆分，体积远小于通用包）</summary>

```bash
flutter build apk --release --split-per-abi
# 产物：app-arm64-v8a-release.apk（现代手机）、app-armeabi-v7a-release.apk（32 位老设备）
```

x86_64 仅用于模拟器，不发布。

</details>

<details>
<summary><b>🍎 macOS</b>（Apple Silicon / arm64，未签名，需在 macOS 上构建）</summary>

```bash
flutter build macos --release
# 产物：build/macos/Build/Products/Release/Flind Player.app
```

</details>

<details>
<summary><b>📱 iOS</b>（未签名，需在 macOS 上构建）</summary>

```bash
flutter build ios --release --no-codesign
# 产物：build/ios/iphoneos/Runner.app（CI 会打成未签名 .ipa 供自签安装）
```

</details>

> **Apple 平台为未签名预览版**：长期不做签名 / 公证，也不上架 App Store。macOS 解压后需先
> `xattr -dr com.apple.quarantine "Flind Player.app"` 再打开；iOS 的 `.ipa` 未签名，需用
> AltStore / Sideloadly 等工具以你自己的证书签名后安装；iOS 暂不支持本地曲库。

## 🎨 图标管线

全平台图标由 [`tool/generate_icons.sh`](tool/generate_icons.sh) 从圆角母版 `docs/FlindPlayer.png`（1120×1120 RGBA）生成：

- `assets/icon/*`：应用图标（含 Android 自适应前景 `app_icon_foreground.png`）；
- `windows/runner/resources/app_icon.ico`、`docs/FlindPlayer.ico`：完整 16–256 多档 `.ico`（Windows 可执行文件与 Inno Setup 安装包）；
- `assets/tray/tray_icon.ico`（Windows 托盘）与 `assets/tray/tray_icon.png`（Linux / macOS 托盘）——托盘与 ico 均使用圆角母版，与 PNG 圆角一致。

替换母版后重跑脚本即可；脚本会同步上述全部产物。**打包前请确保 `build/` 干净**：脚本的 `ensure_bundle()` 会拒绝含有残留 `kernel_blob.bin` 的 release bundle（debug/JIT 产物，会把安装包撑大约 100 MiB）。

## 🧪 测试与验证

| 命令 | 范围 | 门禁 |
| --- | --- | --- |
| `flutter analyze` | 静态分析 | 必须 0 issue |
| `flutter test` | 单元 / 组件测试（当前 **778** 通过） | CI 门禁 |
| `flutter test integration_test` | 真机 / 桌面冒烟（11 用例） | **不在 CI**，需手动运行 |

- 手工回归基线见 [`docs/manual-regression-1.0.md`](docs/manual-regression-1.0.md)。
- 手写 Dart 文件顶部需带 GPL-3.0 文件头；工具生成且不手工编辑的文件（drift `*.g.dart`、`lib/l10n/app_localizations*.dart`）豁免。

## 🔐 签名发布（Android）

1. 生成 keystore（只需一次）：

   ```bash
   keytool -genkeypair -v -keystore android/app/keystore.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias flind
   ```

2. 在 `android/key.properties` 写入（该文件已被 gitignore）：

   ```properties
   storeFile=keystore.jks
   storePassword=****
   keyAlias=flind
   keyPassword=****
   ```

   `android/app/build.gradle.kts` 检测到该文件时使用其中的签名配置；否则回退到
   debug 签名，因此没有密钥也能执行 `flutter build apk --release`。

## 🚢 发布工作流与 CI

打 tag 并推送即可触发构建与发布：

```bash
git tag v1.0.1
git push origin v1.0.1
```

- [`.github/workflows/ci.yml`](.github/workflows/ci.yml)：仅在 `v*-pre*` tag 运行时执行分析、测试与跨平台构建（正式 tag 不跑 CI）。
- [`.github/workflows/release.yml`](.github/workflows/release.yml)：正式 tag 推送时运行；构建前先跑 `analyze-and-test` 门禁，随后构建 Linux / Windows / macOS / iOS / Android 并创建 Release。需要以下仓库 secrets 才能产出**签名** APK：

| Secret | 说明 |
| ------ | ---- |
| `ANDROID_KEYSTORE_BASE64` | keystore 的 base64：`base64 -w0 android/app/keystore.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | keystore 口令 |
| `ANDROID_KEY_ALIAS` | key alias |
| `ANDROID_KEY_PASSWORD` | key 口令 |

缺少 `ANDROID_KEYSTORE_BASE64` 时，正式发布工作流会**直接失败**（不会发布 debug 签名的 APK）。发布说明中包含 GPL-3.0 §6 要求的对应源码指向（本仓库的对应 tag）。

## 🏗️ 代码结构

```
lib/
├── app/            # MaterialApp、主题、语言、DI 装配
├── core/           # 纯 Dart 领域层：models / repositories(抽象) / services(抽象) / sources
├── data/           # drift、音源适配器（bilibili / netease / local）、缓存、播放实现
├── platform/       # audio_service handler、权限、托盘
├── features/       # 一屏一目录：home / library / player / playlists / search / settings
└── shared/         # 通用组件与工具
```

铁律：`features/` 只依赖 `core/` 接口，不 import 具体实现、数据库或播放引擎。详见架构文档。

## 📚 文档索引

| 文档 | 内容 |
| --- | --- |
| [`docs/architecture.md`](docs/architecture.md) | 架构分层、关键决策（ADR）、里程碑与风险 |
| [`docs/bilibili-source.md`](docs/bilibili-source.md) | Bilibili 适配器：端点、WBI 签名、鉴权、限流、法务 |
| [`docs/netease-source.md`](docs/netease-source.md) | 网易云适配器（匿名）：端点、weapi/eapi 协议、能力边界、法务 |
| [`docs/local-library.md`](docs/local-library.md) | 本地曲库：扫描、元数据、drift schema、离线缓存 |
| [`docs/packaging.md`](docs/packaging.md) | 桌面安装包（deb / rpm / AppImage / setup.exe）构建 |
| [`docs/widget-tree.md`](docs/widget-tree.md) | 轻量级 Widget 树总览 |
| [`docs/agent-model-policy.md`](docs/agent-model-policy.md) | Agent 协作与模型使用约定 |
| [`docs/缓存延期问题.md`](docs/缓存延期问题.md) | 缓存评审遗留的延期小问题（触发条件 / 后果） |
| [`docs/耦合TODO.md`](docs/耦合TODO.md) | 设置 / 主题 / 排序的 provider 耦合重构记录 |
| [`docs/manual-regression-1.0.md`](docs/manual-regression-1.0.md) | 手工回归基线 |
| [`docs/release-checklist-1.0.md`](docs/release-checklist-1.0.md) | 1.0 发布清单（签名 / 合规 / 隐私） |
| [`docs/spec-1.0-hardening-2026-10-02.md`](docs/spec-1.0-hardening-2026-10-02.md) | 1.0 加固里程碑设计 |
| [`docs/plan-1.0-hardening-2026-10-02.md`](docs/plan-1.0-hardening-2026-10-02.md) | 1.0 加固实施计划 |
| [`docs/archive/`](docs/archive) | 已完成的设计稿与实施计划 |

## 📈 项目状态

<table align="center">
  <tr>
    <td width="50%" valign="top">
      <h4>✅ 已完成 · M0–M6</h4>
      <ul>
        <li>本地曲库（扫描 + 元数据 + FTS5 检索）</li>
        <li>Bilibili / 网易云在线音源</li>
        <li>离线缓存（1 GiB 默认 · LRU · pinned）</li>
        <li>系统集成（Android 通知栏 / Linux MPRIS / Apple Now Playing / 桌面托盘）</li>
        <li>队列持久化、收藏与自建歌单</li>
        <li>同步歌词（时间轴高亮 · 自动滚动 · 双语）</li>
        <li>CI 与发布流水线（含签名与门禁）</li>
      </ul>
    </td>
    <td width="50%" valign="top">
      <h4>⏳ 延后</h4>
      <ul>
        <li>Android 本地曲库（1.1）</li>
        <li>QR 登录与个人收藏夹（v1.1）</li>
        <li>Windows SMTC 等 OS 媒体控制（1.1 评估）</li>
        <li>自建歌单手动排序</li>
        <li>Web 端（v2）</li>
        <li>Apple 平台签名 / 公证 / TestFlight（长期推迟）</li>
      </ul>
    </td>
  </tr>
</table>

## 🧰 技术栈

| 层 | 技术 | 说明 |
| --- | --- | --- |
| UI | Flutter · Material 3 | 自适应断点（< 600px 紧凑模式 / 宽屏模式） |
| 状态管理 | `flutter_riverpod` 3 | Notifier + 依赖注入 |
| 播放引擎 | `just_audio` + `audio_service` | 桌面端经 `just_audio_media_kit`（libmpv） |
| 数据库 | `drift`（SQLite + FTS5） | 曲库 / 收藏 / 队列持久化 |
| 网络 | `dio` | WBI 签名请求 + CDN 防盗链头 |
| 桌面 | `tray_manager` · `window_manager` | 系统托盘、关闭到托盘 |
| 国际化 | flutter gen-l10n | 简体中文 / English |

## ✅ 提交约定

- 提交信息沿用 `type(scope): 描述`（如 `fix(settings): ...`、`docs(readme): ...`）。
- 提交前运行 `flutter analyze` 与 `flutter test`，两者通过再提交。
- 新增或改动行为请附带测试；涉及缓存驱逐 / 配额时补极限场景测试。
