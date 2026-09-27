# 设计：桌面安装包（Linux deb/rpm/AppImage + Windows setup.exe）

- 日期：2026-09-27
- 状态：待实现
- 范围：桌面端原生安装包的构建脚本、CI 集成、发布产物与文档
- 目标读者：实现者
- 关联：[`.github/workflows/release.yml`](../../../.github/workflows/release.yml)、[`.github/workflows/ci.yml`](../../../.github/workflows/ci.yml)、[`linux/CMakeLists.txt`](../../../linux/CMakeLists.txt)、[`windows/CMakeLists.txt`](../../../windows/CMakeLists.txt)、[`README.md`](../../../README.md)

## 1. 背景与目标

现有发布只提供免安装归档：Linux `FlindPlayer-<tag>-linux-x64.tar.gz`、Windows `FlindPlayer-<tag>-windows-x64.zip`。用户需自行解压、赋执行权限、手建快捷方式，且 Linux 端还需自行确认 `libmpv`。

本次为桌面端补齐原生安装包：

- Linux：`.deb`（Debian/Ubuntu）、`.rpm`（Fedora/RHEL）、`.AppImage`（免安装、自包含播放库）。
- Windows：Inno Setup 的 `.setup.exe`。

### 目标
- 三类 Linux 包与 Windows `.setup.exe` 由脚本产出，并接入现有发布流程。
- `release.yml` 在 tag 推送时自动构建并上传；`ci.yml` 在 `v*-pre*` 标签上先行验证。
- 保留现有 `tar.gz` / `zip`（免安装路线不消失）。
- README / 文档给出各产物的下载与安装指引。

### 非目标
- 不做代码签名 / 公证 / 上架（与当前"预览版不签名"策略一致）。
- 不修改 Flutter 构建配置与应用代码。
- 不发布到任何发行版仓库、AUR、Flathub、Snap Store 或 Microsoft Store。
- 不改动 macOS / iOS / Android 的打包。
- 不做鸿蒙打包（见 §11 附录结论）。

## 2. 已确认的决策

以下为设计问答中已拍定的选择，实现不得偏离：

1. **libmpv 策略**：`.deb` / `.rpm` 声明**依赖系统 libmpv**（体积小、随系统更新）；`.AppImage` **自包含**，把 libmpv 及其 FFmpeg 依赖闭包打进去。
2. **Windows 形态**：Inno Setup，`PrivilegesRequiredOverridesAllowed=dialog` —— **安装时让用户选「仅我 / 所有人」**。
3. **Linux 实现方式**：手写脚本 + 发行版原生工具（`dpkg-deb` / `rpmbuild` / `linuxdeploy` + `appimagetool`）；**不引入** `flutter_distributor` 或任何第三方 Action。
4. **产物集**：**保留** `tar.gz` / `zip`，在其之上**新增**四类安装包。
5. **AppImage 不捆绑 GTK**：依赖系统 GTK3（桌面机普遍具备），仅 libmpv 自包含，避免打包 GTK 破坏主题与字体。
6. **Linux 安装目录**：deb/rpm 统一装到 `/opt/flind-player`。
7. **Windows 运行时**：**内置（app-local）VC++ 运行时 DLL**，放在 exe 同级；**不使用** `vc_redist` 安装器。

## 3. 目标架构

### 3.1 目录结构

只新增打包层，不触碰应用与 Flutter 构建：

```
packaging/
  linux/
    build-deb.sh            # dpkg-deb
    build-rpm.sh            # rpmbuild
    build-appimage.sh       # linuxdeploy + appimagetool
    debian/control.in       # control 模板（版本/依赖占位）
    rpm/flind-player.spec.in
    appimage/AppRun
  windows/
    flind-player.iss        # Inno Setup 脚本
```

### 3.2 产物命名

沿用现有约定 `FlindPlayer-${GITHUB_REF_NAME}-<platform>-<arch>.<ext>`（标签含前导 `v`）：

| 文件 | 说明 |
| --- | --- |
| `FlindPlayer-v0.5.0-linux-x64.deb` | Debian / Ubuntu |
| `FlindPlayer-v0.5.0-linux-x64.rpm` | Fedora / RHEL |
| `FlindPlayer-v0.5.0-linux-x64.AppImage` | 免安装，自包含 libmpv |
| `FlindPlayer-v0.5.0-windows-x64-setup.exe` | Windows 安装器 |
| `FlindPlayer-v0.5.0-linux-x64.tar.gz` | （保留）免安装 |
| `FlindPlayer-v0.5.0-windows-x64.zip` | （保留）免安装 |

