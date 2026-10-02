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
