# 桌面安装包打包说明

## 产物

| 文件 | 平台 | 说明 |
| --- | --- | --- |
| `FlindPlayer-<tag>-linux-x64.deb` | Debian/Ubuntu | 依赖系统 `libmpv2` |
| `FlindPlayer-<tag>-linux-x64.rpm` | Fedora/RHEL | 依赖系统 `mpv-libs` |
| `FlindPlayer-<tag>-linux-x64.AppImage` | 任意发行版 | 自包含 libmpv/FFmpeg；需系统 GTK3 |
| `FlindPlayer-<tag>-windows-x64-setup.exe` | Windows 10/11 x64 | 未签名；已内置 VC++ 运行时 |

免安装的 `linux-x64.tar.gz` / `windows-x64.zip` 仍然保留。

## 本地构建

```bash
flutter build linux --release
packaging/linux/build-deb.sh --version 0.5.0
packaging/linux/build-rpm.sh --version 0.5.0      # 需 rpmbuild
packaging/linux/build-appimage.sh --version 0.5.0
# 产物在 dist/
```

Windows（在 Windows 上）：

```powershell
flutter build windows --release
./packaging/windows/stage-crt.ps1 -ReleaseDir build/windows/x64/runner/Release
ISCC.exe /DVersion=0.5.0 /DTag=v0.5.0 /DSourceDir=build\windows\x64\runner\Release packaging\windows\flind-player.iss
```

## 设计要点

- 安装目录 `/opt/flind-player`，`/usr/bin/flind_player` 为指向它的绝对软链；`.desktop` 与 256×256 图标取自 bundle 内 CMake 已装好的副本。
- 三个 Linux 脚本共享 `packaging/linux/common.sh`；版本号统一由 `--version` 传入（CI 用 `${GITHUB_REF_NAME#v}`），缺省时回落 `pubspec.yaml`。
- AppImage 依赖的 `libmpv.so.2` 由 media_kit 运行时 `dlopen`，不在 ELF `NEEDED` 中，必须用 `linuxdeploy --library` 显式纳入。
- linuxdeploy 固定 `1-alpha-20251107-1`、appimagetool 固定 `1.9.1`，下载后校验 sha256；哈希不符即失败（避免上游漂移）。
- rpm 的 `%files` 由 `build-rpm.sh` 在打包前自检（列出的必须存在，暂存的文件必须被覆盖）。
- Windows 用 app-local 复制 MSVC 运行时 DLL（`vswhere` 定位 VS 的 `VC\Redist\MSVC\*\x64\Microsoft.VC*.CRT`），因此 zip 与安装器都不再依赖系统 VC++ Redistributable。

## 已知边界

- **最低发行版**：deb/rpm 需要提供 `libmpv.so.2`（Ubuntu 24.04+ / Debian 12+ / Fedora 39+ 一类）。
- **AppImage + FUSE**：部分发行版默认无 `libfuse2`，可 `APPIMAGE_EXTRACT_AND_RUN=1 ./FlindPlayer-….AppImage` 兜底。
- **未签名**：Windows SmartScreen 会提示；这是既有预览策略。
- **许可**：应用为 GPL-3.0；AppImage 捆绑 LGPL-2.1+ 的 libmpv/FFmpeg，包内附许可说明；Windows 包内含微软可再发行 DLL。
- 安装/卸载**不删除用户数据**（`~/.local/share`、`%APPDATA%` 等）。

## 鸿蒙

见 `docs/archive/spec-desktop-installers-2026-09-27.md` §11 的探针结论：本项目当前无法构建鸿蒙版（社区分支的 Dart 版本尚未达到本项目要求）。