**包内版本号** = 去掉前导 `v` 的标签（`0.5.0`），`dpkg` / `rpm` / Inno / AppImage 均以此为准。

### 3.3 输入产物

- Linux：`build/linux/x64/release/bundle/`。已含 `flind_player`、`lib/`、`data/`，以及 CMake 已安装的 `share/applications/flind_player.desktop` 与 `share/icons/hicolor/256x256/apps/flind_player.png`（见 `linux/CMakeLists.txt` §Desktop integration）。
- Windows：`build/windows/x64/runner/Release/`。已含 `flind_player.exe`、插件 DLL、`libmpv-2.dll`（`media_kit_libs_windows_audio` 自带）与 `data/`。

### 3.4 参数约定

- 脚本统一接受 `--version <x.y.z>`；未给时回落读取 `pubspec.yaml` 的 `version`（取 `+` 之前部分）。CI 显式传 `${GITHUB_REF_NAME#v}`。
- 脚本可在本地直接运行（便于复现），无需 CI 环境变量。

## 4. Linux 三类包

### 4.1 通用安装布局

- `/opt/flind-player/`：整棵 bundle（`flind_player` + `lib/` + `data/`）。bundle 里的 `share/` **不**原样安装，其内容分别落到标准位置。
- `/usr/bin/flind_player` → 软链到 `/opt/flind-player/flind_player`。
- `/usr/share/applications/flind_player.desktop`、`/usr/share/icons/hicolor/256x256/apps/flind_player.png`：取自 bundle 的 `share/`。

依据：Linux 版用默认 `FlDartProject`（`linux/runner/my_application.cc` 未做自定义路径逻辑），GTK 嵌入层经 `/proc/self/exe` 解析**真实**可执行路径来定位 `data/`，因此 `/usr/bin` 软链安全；`.desktop` 的 `Exec=flind_player` 依赖 `/usr/bin` 在 `PATH`，故软链必需。

### 4.2 .deb

- 构建：`dpkg-deb --build --root-owner-group <pkgroot> <out.deb>`。
- `control` 关键字段：
  - `Package: flind-player`
  - `Version: 0.5.0`
  - `Architecture: amd64`
  - `Section: sound`、`Priority: optional`
  - `Depends: libmpv2, libgtk-3-0, libsecret-1-0, libayatana-appindicator3-1`
  - `Installed-Size`、`Homepage: https://github.com/Q-wind520/flind-player`、`Description`
- `usr/share/doc/flind-player/copyright`：声明本应用 GPL-3.0；说明 libmpv/FFmpeg 为 LGPL-2.1+ 且**未随包分发**（由系统提供）。
- `postinst` / `postrm`：容错刷新桌面数据库与图标缓存（`command -v … && … || true`）。
- 最低系统假设（写进 `Description` 与 README）：提供 `libmpv.so.2` 的发行版，即 Ubuntu 24.04+ / Debian 12+ / Fedora 39+ 一类。
- 卸载**不删用户数据**（`~/.local/share/…` 等），文档说明。

### 4.3 .rpm

- 构建：`rpmbuild -bb --define "_topdir $PWD/rpmbuild" --define "version 0.5.0" --define "bundle_dir <bundle>" packaging/linux/rpm/flind-player.spec`。
- spec 关键：
  - `Name: flind-player`、`Version: %{version}`、`Release: 1%{?dist}`、`BuildArch: x86_64`
  - `License: GPL-3.0-only`、`URL`、`Summary`、`%description`
  - `Requires: mpv-libs` —— libmpv 由 media_kit **运行时 dlopen**，不在 ELF `NEEDED` 中，自动依赖生成器抓不到，必须手工声明。
  - 其余链接库（`libgtk-3.so.0`、`libsecret-1.so.0`、`libayatana-appindicator3.so.1`、`libc` 等）**交给 rpmbuild 自动依赖生成**。
  - `%install` 从 `%{bundle_dir}` `cp -a` 到 `%{buildroot}` 的 `/opt/flind-player`，并创建 `/usr/bin/flind_player` 软链、安装桌面文件与图标。
  - `%files` 列出上述路径（`/opt/flind-player`、`/usr/bin/flind_player`、桌面文件、图标、`%license`）。
  - `%post` / `%postun`：同 deb 的容错刷新。
