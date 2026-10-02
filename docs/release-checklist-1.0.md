# Flind Player 1.0 发布清单

> 状态：进行中（2026-10-02 建立）
> 对应设计：`docs/spec-1.0-hardening-2026-10-02.md` · 计划：`docs/plan-1.0-hardening-2026-10-02.md`

本清单记录仓库侧无法自动完成、需维护者确认的发布前置项。

## Android 正式签名（Task 8）

Gradle 已支持正式签名：存在 `android/key.properties` 时使用其中的 `release` 配置，否则回落 debug（`android/app/build.gradle.kts:10-70`）。仓库侧无需改代码。

- [ ] keystore 已生成：`keytool -genkeypair -v -keystore android/app/keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias flind`
- [ ] 仓库 secrets 已配置：`ANDROID_KEYSTORE_BASE64` / `ANDROID_KEYSTORE_PASSWORD` / `ANDROID_KEY_ALIAS` / `ANDROID_KEY_PASSWORD`
- [ ] 本地 `android/key.properties` 指向 keystore（该文件与 `*.jks` 均已在 `.gitignore` 中）
- [ ] `flutter build apk --release` 后 `apksigner verify --print-certs` 显示的是正式证书（非 `Android Debug`）

> 2026-10-02 复核：当前工作区**没有** `android/key.properties` 或 `android/app/keystore.jks`，第 3–4 项待维护者在本机补齐后勾选。

## GPL-3.0 合规（Task 24）

- [x] Release body 含对应源码指向：`.github/workflows/release.yml` 的 GPL 段落指向本 tag 的仓库快照（2026-10-02 复核存在）。
- [x] 仓库根 `LICENSE` 为 GPL-3.0 全文；README License 段指向正确。
- [ ] **AppImage 内的 libmpv/FFmpeg LGPL 说明**：`packaging/linux/build-appimage.sh` 目前只 `install` 了项目自身的 `LICENSE`（第 50 行），**未见到 libmpv/FFmpeg 的 LGPL 许可文本随包**；`docs/packaging.md` 第 46 行的「包内附许可说明」需据此核实或补齐。
- [x] Windows 包随附 MSVC 可再发行 DLL；`docs/packaging.md` 第 39/46 行有说明。

## 隐私与安全（Task 25）

- [x] 当前无登录实现，代码中**无凭证持久化**（2026-10-02 grep `secure_storage|SESSDATA|MUSIC_U|password|token` 仅命中搜索/CSRF 占位与行注释，无凭证落盘）。
- [x] 权限仅用于音频读取 / 通知 / 网络（`lib/platform/permissions/`）；申请时机与文案见该目录。
- [x] 网络只访问 Bilibili 与网易云；README 与应用内无夸大隐私声明。
