# Flind Player

A cross-platform music player built with Flutter.

## Platforms

| Platform | Priority | Notes |
| -------- | -------- | ----- |
| Android  | Primary  | — |
| Linux    | Primary  | 需要系统 `libmpv` |
| Windows  | Secondary | 内置 mpv |
| macOS    | Secondary | **未签名**预览（保留沙盒，仅加网络权限） |
| iOS      | Secondary | **未签名**预览，需自行签名安装；暂不支持本地曲库 |
| Web      | Deferred (v2) | — |

## Identifiers

- Dart package: `flind_player`
- Android applicationId: `top.qwind.app.flind_player`
- iOS/macOS bundle ID: `top.qwind.app.flindPlayer`
- Linux application ID: `top.qwind.app.flind_player`

## Getting started

```bash
flutter pub get
flutter run -d linux
```

## 构建与发布

### 本地构建

```bash
flutter pub get

# Linux 桌面（需要系统 libmpv，详见 docs/local-library.md）
sudo apt-get install -y libgtk-3-dev libmpv-dev libayatana-appindicator3-dev libsecret-1-dev
flutter build linux --release
# 产物：build/linux/x64/release/bundle/

# Windows 桌面（首次构建时 media_kit_libs_windows_audio 会自动下载预编译的
# mpv 7z 包并做 MD5 校验；若 GitHub 下载不稳定，可手动下载同名归档放到
# build/windows/x64/ 下，见下方「mpv 预编译包」说明）
flutter build windows --release
# 产物：build/windows/x64/runner/Release/（运行 flind_player.exe，已内置 mpv）

# Android 按架构拆分（体积远小于通用包，推荐分发给用户）
flutter build apk --release --split-per-abi
# 产物：app-arm64-v8a-release.apk（现代手机）、app-armeabi-v7a-release.apk（32 位老设备）

# macOS 桌面（未签名，macOS 上构建）
flutter build macos --release
# 产物：build/macos/Build/Products/Release/Flind Player.app

# iOS（未签名，macOS 上构建；CI 会打成未签名 .ipa 供自签安装）
flutter build ios --release --no-codesign
# 产物：build/ios/iphoneos/Runner.app
```

> **mpv 预编译包**：Windows 播放内核 (media_kit) 自带 mpv，不依赖系统库。构建时
> `media_kit_libs_windows_audio` 会从
> `https://github.com/media-kit/libmpv-win32-audio-build/releases/download/2023-09-24/`
> 下载 `mpv-dev-x86_64-20230924-git-652a1dd.7z`（约 5 MB）并校验 MD5
> （`cd738e16e2a19626d7cfa48801524f8c`）。国内网络可能下载失败（表现为生成构建
> 时报 "Integrity check failed"），此时用任意方式手动下载该归档放入
> `build/windows/x64/` 后重新构建即可（CMake 校验通过后不会再下载）。CI 中用
> `actions/cache` 缓存该归档，升级 `media_kit_libs_windows_audio` 时请同步更新
> 工作流中的归档文件名与缓存 key。

> **Apple 平台为未签名预览版**：长期不做签名 / 公证，也不上架 App Store。macOS 解压后需先
> `xattr -dr com.apple.quarantine "Flind Player.app"` 再打开；iOS 的 `.ipa` 未签名，需用
> AltStore / Sideloadly 等工具以你自己的证书签名后安装；iOS 暂不支持本地曲库。

### 签名发布（Android）

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

### 触发发布工作流

打 tag 并推送即可，GitHub Actions 会构建 Linux、Windows 与 Android 产物并创建 Release：

```bash
git tag v0.1.0
git push origin v0.1.0
```

- `.github/workflows/ci.yml`：push 到 `master` 及 PR 时运行分析、测试与 Linux 构建。
- `.github/workflows/release.yml`：tag 推送时运行，需要以下仓库 secrets 才能产出签名 APK：

| Secret | 说明 |
| ------ | ---- |
| `ANDROID_KEYSTORE_BASE64` | keystore 的 base64：`base64 -w0 android/app/keystore.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | keystore 口令 |
| `ANDROID_KEY_ALIAS` | key alias |
| `ANDROID_KEY_PASSWORD` | key 口令 |

缺少 `ANDROID_KEYSTORE_BASE64` 时，发布仍会进行，但 APK 使用 debug 签名。发布说明中
包含 GPL-3.0 §6 要求的对应源码指向（本仓库的对应 tag）。

> **0.1.x 预览版签名**：0.1.x 阶段继续使用 debug 签名，因此**各版本之间不支持覆盖
> 安装**，升级需先卸载旧版本（本地数据会清除）。正式签名计划在 1.0 引入。

> **图标**：全平台图标由 `docs/FlindPlayer.png` 经 `tool/generate_icons.sh` 生成
> （Android 自适应、iOS 无 alpha、Windows 多档 `.ico` 等）。该美术稿是当前占位设计；
> 替换后重跑脚本即可。

## Documentation

- [`docs/architecture.md`](docs/architecture.md) - architecture, layering, decisions (ADR), milestones, risks
- [`docs/bilibili-source.md`](docs/bilibili-source.md) - Bilibili adapter: endpoints, WBI signing, auth, rate limiting
- [`docs/local-library.md`](docs/local-library.md) - local library: scanning, metadata, drift schema, offline cache

## Status

M0–M6 已完成（本地曲库、Bilibili 在线音源、离线缓存、系统集成、队列持久化与收藏）。
当前处于 **0.1.x** 预览阶段：CI 与发布流水线已跑通，使用 debug 签名发布。

已延后：歌词、QR 登录与个人收藏夹（v1.1）、Web 端（v2）。

## License

Licensed under the GNU General Public License v3.0 - see [LICENSE](LICENSE) for the full text.
