# Flind Player

A cross-platform music player built with Flutter.

## Platforms

| Platform | Priority |
| -------- | -------- |
| Android  | Primary  |
| Linux    | Primary  |
| Windows  | Secondary |
| macOS    | Secondary |
| iOS      | Secondary |
| Web      | Deferred (v2) |

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

# Android
flutter build apk --release
# 产物：build/app/outputs/flutter-apk/app-release.apk
```

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

打 tag 并推送即可，GitHub Actions 会构建 Linux 与 Android 产物并创建 Release：

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

> **图标占位**：当前应用图标仍为占位图（`assets/tray/tray_icon.png`），待维护者选定
> 正式图标后替换。

## Documentation

- [`docs/architecture.md`](docs/architecture.md) - architecture, layering, decisions (ADR), milestones, risks
- [`docs/bilibili-source.md`](docs/bilibili-source.md) - Bilibili adapter: endpoints, WBI signing, auth, rate limiting
- [`docs/local-library.md`](docs/local-library.md) - local library: scanning, metadata, drift schema, offline cache

## Status

Scaffold initialized and architecture designed. Next milestone: **M0** (skeleton + Riverpod wiring + drift + local file playback).

## License

Licensed under the GNU General Public License v3.0 - see [LICENSE](LICENSE) for the full text.