- 环境：Ubuntu runner 需 `apt-get install -y rpm` 提供 `rpmbuild`。

### 4.4 .AppImage

AppDir 结构：

```
FlindPlayer.AppDir/
  AppRun
  flind_player.desktop            # 复制自 usr/share/applications
  flind_player.png                # 复制自 usr/share/icons/...（AppDir 根图标）
  usr/lib/flind-player/           # 整棵 bundle：flind_player + lib/ + data/
  usr/bin/flind_player            # -> ../lib/flind-player/flind_player
  usr/share/applications/flind_player.desktop
  usr/share/icons/hicolor/256x256/apps/flind_player.png
  usr/share/doc/flind-player/     # LICENSE + copyright（GPL-3.0 与 LGPL-2.1+ 说明）
  usr/lib/…                       # linuxdeploy 拷入的 libmpv.so.2 + FFmpeg 依赖闭包
```

- `AppRun`（`/bin/sh`）：

  ```sh
  #!/bin/sh
  if [ -z "$APPDIR" ]; then
    APPDIR="$(dirname "$(readlink -f "$0")")"
  fi
  export LD_LIBRARY_PATH="$APPDIR/usr/lib/flind-player/lib:$APPDIR/usr/lib:${LD_LIBRARY_PATH:-}"
  exec "$APPDIR/usr/lib/flind-player/flind_player" "$@"
  ```

  AppImage runtime 运行时会设置 `APPDIR`；直接运行 AppDir 时用 `readlink` 兜底。
- 构建：
  - `ARCH=x86_64 linuxdeploy --appdir <dir> --executable usr/lib/flind-player/flind_player --desktop-file usr/share/applications/flind_player.desktop --icon-file usr/share/icons/hicolor/256x256/apps/flind_player.png --library /usr/lib/x86_64-linux-gnu/libmpv.so.2 --output appimage`
  - `ARCH=x86_64 VERSION=0.5.0 appimagetool -o <out> <dir>`
- 工具获取：从官方 release **固定具体版本**下载 `linuxdeploy-x86_64.AppImage` 与 `appimagetool-x86_64.AppImage` 并校验 sha256（不用会漂移的 `continuous` 标签）。CI 容器无 FUSE，统一以 `--appimage-extract-and-run` 调用。
- **不捆绑 GTK**；仅捆 libmpv 与 FFmpeg 闭包。体积预期 +100~200 MB。
- 运行前提：需 FUSE（部分发行版需 `libfuse2`）；README 给 `APPIMAGE_EXTRACT_AND_RUN=1 ./….AppImage` 兜底。

## 5. Windows

### 5.1 运行时 DLL（app-local）

