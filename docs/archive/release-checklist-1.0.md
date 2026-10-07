# Flind Player 1.0 发布清单

> 状态：**已完成** —— v1.0.0 已于 2026-10-02 发布。
> 对应设计：`docs/spec-1.0-hardening-2026-10-02.md` · 计划：`docs/plan-1.0-hardening-2026-10-02.md`

本清单记录仓库侧无法自动完成、需维护者确认的发布前置项。

## Android 正式签名（Task 8）

Gradle 已支持正式签名：存在 `android/key.properties` 时使用其中的 `release` 配置，否则回落 debug（`android/app/build.gradle.kts:10-70`）。仓库侧无需改代码。

- [x] keystore 已生成（`android/app/keystore.jks`，gitignored，`CN=Qwind520`）。
- [x] 仓库 secrets 已配置（2026-10-02 核对存在）：`ANDROID_KEYSTORE_BASE64` / `ANDROID_KEYSTORE_PASSWORD` / `ANDROID_KEY_ALIAS` / `ANDROID_KEY_PASSWORD`。
- [x] 签名在 CI 完成（`release.yml` 的 Android job 从 secrets 写 `android/key.properties`）；本地无需 `key.properties`。
- [x] 正式发布 `v1.0.0` 的 APK/AAB 经 `apksigner` / `keytool` 验证为正式证书：`CN=Qwind520`，SHA-256 `56BCDDC7…5CA192C5`（非 `Android Debug`）。

> 2026-10-02 复核：keystore 与 secrets 均已就绪；`release.yml` 现在缺少 `ANDROID_KEYSTORE_BASE64` 时会直接失败，杜绝 debug 签名混入正式发布。

## GPL-3.0 合规（Task 24）

- [x] Release body 含对应源码指向：`.github/workflows/release.yml` 的 GPL 段落指向本 tag 的仓库快照（2026-10-02 复核存在）。
- [x] 仓库根 `LICENSE` 为 GPL-3.0 全文；README License 段指向正确。
- [x] **AppImage 内的 libmpv/FFmpeg LGPL 说明**：`packaging/linux/build-appimage.sh:49` 以 `write_copyright … yes` 生成 `/usr/share/doc/flind-player/copyright`，内含 `License: LGPL-2.1+` 声明（libmpv/FFmpeg 随包分发）；deb/rpm 传 `no`（系统提供）。**剩余待决**：是否需随包附 LGPL-2.1 **全文**（当前仅声明 + 指向上游）。
- [x] Windows 包随附 MSVC 可再发行 DLL；`docs/packaging.md` 第 39/46 行有说明。

## 隐私与安全（Task 25）

- [x] 当前无登录实现，代码中**无凭证持久化**（2026-10-02 grep `secure_storage|SESSDATA|MUSIC_U|password|token` 仅命中搜索/CSRF 占位与行注释，无凭证落盘）。
- [x] 权限仅用于音频读取 / 通知 / 网络（`lib/platform/permissions/`）；申请时机与文案见该目录。
- [x] 网络只访问 Bilibili 与网易云；README 与应用内无夸大隐私声明。

## 音源 ToS / 风控复核（Task 26）

- [x] `docs/bilibili-source.md` §1/§4.3/§5：个人使用姿态、不内置凭证、不做带凭证公共代理、音源可远程禁用（律师函时间线见 §1）。
- [x] `docs/netease-source.md` §1/§6：weapi/eapi 私有协议风险、零登录态、匿名 Cookie 仅占位、`disabledSourceIdsProvider` 为唯一禁用钩子（禁用后搜索/流/歌词一并不可达）。
- [x] 复核日期：2026-10-02。结论：法务与风控姿态与实现一致，无需改动。

## 构建矩阵（Task 28，2026-10-02）

本机环境：Linux x64，Flutter 3.47.5 / Dart 3.13.4。

- [x] `flutter build linux --release` → 成功（`build/linux/x64/release/bundle/flind_player`）。
- [x] `packaging/linux/build-deb.sh --version 1.0.0` → `dist/FlindPlayer-v1.0.0-linux-x64.deb`。
- [x] `packaging/linux/build-appimage.sh --version 1.0.0` → `dist/FlindPlayer-v1.0.0-linux-x64.AppImage`。
- [x] `packaging/linux/build-rpm.sh --version 1.0.0` → 本机缺 `rpmbuild`；已由 release CI 产出 `FlindPlayer-v1.0.0-linux-x64.rpm` 验证。
- [x] `flutter build apk --release --split-per-abi` → arm64-v8a 31.5MB / armeabi-v7a 29.4MB / x86_64 33.0MB（当前为 debug 签名，正式签名见上文）。
- [x] Windows / macOS / iOS：已由 CI 预发布 tag `v1.0.0-pre+1`（run 36982243576）验证通过（全部 6 个 job 绿）。据此已从 `release.yml` 移除 macOS/iOS 的 `continue-on-error`，Apple 构建失败将不再被静默吞掉。

> 体积复核（2026-10-02）：首次打包得到 ~35MB deb / ~132MB AppImage，根因是 `build/` 残留了 14:58 的 101 MiB `kernel_blob.bin`（debug/JIT 产物），`flutter build --release` 未清除，被 `stage_tree` 一并打包。删除残留后重打包为 **~11.5MB deb / ~105MB AppImage**，与 0.5.0 一致。已在 `packaging/linux/common.sh` 的 `ensure_bundle()` 加守卫：release bundle 内存在 `kernel_blob.bin` 即拒绝打包。

## 发布结果（2026-10-02）

- 正式 tag `v1.0.0`；Release：https://github.com/Q-wind520/flind-player/releases/tag/v1.0.0（非预发布）。
- 全部 6 个 job 绿（analyze+test、Linux、Windows、macOS、iOS、Android），`analyze-and-test` 门禁在构建前生效。
- 11 个资产齐全：Linux deb / rpm / AppImage / tar.gz、Windows setup / zip、macOS zip、iOS ipa、Android APK×2 + AAB。
- 预发布 tag `v1.0.0-pre+1` 仅用于验证 CI 矩阵。