- 事实：`windows/runner/CMakeLists.txt` 走 `apply_standard_settings` 且未设静态运行时 → **动态链接 MSVC 运行时**（`/MD`）；Flutter 构建产物**不含** CRT DLL。缺失时典型症状是"装完打不开"。
- 处理：在 `flutter build windows --release` **之后**、打包之前，把 CRT DLL 复制进 `Release\`：
  - 用 `vswhere.exe` 定位 VS 安装路径；
  - 取 `VC\Redist\MSVC\*\x64\Microsoft.VC*.CRT\*.dll`（含 `msvcp140.dll`、`vcruntime140.dll`、`vcruntime140_1.dll` 等）；
  - 复制到 `build\windows\x64\runner\Release\`。
- 放在打包前 → **`zip` 与 `setup.exe` 同时自包含**（顺带修复现有 zip 在缺 CRT 机器上的隐患）。
- 许可：这些 DLL 属 Visual Studio 可再发行组件，Microsoft 允许 app-local 随程序分发。

### 5.2 Inno Setup 脚本（`packaging/windows/flind-player.iss`）

- 版本相关值经 `/D` 传入：`Version`、`Tag`、`SourceDir`。
- 关键指令：
  - 应用：`AppId={{<GUID>}}`（实现时用 `uuidgen` 生成一次并写死；此后**永不更改**，否则升级与卸载识别会失效）、`AppName=Flind Player`、`AppVersion={#Version}`、`AppPublisher`、`AppPublisherURL`、`AppSupportURL`、`UninstallDisplayIcon={app}\flind_player.exe`、`SetupIconFile=docs\FlindPlayer.ico`、`LicenseFile=LICENSE`。
  - 安装范围：`DefaultDirName={autopf}\Flind Player`、`PrivilegesRequired=lowest`、`PrivilegesRequiredOverridesAllowed=dialog`、`DisableProgramGroupPage=yes`。
  - 架构：`ArchitecturesAllowed=x64compatible`、`ArchitecturesInstallIn64BitMode=x64compatible`。
  - 输出：`OutputBaseFilename=FlindPlayer-{#Tag}-windows-x64-setup`、`Compression=lzma2/max`、`SolidCompression=yes`、`WizardStyle=modern`。
  - `[Files]`：`Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion`。
  - `[Tasks]`：`desktopicon`（**默认不勾**）。
  - `[Icons]`：`{autoprograms}\Flind Player`（含卸载项）+ `{autodesktop}\Flind Player`（绑定 `desktopicon` task）。
  - `[Run]`：`postinstall nowait skipifsilent` 启动应用。
  - `[UninstallDelete]`：仅清程序目录；**不删用户数据**。
- 未签名：SmartScreen 会拦截提示；README 说明。
- CI 安装 Inno：从官方 release 资产固定版本下载（`https://github.com/jrsoftware/issrc/releases/download/is-7_1_0/innosetup-7.1.0-x64.exe`，sha256 `0362a383ed217d4c4239b5933866dd96d3eb2102737da92f80f6057a4b40df2f`），校验后静默安装；调用动态定位到的 `ISCC.exe`。本地脚本直接调用 `iscc`（若在 PATH）。

### 5.3 Windows 打包顺序

`flutter build windows --release` → 复制 CRT DLL → `Compress-Archive`（zip）→ `ISCC`（setup.exe）。

## 6. CI 集成

### 6.1 `release.yml`

- `build-linux`：
  - 追加 apt：`rpm`（`rpmbuild`）、`squashfs-tools`（appimagetool 依赖 `mksquashfs`）。
  - 在 `flutter build linux --release` 后依次运行 `build-deb.sh`、`build-rpm.sh`、`build-appimage.sh`。
  - `linux-release` 上传新增 `*.deb`、`*.rpm`、`*.AppImage`（与 `*.tar.gz` 并列）。
- `build-windows`：
  - 追加：choco 安装固定版本 Inno Setup。
  - 在 `flutter build windows --release` 后复制 CRT DLL → 打 zip → 运行 `ISCC`。
  - `windows-release` 上传 `zip` 与 `*-setup.exe`。
- `release`：
  - `files:` 增加四个新产物。
  - 正文资源表补四行，并给出安装命令：`sudo apt install ./FlindPlayer-….deb`、`sudo dnf install ./FlindPlayer-….rpm`、`chmod +x FlindPlayer-….AppImage && ./FlindPlayer-….AppImage`、双击 `FlindPlayer-…-setup.exe`。
  - 继续保留 GPL-3.0 §6 的对应源码指向段落。

### 6.2 `ci.yml`

- 在 `build-linux` / `build-windows` 中执行与 release **相同**的打包步骤（不上传），使 `v*-pre*` 预发布标签即可暴露问题。
- 说明：本仓库 CI 仅在 `v*-pre*` 标签触发，这是发布前唯一的自动化验证入口。

## 7. 文档更新

- `README.md`：
  - 「支持平台」表补充 Linux 安装包 / Windows 安装器。
  - 「构建与发布 → 本地构建」补充四类安装包的本地命令。
  - 新增「下载与安装」小节（含 AppImage 的 FUSE 兜底、deb/rpm 的最低发行版）。
- `docs/packaging.md`（新增）：目录结构、依赖、工具版本固定、本地复现步骤、已知边界（AppImage FUSE、libmpv 最低发行版、CRT app-local 许可）。
- 发布正文：见 §6.1。

## 8. 测试与验证

打包属构建产物，没有 Flutter 单测面，**不触碰 `flutter test` / `dart analyze`**。验证方式：

1. **本地**：
   - `dpkg-deb -I <deb>` / `dpkg-deb -c <deb>` 检查控制信息与文件表。
   - `rpm -qpl <rpm>` 或 `rpm2cpio <rpm> | cpio -t` 检查文件表（需本机装 `rpm`）。
   - `<appimage> --appimage-extract` 后检查 `AppDir` 是否含 `libmpv.so.2` 及 FFmpeg 闭包，并 `ldd` 校验；确认 `AppRun` 可执行。
   - `iscc` 本地编译一次 `.iss` 验证语法。
2. **CI**：打 `v0.5.1-pre+1` 预发布标签，确认四个产物生成且既有产物不受影响。
3. **冒烟**：在 Debian/Ubuntu、Fedora 容器内 `apt/dnf install ./…`，在 Windows 上双击 `setup.exe`，验证安装、启动、卸载（并确认用户数据保留）。
4. **回归**：确认 `tar.gz` / `zip` 仍正常生成、内容变化仅限新增 CRT DLL。

## 9. 不变量

- 不修改应用代码与 Flutter 构建配置。
- 安装与卸载**不删除用户数据**。
- 除下述边界外，产物自包含：AppImage 依赖系统 GTK3；deb/rpm 依赖系统 libmpv。
- 包内版本号与发布标签一致（去前导 `v`）。
- 发布正文继续包含 GPL-3.0 §6 的对应源码指向。

## 10. 风险与已知边界

1. **AppImage 与 dlopen 的 libmpv**：`libmpv.so.2` 由 media_kit 运行时 `dlopen`，不在 ELF `NEEDED`，必须用 `--library` 显式加入，其 FFmpeg 依赖闭包由 linuxdeploy 解析。若冒烟失败，回退：手工 `cp` 依赖闭包并在 `AppRun` 里补 `LD_LIBRARY_PATH`。
2. **AppImage 体积**：+100~200 MB。
3. **FUSE 依赖**：较新发行版默认无 `libfuse2`；文档给 `APPIMAGE_EXTRACT_AND_RUN=1` 兜底。
4. **deb/rpm 最低发行版**：需提供 `libmpv.so.2`（Ubuntu 24.04+ / Debian 12+ / Fedora 39+ 一类）；更老的发行版不保证。
5. **在 Ubuntu 上做 rpm**：`rpmbuild` 与 Fedora 环境存在细微差异；需确认自动生成的 `Requires` 正确、`%files` 无遗漏。
6. **AppImage 工具链版本漂移**：`linuxdeploy` / `appimagetool` 必须固定到具体版本并校验 sha256。
7. **未签名**：Windows SmartScreen 会提示；属既有预览策略，不在本次解决。
8. **许可合规**：AppImage 捆绑 LGPL-2.1+ 的 libmpv/FFmpeg → 随包附许可文本并说明可替换；Windows 内置微软可再发行 DLL。

## 11. 附录：鸿蒙可行性探针结论（非本次范围）

2026-09-27 的廉价核查结论（不实现，仅备查）：

- 官方 Flutter 无 `ohos` 平台；社区分支 `openharmony-sig/flutter_flutter`（gitcode）已到发布线 `3.41.10-ohos-1.0.1`（framework Dart 地板 `^3.9.0-0`）与 canary `3.44.9`（`^3.10.0-0`）；用地板规律（本机 3.47.5 → Dart 3.13.4，地板 `^3.11.0-0`）推算，对应 Dart ≈ 3.11 / 3.12。
- 本项目 `environment: sdk: ^3.13.3` → **当前无任何鸿蒙分支可满足**，`pub get` 会直接失败。
- 依赖侧：`just_audio`、`audio_session`、`audio_service`、`media_kit`、`sqlite3`、`path_provider`、`shared_preferences`、`permission_handler`、`file_picker`、`package_info_plus` 均有社区鸿蒙端口（gitcode/atomgit），但需改造为 git 依赖 / `dependency_overrides`；桌面专属的 `tray_manager` / `window_manager` 在本项目已由 `Platform.is*` 隔离。
- 构建环境另需 OpenHarmony SDK(API 12+)+`ohpm`+`hvigor`+node+**JDK 17**（本机为 JDK 25）。
- 结论：构建鸿蒙 Flutter 应用本身可行；**本项目当前不可行**，待社区分支追上 Flutter 3.47 / Dart 3.13 再评估。
