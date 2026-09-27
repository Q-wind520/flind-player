# 桌面安装包（Linux deb/rpm/AppImage + Windows setup.exe）实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 Flind Player 的桌面端新增 `.deb`、`.rpm`、`.AppImage` 与 Windows `.setup.exe` 四类安装包，并接入现有发布流程。

**Architecture:** 新增 `packaging/` 目录存放脚本与模板，全部复用 `flutter build` 已有的 bundle/`Release` 产物；Linux 用发行版原生工具（`dpkg-deb` / `rpmbuild` / `linuxdeploy`+`appimagetool`），Windows 用 Inno Setup。CI 侧在 `release.yml` 产出并上传，`ci.yml` 在 `v*-pre*` 标签上先验证。

**Tech Stack:** Bash 脚本、`dpkg-deb`、`rpmbuild`、linuxdeploy `1-alpha-20251107-1`、appimagetool `1.9.1`、Inno Setup `7.1.0`、PowerShell、GitHub Actions。

**Spec:** `docs/superpowers/specs/2026-09-27-desktop-installers-design.md`

## Global Constraints

- 安装目录 `/opt/flind-player`；二进制 `flind_player`；包名 `flind-player`；应用名 `Flind Player`。
- 产物命名 `FlindPlayer-v<version>-<platform>-<arch>.<ext>`，`<version>` 为标签去掉前导 `v`（如 `0.5.0`、预发布则为 `0.5.1-pre+1`）。
- 全部产物输出到仓库根的 `dist/`（该目录不提交）。
- `libmpv` 策略：`.deb`/`.rpm` **依赖系统** libmpv；`.AppImage` **自包含** libmpv + FFmpeg 闭包；三者都不捆绑 GTK。
- Windows **不签名**；**不使用** `vc_redist` 安装器，改为 app-local 复制 CRT DLL。
- 保留现有 `tar.gz` / `zip`。
- 打包脚本**不得**修改应用代码或 Flutter 构建配置；安装/卸载**不得**删除用户数据。
- 工具版本固定：linuxdeploy `1-alpha-20251107-1`（sha256 `c20cd71e3a4e3b80c3483cef793cda3f4e990aca14014d23c544ca3ce1270b4d`）、appimagetool `1.9.1`（sha256 `ed4ce84f0d9caff66f50bcca6ff6f35aae54ce8135408b3fa33abfc3cb384eb0`）、Inno Setup `7.1.0`。
- 所有 shell 脚本：`#!/usr/bin/env bash` + `set -euo pipefail`（Debian maintainer 脚本用 `#!/bin/sh` + `set -e`）。
- 仓库 lint 面：`flutter analyze` / `flutter test` 必须保持全绿（本计划不触碰 Dart 代码，但每次提交前仍要确认）。

## Review Focus

以下是最可能咬到真实用户、但没有任何单测覆盖的输入/失败模式；每条都在对应任务里有具体校验步骤：

1. **系统只有 `libmpv1`（无 `libmpv.so.2`）**：deb/rpm 能装上但播放静默失败。期望：`Depends`/`Requires` 明确；文档给出最低发行版。← Task 1、Task 7。
2. **AppImage 里 libmpv 没被真正打进去**（media_kit 是运行时 `dlopen`，不在 ELF `NEEDED`）：期望 `.AppImage` 解包后 `usr/lib` 有 `libmpv.so.2` 且 `ldd` 无 `not found`。← Task 3。
3. **预发布标签（含 `-` 与 `+`）导致 dpkg/rpm 版本号非法**：期望脚本不崩、版本号被正确拆分。← Task 1、Task 2。
4. **appimagetool/linuxdeploy 上游漂移**：期望下载用 sha256 fail-closed，改版本必须显式改哈希。← Task 3。
5. **Windows 缺 MSVC 运行时 DLL**：期望 `Release\` 内确实出现 `vcruntime140*.dll` 等，`setup.exe` 装完能直接启动。← Task 4、Task 8。

---

### Task 1: Linux 共享层 + `.deb`

**Files:**
- Create: `packaging/linux/common.sh`
- Create: `packaging/linux/debian/control.in`
- Create: `packaging/linux/debian/postinst`
- Create: `packaging/linux/debian/postrm`
- Create: `packaging/linux/build-deb.sh`
- Modify: `.gitignore`（追加 `/dist/`）

**Interfaces:**
- Produces（供 Task 2/3 复用，均在 `common.sh` 中）：
  - 变量 `PACKAGING_DIR`、`REPO_ROOT`、`PKG_NAME=flind-player`、`BIN_NAME=flind_player`、`INSTALL_DIR=/opt/flind-player`、`APP_LABEL=Flind Player`、`HOMEPAGE`、`BUNDLE_DIR`、`OUT_DIR`、`VERSION`
  - `parse_args "$@"`：只认 `--version <x.y.z>`、`--help`
  - `resolve_version`：未给 `--version` 时从 `pubspec.yaml` 取（`0.5.0+9` → `0.5.0`）；非法字符直接 `die`
  - `ensure_bundle`：校验 `BUNDLE_DIR` 下二进制 / `.desktop` / 图标存在
  - `stage_tree <root>`：把 bundle 铺成 FHS 树到 `<root>`（`<root>` 在安装时映射为 `/`）
  - `write_copyright <root> <yes|no>`：写 `usr/share/doc/flind-player/copyright`
  - `normalize_tree <root>`：统一包内权限（目录 0755、文件去掉组写位、保留可执行位）
  - `rpm_version` / `rpm_release`：把 `VERSION` 拆成 rpm 合法的 Version/Release（Task 2 用）
  - `die <msg>`
- Produces: `dist/FlindPlayer-v<version>-linux-x64.deb`

- [ ] **Step 1: 写 `common.sh`**

创建 `packaging/linux/common.sh`：

```bash
#!/usr/bin/env bash
# Shared helpers for the Linux installer scripts.
#
# Sourced (not executed) by build-deb.sh / build-rpm.sh / build-appimage.sh.
set -euo pipefail

PACKAGING_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${PACKAGING_DIR}/../.." && pwd)"

PKG_NAME="flind-player"
BIN_NAME="flind_player"
INSTALL_DIR="/opt/${PKG_NAME}"
APP_LABEL="Flind Player"
HOMEPAGE="https://github.com/Q-wind520/flind-player"

BUNDLE_DIR="${BUNDLE_DIR:-${REPO_ROOT}/build/linux/x64/release/bundle}"
OUT_DIR="${OUT_DIR:-${REPO_ROOT}/dist}"
VERSION=""

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --version)
        [ $# -ge 2 ] || die "--version needs a value"
        VERSION="$2"
        shift 2
        ;;
      --help | -h)
        printf 'usage: %s [--version x.y.z]\n' "$(basename "$0")"
        exit 0
        ;;
      *)
        die "unknown argument: $1"
        ;;
    esac
  done
}

resolve_version() {
  if [ -z "${VERSION}" ]; then
    VERSION="$(sed -n 's/^version:[[:space:]]*\([^+]*\).*/\1/p' "${REPO_ROOT}/pubspec.yaml" | head -1)"
  fi
  [ -n "${VERSION}" ] || die "cannot determine version (pass --version)"
  case "${VERSION}" in
    *[!A-Za-z0-9.+-]*) die "version has characters dpkg/rpm reject: ${VERSION}" ;;
  esac
  case "${VERSION}" in
    '' | .* | *.) die "malformed version: ${VERSION}" ;;
  esac
}

ensure_bundle() {
  [ -x "${BUNDLE_DIR}/${BIN_NAME}" ] ||
    die "bundle binary not found: ${BUNDLE_DIR}/${BIN_NAME} (run: flutter build linux --release)"
  [ -f "${BUNDLE_DIR}/share/applications/${BIN_NAME}.desktop" ] ||
    die "desktop file not found under ${BUNDLE_DIR}/share/applications"
  [ -f "${BUNDLE_DIR}/share/icons/hicolor/256x256/apps/${BIN_NAME}.png" ] ||
    die "icon not found under ${BUNDLE_DIR}/share/icons"
}

# rpm forbids '-' in Version/Release; split "0.5.1-pre+1" into 0.5.1 / 0.pre+1
rpm_version() {
  printf '%s' "${VERSION%%-*}"
}

rpm_release() {
  case "${VERSION}" in
    *-*) printf '%s' "0.${VERSION#*-}" | tr '-' '.' ;;
    *) printf '1' ;;
  esac
}

# manifest_check <spec> <root>
# Fails when the spec's %files lists a path that is missing under <root>, or
# when a staged file is not covered by any %files entry. Catches the two classic
# hand-written-spec mistakes without needing rpmbuild.
manifest_check() {
  local spec="$1" root="$2" p f covered rc=0
  local -a entries=()
  while IFS= read -r p; do
    if [ -n "${p}" ]; then entries+=("${p}"); fi
  done < <(awk '/^%files/{f=1;next} f&&/^%/{f=0} f&&NF{print $NF}' "${spec}" | grep '^/' || true)
  if [ "${#entries[@]}" -eq 0 ]; then
    printf 'error: no %%files entries parsed from %s\n' "${spec}" >&2
    return 1
  fi

  for p in "${entries[@]}"; do
    # -e follows symlinks, and an absolute symlink such as /usr/bin/flind_player
    # does not resolve inside the staging root; accept -L as well.
    if [ ! -e "${root}${p}" ] && [ ! -L "${root}${p}" ]; then
      printf 'error: %%files lists %s but it is missing under %s\n' "${p}" "${root}" >&2
      rc=1
    fi
  done
  while IFS= read -r f; do
    covered=0
    for p in "${entries[@]}"; do
      case "${f}" in
        "${root}${p}" | "${root}${p}"/*)
          covered=1
          break
          ;;
      esac
    done
    if [ "${covered}" -eq 0 ]; then
      printf 'error: staged file not covered by %%files: %s\n' "${f#"${root}"}" >&2
      rc=1
    fi
  done < <(find "${root}" \( -type f -o -type l \) | sort)
  return "${rc}"
}

# stage_tree <root>: lay out the FHS tree under <root> (which maps to / when installed).
stage_tree() {
  local root="$1"
  install -d "${root}${INSTALL_DIR}"
  cp -a "${BUNDLE_DIR}/${BIN_NAME}" "${root}${INSTALL_DIR}/"
  cp -a "${BUNDLE_DIR}/lib" "${root}${INSTALL_DIR}/"
  cp -a "${BUNDLE_DIR}/data" "${root}${INSTALL_DIR}/"

  install -d "${root}/usr/bin"
  ln -sf "${INSTALL_DIR}/${BIN_NAME}" "${root}/usr/bin/${BIN_NAME}"

  install -d "${root}/usr/share/applications"
  install -d "${root}/usr/share/icons/hicolor/256x256/apps"
  install -d "${root}/usr/share/doc/${PKG_NAME}"
  install -m0644 "${BUNDLE_DIR}/share/applications/${BIN_NAME}.desktop" \
    "${root}/usr/share/applications/${BIN_NAME}.desktop"
  install -m0644 "${BUNDLE_DIR}/share/icons/hicolor/256x256/apps/${BIN_NAME}.png" \
    "${root}/usr/share/icons/hicolor/256x256/apps/${BIN_NAME}.png"
}

# write_copyright <root> <yes|no>  (yes = libmpv/FFmpeg are bundled in this package)
write_copyright() {
  local root="$1" bundles="$2" note
  if [ "${bundles}" = "yes" ]; then
    note="libmpv / FFmpeg 随本包分发（动态链接）。"
  else
    note="libmpv / FFmpeg 由系统提供，未随本包分发。"
  fi
  cat >"${root}/usr/share/doc/${PKG_NAME}/copyright" <<EOF
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: ${APP_LABEL}
Source: ${HOMEPAGE}

Files: *
Copyright: 2026 top.qwind.app
License: GPL-3.0
 本程序为自由软件，依据 GNU GPL-3.0 分发，不附带任何担保。

License: LGPL-2.1+
 播放后端 libmpv / FFmpeg 依据 LGPL-2.1-or-later 分发；${note}
 完整许可文本见 ${HOMEPAGE} 及各组件上游。
EOF
}

# normalize_tree <root>: predictable permissions for a package payload
# (world-readable dirs, non-group-writable files, executables untouched).
normalize_tree() {
  chmod 0755 "$1"
  find "$1" -type d -exec chmod 0755 {} +
  find "$1" -type f -exec chmod go-w {} +
}
```

- [ ] **Step 2: 写 Debian 控制文件与 maintainer 脚本**

创建 `packaging/linux/debian/control.in`：

```
Package: @PKGNAME@
Version: @VERSION@
Section: sound
Priority: optional
Architecture: amd64
Maintainer: Qwind520 <qwqwind42@gmail.com>
Homepage: @HOMEPAGE@
Depends: libmpv2, libgtk-3-0, libsecret-1-0, libayatana-appindicator3-1
Description: Flind Player - cross-platform music player
 A Flutter based music player with local library scanning, Bilibili audio
 sources, playlists, favorites and offline caching.
 .
 Playback requires a system libmpv (package libmpv2), which is not bundled.
```

创建 `packaging/linux/debian/postinst`：

```sh
#!/bin/sh
set -e
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database -q /usr/share/applications || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
fi
exit 0
```

创建 `packaging/linux/debian/postrm`：

```sh
#!/bin/sh
set -e
case "$1" in
remove | purge)
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database -q /usr/share/applications || true
  fi
  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
  fi
  ;;
esac
exit 0
```

- [ ] **Step 3: 写 `build-deb.sh`**

创建 `packaging/linux/build-deb.sh`：

```bash
#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

parse_args "$@"
resolve_version
ensure_bundle

out="${OUT_DIR}/FlindPlayer-v${VERSION}-linux-x64.deb"
mkdir -p "${OUT_DIR}"

pkgroot="$(mktemp -d)"
trap 'rm -rf "${pkgroot}"' EXIT

stage_tree "${pkgroot}"
write_copyright "${pkgroot}" no

install -d "${pkgroot}/DEBIAN"
sed -e "s/@VERSION@/${VERSION}/g" \
  -e "s/@PKGNAME@/${PKG_NAME}/g" \
  -e "s|@HOMEPAGE@|${HOMEPAGE}|g" \
  "${PACKAGING_DIR}/debian/control.in" >"${pkgroot}/DEBIAN/control"
printf 'Installed-Size: %s\n' "$(du -sk "${pkgroot}" | cut -f1)" >>"${pkgroot}/DEBIAN/control"

install -m0755 "${PACKAGING_DIR}/debian/postinst" "${pkgroot}/DEBIAN/postinst"
install -m0755 "${PACKAGING_DIR}/debian/postrm" "${pkgroot}/DEBIAN/postrm"

normalize_tree "${pkgroot}"
dpkg-deb --build --root-owner-group "${pkgroot}" "${out}" >/dev/null
printf 'built %s\n' "${out}"
```

- [ ] **Step 4: 加 `/dist/` 到 `.gitignore`**

在 `.gitignore` 的 `# Flutter/Dart/Pub related` 段之后追加：

```
# Packaged desktop installers (packaging/linux/*, packaging/windows/*)
/dist/
```

- [ ] **Step 5: 语法检查**

Run:
```bash
bash -n packaging/linux/common.sh
bash -n packaging/linux/build-deb.sh
sh -n packaging/linux/debian/postinst
sh -n packaging/linux/debian/postrm
```
Expected: 无输出（全部通过）。

- [ ] **Step 6: 构建 `.deb`**

Run:
```bash
chmod +x packaging/linux/build-deb.sh
packaging/linux/build-deb.sh --version 0.5.0
```
Expected: `built /home/qwind/Projects/Flind Player/dist/FlindPlayer-v0.5.0-linux-x64.deb`

- [ ] **Step 7: 校验控制信息与文件表**

Run:
```bash
dpkg-deb -f dist/FlindPlayer-v0.5.0-linux-x64.deb Depends
dpkg-deb -f dist/FlindPlayer-v0.5.0-linux-x64.deb Version
dpkg-deb -c dist/FlindPlayer-v0.5.0-linux-x64.deb
```
Expected:
- `Depends` 含 `libmpv2`（Review Focus #1）
- `Version` 为 `0.5.0`
- 文件表含 `/opt/flind-player/flind_player`、`/opt/flind-player/lib/…`、`/opt/flind-player/data/…`、`/usr/share/applications/flind_player.desktop`、`/usr/share/icons/hicolor/256x256/apps/flind_player.png`、`/usr/share/doc/flind-player/copyright`，以及 `usr/bin/flind_player -> /opt/flind-player/flind_player`（**绝对**软链）；**不含** `…/share/applications` 在 `/opt` 下的重复副本。

- [ ] **Step 8: 校验软链与桌面集成真的可用**

Run:
```bash
rm -rf /tmp/opencode/debroot && dpkg-deb -x dist/FlindPlayer-v0.5.0-linux-x64.deb /tmp/opencode/debroot
readlink /tmp/opencode/debroot/usr/bin/flind_player
test -f /tmp/opencode/debroot/opt/flind-player/data/flutter_assets/AssetManifest.bin && echo "assets OK"
grep -c '^Exec=flind_player$' /tmp/opencode/debroot/usr/share/applications/flind_player.desktop
```
Expected: `readlink` 输出 `/opt/flind-player/flind_player`；`assets OK`；`grep -c` 输出 `1`。

- [ ] **Step 9: 校验版本号边界（Review Focus #3）**

Run:
```bash
packaging/linux/build-deb.sh --version '0.5.0;echo pwned'
```
Expected: 以非零码退出，stderr 含 `version has characters dpkg/rpm reject`（不得创建任何文件）。

Run:
```bash
packaging/linux/build-deb.sh --version 0.5.1-pre+1
dpkg-deb -f dist/FlindPlayer-v0.5.1-pre+1-linux-x64.deb Version
```
Expected: 构建成功，`Version` 输出 `0.5.1-pre+1`。

- [ ] **Step 10: 提交**

```bash
git add packaging/linux/common.sh packaging/linux/debian/control.in \
  packaging/linux/debian/postinst packaging/linux/debian/postrm \
  packaging/linux/build-deb.sh .gitignore
git commit -m "build(packaging): add shared linux helpers and .deb builder"
```

---

### Task 2: `.rpm`

**Files:**
- Create: `packaging/linux/rpm/flind-player.spec.in`
- Create: `packaging/linux/build-rpm.sh`

**Interfaces:**
- Consumes: `common.sh` 的 `parse_args`/`resolve_version`/`ensure_bundle`/`stage_tree`/`write_copyright`/`rpm_version`/`rpm_release`/`PACKAGING_DIR`/`REPO_ROOT`/`PKG_NAME`/`BIN_NAME`/`HOMEPAGE`
- Produces: `dist/FlindPlayer-v<version>-linux-x64.rpm`

- [ ] **Step 1: 写 spec 模板**

创建 `packaging/linux/rpm/flind-player.spec.in`：

```
Name:           flind-player
Version:        @RPMVERSION@
Release:        @RPMRELEASE@%{?dist}
Summary:        Flind Player - cross-platform music player

License:        GPL-3.0-only
URL:            @HOMEPAGE@
BuildArch:      x86_64
AutoReqProv:    yes

# libmpv is dlopen()ed at runtime by media_kit, so rpm's automatic ELF
# dependency generator cannot see it; declare it by hand.
Requires:       mpv-libs

%description
A Flutter based music player with local library scanning, Bilibili audio
sources, playlists, favorites and offline caching.

Playback requires a system libmpv (package mpv-libs), which is not bundled.

%prep
%build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}
cp -a "%{_bundledir}/." %{buildroot}/

%files
/opt/flind-player
/usr/bin/flind_player
/usr/share/applications/flind_player.desktop
/usr/share/icons/hicolor/256x256/apps/flind_player.png
/usr/share/doc/flind-player/copyright
/usr/share/licenses/flind-player/LICENSE

%post
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database -q /usr/share/applications || :
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || :
fi

%postun
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database -q /usr/share/applications || :
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || :
fi
```

- [ ] **Step 2: 写 `build-rpm.sh`（含 `%files` 自检）**

创建 `packaging/linux/build-rpm.sh`：

```bash
#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

parse_args "$@"
resolve_version
ensure_bundle

mkdir -p "${OUT_DIR}"
stage="$(mktemp -d)"
topdir="$(mktemp -d)"
trap 'rm -rf "${stage}" "${topdir}"' EXIT

stage_tree "${stage}"
write_copyright "${stage}" no
install -D -m0644 "${REPO_ROOT}/LICENSE" "${stage}/usr/share/licenses/${PKG_NAME}/LICENSE"
normalize_tree "${stage}"

spec="${topdir}/flind-player.spec"
sed -e "s/@RPMVERSION@/$(rpm_version)/g" \
  -e "s/@RPMRELEASE@/$(rpm_release)/g" \
  -e "s|@HOMEPAGE@|${HOMEPAGE}|g" \
  "${PACKAGING_DIR}/rpm/flind-player.spec.in" >"${spec}"

manifest_check "${spec}" "${stage}"

command -v rpmbuild >/dev/null 2>&1 ||
  die "rpmbuild not found (Debian/Ubuntu: apt-get install rpm)"

rpmbuild -bb --define "_topdir ${topdir}" --define "_bundledir ${stage}" "${spec}" >/dev/null

rpmfile="$(find "${topdir}/RPMS" -name '*.rpm' | head -1)"
[ -n "${rpmfile}" ] || die "rpmbuild produced no rpm"
mv "${rpmfile}" "${OUT_DIR}/FlindPlayer-v${VERSION}-linux-x64.rpm"
printf 'built %s\n' "${OUT_DIR}/FlindPlayer-v${VERSION}-linux-x64.rpm"
```

- [ ] **Step 3: 语法检查**

Run:
```bash
bash -n packaging/linux/build-rpm.sh
```
Expected: 无输出。

- [ ] **Step 4: 自检逻辑的负向测试（不依赖 rpmbuild）**

先铺一棵真实暂存树，再用「`%files` 指向不存在文件」的 spec 触发自检：

```bash
rm -rf /tmp/opencode/mcstage /tmp/opencode/good.spec /tmp/opencode/bad.spec
bash -c '
  source packaging/linux/common.sh
  stage_tree /tmp/opencode/mcstage
  write_copyright /tmp/opencode/mcstage no
  install -D -m0644 LICENSE /tmp/opencode/mcstage/usr/share/licenses/flind-player/LICENSE
  sed -e "s/@RPMVERSION@/0.5.0/;s/@RPMRELEASE@/1/;s|@HOMEPAGE@|x|" \
      packaging/linux/rpm/flind-player.spec.in > /tmp/opencode/good.spec
  sed "s#^/usr/share/licenses/flind-player/LICENSE\$#/usr/share/licenses/flind-player/NOPE#" \
      /tmp/opencode/good.spec > /tmp/opencode/bad.spec
  manifest_check /tmp/opencode/good.spec /tmp/opencode/mcstage && echo "positive check OK"
  if manifest_check /tmp/opencode/bad.spec /tmp/opencode/mcstage; then
    echo "UNEXPECTED PASS"; exit 1
  else
    echo "negative check OK"
  fi
'
```
Expected: 先 `positive check OK`；然后两行 `error:`（`…/NOPE` 缺失 + `staged file not covered by %files: /usr/share/licenses/flind-player/LICENSE`）；最后 `negative check OK`。

- [ ] **Step 5: 尝试本地完整构建**

Run:
```bash
command -v rpmbuild || echo "rpmbuild missing -> 需要 sudo apt-get install -y rpm"
```
若 `rpmbuild` 存在，Run：
```bash
chmod +x packaging/linux/build-rpm.sh
packaging/linux/build-rpm.sh --version 0.5.0
rpm -qpl dist/FlindPlayer-v0.5.0-linux-x64.rpm
rpm -qpR dist/FlindPlayer-v0.5.0-linux-x64.rpm
```
Expected: 生成 rpm；`-qpl` 列出 6 条 `%files` 路径；`-qpR` 含 `mpv-libs` 与自动生成的 `libgtk-3.so.0()(64bit)` 一类（Review Focus #1）。

**若本机无 `rpmbuild` 且无法安装**：跳过本步，改为
```bash
packaging/linux/build-rpm.sh --version 0.5.0 || true   # 预期在 rpmbuild 检查处 die
```
Expected: 报 `rpmbuild not found`，且**尚未**产生任何 rpm。完整构建留到 Task 8 的 CI 验证，并在提交信息里注明。

- [ ] **Step 6: 提交**

```bash
git add packaging/linux/rpm/flind-player.spec.in packaging/linux/build-rpm.sh
git commit -m "build(packaging): add .rpm builder with %files manifest self-check"
```

---

### Task 3: `.AppImage`

**Files:**
- Create: `packaging/linux/appimage/AppRun`
- Create: `packaging/linux/build-appimage.sh`

**Interfaces:**
- Consumes: `common.sh` 同上（`parse_args`/`resolve_version`/`ensure_bundle`/`write_copyright`/`die`/`PACKAGING_DIR`/`REPO_ROOT`/`BUNDLE_DIR`/`OUT_DIR`/`PKG_NAME`/`BIN_NAME`）
- Produces: `dist/FlindPlayer-v<version>-linux-x64.AppImage`

- [ ] **Step 1: 写 `AppRun`**

创建 `packaging/linux/appimage/AppRun`：

```sh
#!/bin/sh
# AppImage entry point for Flind Player.
set -e
if [ -z "${APPDIR:-}" ]; then
  APPDIR="$(dirname "$(readlink -f "$0")")"
fi
export LD_LIBRARY_PATH="${APPDIR}/usr/lib/flind-player/lib:${APPDIR}/usr/lib:${LD_LIBRARY_PATH:-}"
exec "${APPDIR}/usr/lib/flind-player/flind_player" "$@"
```

- [ ] **Step 2: 写 `build-appimage.sh`**

创建 `packaging/linux/build-appimage.sh`：

> **实施修正（构建时发现）**：计划原稿让 linuxdeploy 在**放入 Flutter bundle 之后**、并带 `--executable` 运行，结果它会把 AppDir 里每个 ELF 的依赖都打进去——包括整条 GTK 栈（343 MB），违反 spec §2.5「不打包 GTK」。实际实现改为：先在空的 AppDir 骨架上跑 linuxdeploy（只解析 libmpv 的 FFmpeg 闭包），再用 `--exclude-library` 排除 glib/pango/cairo 等 GTK 共享栈，最后才放入 bundle、建软链。下方代码即**实际发布**的版本。

```bash
#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# Pinned tool builds. Bumping a version requires updating its sha256 below;
# a mismatch aborts the build (fail closed) instead of silently using
# whatever the moving upstream tag points at today.
LINUXDEPLOY_VERSION="1-alpha-20251107-1"
LINUXDEPLOY_SHA256="c20cd71e3a4e3b80c3483cef793cda3f4e990aca14014d23c544ca3ce1270b4d"
APPIMAGETOOL_VERSION="1.9.1"
APPIMAGETOOL_SHA256="ed4ce84f0d9caff66f50bcca6ff6f35aae54ce8135408b3fa33abfc3cb384eb0"

LIBMPV_SO="${LIBMPV_SO:-/usr/lib/x86_64-linux-gnu/libmpv.so.2}"

parse_args "$@"
resolve_version
ensure_bundle
[ -e "${LIBMPV_SO}" ] ||
  die "libmpv not found at ${LIBMPV_SO} (Debian/Ubuntu: apt-get install libmpv-dev)"

tools="$(mktemp -d)"
appdir="$(mktemp -d)"
trap 'rm -rf "${tools}" "${appdir}"' EXIT

fetch() { # fetch <url> <sha256> <dest>
  curl -fsSL --retry 3 --connect-timeout 30 -o "$3" "$1" || die "download failed: $1"
  printf '%s  %s\n' "$2" "$3" | sha256sum -c - >/dev/null || die "sha256 mismatch: $1"
  chmod +x "$3"
}

fetch "https://github.com/linuxdeploy/linuxdeploy/releases/download/${LINUXDEPLOY_VERSION}/linuxdeploy-x86_64.AppImage" \
  "${LINUXDEPLOY_SHA256}" "${tools}/linuxdeploy"
fetch "https://github.com/AppImage/appimagetool/releases/download/${APPIMAGETOOL_VERSION}/appimagetool-x86_64.AppImage" \
  "${APPIMAGETOOL_SHA256}" "${tools}/appimagetool"

# --- AppDir skeleton --------------------------------------------------------
install -d "${appdir}/usr/bin"
install -d "${appdir}/usr/lib"
install -d "${appdir}/usr/share/applications"
install -d "${appdir}/usr/share/icons/hicolor/256x256/apps"
install -d "${appdir}/usr/share/doc/${PKG_NAME}"

install -m0644 "${BUNDLE_DIR}/share/applications/${BIN_NAME}.desktop" \
  "${appdir}/usr/share/applications/${BIN_NAME}.desktop"
install -m0644 "${BUNDLE_DIR}/share/icons/hicolor/256x256/apps/${BIN_NAME}.png" \
  "${appdir}/usr/share/icons/hicolor/256x256/apps/${BIN_NAME}.png"

write_copyright "${appdir}" yes
install -m0644 "${REPO_ROOT}/LICENSE" "${appdir}/usr/share/doc/${PKG_NAME}/LICENSE"
install -m0755 "${PACKAGING_DIR}/appimage/AppRun" "${appdir}/AppRun"

# appimagetool wants the desktop file and icon at the AppDir root too.
cp "${appdir}/usr/share/applications/${BIN_NAME}.desktop" "${appdir}/${BIN_NAME}.desktop"
cp "${appdir}/usr/share/icons/hicolor/256x256/apps/${BIN_NAME}.png" "${appdir}/${BIN_NAME}.png"

# --- deploy libmpv + its dependency closure ---------------------------------
# media_kit dlopen()s libmpv, so it is invisible to ldd; --library forces it in
# and linuxdeploy resolves its (FFmpeg) closure.
#
# libmpv's own dependency closure reaches into the GTK/desktop shared stack
# (librsvg pulls cairo/pango; ffmpeg pulls wayland/xkbcommon and glib). Those
# must come from the host, not the AppImage: GTK3 is a system dependency by
# design (spec 2.5), and mixing a bundled glib/pango/cairo with the host GTK3
# risks ABI skew (undefined symbols, broken theming/IME). Exclude them so only
# libmpv's non-desktop closure is bundled.
GTK_SHARED_EXCLUDES=(
  'libglib-2.0.so*'
  'libgio-2.0.so*'
  'libgobject-2.0.so*'
  'libgmodule-2.0.so*'
  'libpango-1.0.so*'
  'libpangocairo-1.0.so*'
  'libpangoft2-1.0.so*'
  'libcairo.so*'
  'libcairo-gobject.so*'
  'libgdk_pixbuf-2.0.so*'
  'libwayland-*.so*'
  'libxkbcommon.so*'
)
exclude_args=()
for pattern in "${GTK_SHARED_EXCLUDES[@]}"; do
  exclude_args+=(--exclude-library "${pattern}")
done

# Order matters: linuxdeploy walks EVERY ELF file already present in the AppDir.
# Running it before the Flutter bundle is copied in keeps the deployment to
# libmpv's closure only, leaving GTK3 a system dependency by design (spec 2.5)
# instead of bundling a GTK stack without its loaders/schemas.
ARCH=x86_64 "${tools}/linuxdeploy" --appimage-extract-and-run \
  --appdir "${appdir}" \
  --desktop-file "${appdir}/usr/share/applications/${BIN_NAME}.desktop" \
  --icon-file "${appdir}/usr/share/icons/hicolor/256x256/apps/${BIN_NAME}.png" \
  --library "${LIBMPV_SO}" \
  "${exclude_args[@]}"

# --- add the application itself ---------------------------------------------
install -d "${appdir}/usr/lib/${PKG_NAME}"
cp -a "${BUNDLE_DIR}/." "${appdir}/usr/lib/${PKG_NAME}/"
rm -rf "${appdir}/usr/lib/${PKG_NAME}/share"
ln -sf "../lib/${PKG_NAME}/${BIN_NAME}" "${appdir}/usr/bin/${BIN_NAME}"

# --- pack -------------------------------------------------------------------
out="${OUT_DIR}/FlindPlayer-v${VERSION}-linux-x64.AppImage"
mkdir -p "${OUT_DIR}"
# appimagetool takes SOURCE and DESTINATION positionally (there is no -o flag).
ARCH=x86_64 VERSION="${VERSION}" "${tools}/appimagetool" --appimage-extract-and-run "${appdir}" "${out}"
printf 'built %s\n' "${out}"
```

- [ ] **Step 3: 语法检查**

Run:
```bash
bash -n packaging/linux/build-appimage.sh
sh -n packaging/linux/appimage/AppRun
```
Expected: 无输出。

- [ ] **Step 4: 构建 `.AppImage`**

Run:
```bash
chmod +x packaging/linux/build-appimage.sh
packaging/linux/build-appimage.sh --version 0.5.0
```
Expected: 远端下载两个固定版本工具并通过 sha256；输出 `built …/dist/FlindPlayer-v0.5.0-linux-x64.AppImage`。

- [ ] **Step 5: 校验 libmpv 与闭包真的进去了（Review Focus #2）**

Run:
```bash
rm -rf squashfs-root /tmp/opencode/appdir-root
dist/FlindPlayer-v0.5.0-linux-x64.AppImage --appimage-extract >/dev/null
mv squashfs-root /tmp/opencode/appdir-root
find /tmp/opencode/appdir-root -name 'libmpv.so.2' -print
libmpv="$(find /tmp/opencode/appdir-root -name 'libmpv.so.2' | head -1)"
ldd "${libmpv}" | grep 'not found' || echo "no missing deps for libmpv"
test -x /tmp/opencode/appdir-root/AppRun && echo "AppRun OK"
find /tmp/opencode/appdir-root -name 'AssetManifest.bin' | head -1
```
Expected:
- `find` 打印出 AppDir **内部**的 `libmpv.so.2` 路径（Review Focus #2）
- `no missing deps for libmpv`（FFmpeg 闭包齐全）
- `AppRun OK`
- 打印出 `AssetManifest.bin` 的路径

若第 2 条输出非 `0`：按 spec §10.1 的回退方案，在 `AppRun` 里补 `LD_LIBRARY_PATH` 或在脚本里手动 `cp` 缺失库，然后重跑 Step 4–5。

- [ ] **Step 6: 反向校验 sha256 fail-closed（Review Focus #4）**

Run:
```bash
cp packaging/linux/build-appimage.sh /tmp/opencode/bad-appimage.sh
sed -i 's/^APPIMAGETOOL_SHA256=.*/APPIMAGETOOL_SHA256="0000000000000000000000000000000000000000000000000000000000000000"/' /tmp/opencode/bad-appimage.sh
OUT_DIR=/tmp/opencode/out bash /tmp/opencode/bad-appimage.sh --version 0.5.0
```
Expected: 非零退出，stderr 含 `sha256 mismatch`，且 `/tmp/opencode/out` 下**没有** `.AppImage`。

- [ ] **Step 7: 提交**

```bash
git add packaging/linux/appimage/AppRun packaging/linux/build-appimage.sh
git commit -m "build(packaging): add .AppImage builder (pinned, self-contained libmpv)"
```

---

### Task 4: Windows —— CRT app-local 暂存 + Inno Setup 安装器

**Files:**
- Create: `packaging/windows/stage-crt.ps1`
- Create: `packaging/windows/flind-player.iss`

**Interfaces:**
- `stage-crt.ps1 -ReleaseDir <path>`：把 MSVC 运行时 DLL 复制进 `ReleaseDir`（幂等）
- `flind-player.iss` 接受 Inno 预定义：`/DVersion=<x.y.z>`、`/DTag=<vX.Y.Z>`、`/DSourceDir=<abs path to Release>`；产出 `dist\FlindPlayer-<Tag>-windows-x64-setup.exe`

> 本地（Linux）无法执行 Windows 工具链；本任务的验证是「静态审阅 + 明确的一致性检查」，真正的门在 Task 8 的 CI。

- [ ] **Step 1: 写 `stage-crt.ps1`**

创建 `packaging/windows/stage-crt.ps1`：

```powershell
# Stages the MSVC runtime DLLs next to flind_player.exe (app-local deployment),
# so both the portable zip and the Inno Setup installer run on machines that do
# not have the Visual C++ Redistributable installed.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ReleaseDir
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ReleaseDir)) {
    throw "release dir not found: $ReleaseDir"
}

$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (-not (Test-Path -LiteralPath $vswhere)) {
    throw "vswhere.exe not found at $vswhere (Visual Studio Build Tools required)"
}

$vsPath = & $vswhere -latest -products * `
    -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
    -property installationPath
if (-not $vsPath) { throw 'Visual Studio with the C++ toolset was not found' }

$crtDir = Get-ChildItem -Path (Join-Path $vsPath 'VC\Redist\MSVC\*\x64\Microsoft.VC*.CRT') -Directory |
    Sort-Object -Property FullName |
    Select-Object -Last 1
if (-not $crtDir) { throw 'MSVC CRT redist directory not found' }

$dlls = @(Get-ChildItem -Path (Join-Path $crtDir.FullName '*.dll'))
if ($dlls.Count -eq 0) { throw "no DLLs found in $($crtDir.FullName)" }

foreach ($dll in $dlls) {
    Copy-Item -LiteralPath $dll.FullName -Destination (Join-Path $ReleaseDir $dll.Name) -Force
}

$staged = ($dlls | ForEach-Object { $_.Name }) -join ', '
Write-Host "staged $($dlls.Count) CRT DLLs into ${ReleaseDir}: $staged"
if (-not ($dlls.Name -contains 'vcruntime140.dll')) {
    throw 'vcruntime140.dll was not among the staged DLLs'
}
```

- [ ] **Step 2: 写 `flind-player.iss`**

创建 `packaging/windows/flind-player.iss`：

```
; Inno Setup script for Flind Player (Windows x64).
;
; Build (from the repository root):
;   ISCC.exe /DVersion=0.5.0 /DTag=v0.5.0 /DSourceDir=build\windows\x64\runner\Release packaging\windows\flind-player.iss
;
; Requires Inno Setup 7.x (x64compatible / PrivilegesRequiredOverridesAllowed).

#ifndef Version
  #error Version is required (pass /DVersion=x.y.z)
#endif
#ifndef Tag
  #define Tag "dev"
#endif
#ifndef SourceDir
  #define SourceDir "build\windows\x64\runner\Release"
#endif

#define AppName "Flind Player"
#define AppExe "flind_player.exe"
#define AppUrl "https://github.com/Q-wind520/flind-player"

[Setup]
AppId={{bb0bd0c2-8d74-42cd-bf62-e6d298019c44}
AppName={#AppName}
AppVersion={#Version}
AppVerName={#AppName} {#Version}
AppPublisher=top.qwind.app
AppPublisherURL={#AppUrl}
AppSupportURL={#AppUrl}/issues
AppUpdatesURL={#AppUrl}/releases
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\..\dist
OutputBaseFilename=FlindPlayer-{#Tag}-windows-x64-setup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
LicenseFile=..\..\LICENSE
SetupIconFile=..\..\docs\FlindPlayer.ico
UninstallDisplayIcon={app}\{#AppExe}
DisableDirPage=auto

[Languages]
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
```

- [ ] **Step 3: 静态一致性检查**

Run:
```bash
grep -q 'PrivilegesRequiredOverridesAllowed=dialog' packaging/windows/flind-player.iss && echo "privilege dialog OK"
grep -q 'OutputBaseFilename=FlindPlayer-{#Tag}-windows-x64-setup' packaging/windows/flind-player.iss && echo "output name OK"
grep -q 'vcruntime140.dll' packaging/windows/stage-crt.ps1 && echo "CRT assertion OK"
grep -q 'ChineseSimplified.isl' packaging/windows/flind-player.iss && echo "zh wizard OK"
grep -q 'bb0bd0c2-8d74-42cd-bf62-e6d298019c44' packaging/windows/flind-player.iss && echo "stable AppId OK"
python3 - <<'PY'
import re, pathlib
iss = pathlib.Path('packaging/windows/flind-player.iss').read_text()
defined = set(re.findall(r'^#define\s+(\w+)', iss, re.M)) | {'Version', 'Tag', 'SourceDir'}
used = set(re.findall(r'\{#(\w+)\}', iss))
missing = used - defined
assert not missing, f'undefined preprocessor symbols: {sorted(missing)}'
print('all {#...} symbols defined:', sorted(used))
PY
```
Expected: 六行 `OK` + 一行 `all {#...} symbols defined: [...]`。

- [ ] **Step 4: 提交**

```bash
git add packaging/windows/stage-crt.ps1 packaging/windows/flind-player.iss
git commit -m "build(packaging): add windows CRT staging and Inno Setup installer"
```

---

### Task 5: `release.yml` 集成

**Files:**
- Modify: `.github/workflows/release.yml`（`build-linux`、`build-windows`、`release` 三个 job）

**Interfaces:**
- Consumes: `packaging/linux/build-{deb,rpm,appimage}.sh`、`packaging/windows/stage-crt.ps1`、`packaging/windows/flind-player.iss`
- Produces: Release 页新增 4 个产物

- [ ] **Step 1: Linux job —— 补依赖并调用打包脚本**

把 `build-linux` 的 `Install Linux build dependencies` 步骤改为：

```yaml
      - name: Install Linux build dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y \
            libgtk-3-dev \
            libmpv-dev \
            libayatana-appindicator3-dev \
            libsecret-1-dev \
            rpm
```

（`rpm` 提供 `rpmbuild`。**不要**加 `squashfs-tools`：appimagetool `1.9.1` 自带 `mksquashfs`，其 `AppRun` 会把内置 `usr/bin` 加到 `PATH` 最前。）

把 `Package Linux bundle` 改为：

```yaml
      - name: Package Linux bundle
        run: |
          mkdir -p dist
          tar -czf "dist/FlindPlayer-${GITHUB_REF_NAME}-linux-x64.tar.gz" \
            -C build/linux/x64/release bundle
          packaging/linux/build-deb.sh --version "${GITHUB_REF_NAME#v}"
          packaging/linux/build-rpm.sh --version "${GITHUB_REF_NAME#v}"
          packaging/linux/build-appimage.sh --version "${GITHUB_REF_NAME#v}"
```

把 `Upload Linux archive` 改为：

```yaml
      - name: Upload Linux archive
        uses: actions/upload-artifact@v7
        with:
          name: linux-release
          path: dist/FlindPlayer-*-linux-x64.*
          if-no-files-found: error
          retention-days: 7
```

- [ ] **Step 2: Windows job —— CRT + zip + Inno**

在 `flutter build windows --release` 与 `Package Windows bundle` 之间插入 CRT 暂存，并改 zip 输出目录 / 追加安装器步骤：

```yaml
      - name: Stage MSVC runtime DLLs (app-local)
        run: |
          & ./packaging/windows/stage-crt.ps1 -ReleaseDir build/windows/x64/runner/Release

      - name: Package Windows bundle
        run: |
          New-Item -ItemType Directory -Force -Path dist | Out-Null
          Compress-Archive -Path build/windows/x64/runner/Release/* `
            -DestinationPath "dist/FlindPlayer-$env:GITHUB_REF_NAME-windows-x64.zip"

      - name: Install Inno Setup
        run: |
          Invoke-WebRequest `
            -Uri 'https://github.com/jrsoftware/issrc/releases/download/is-7_1_0/innosetup-7.1.0-x64.exe' `
            -OutFile "$env:TEMP\innosetup.exe"
          Start-Process -FilePath "$env:TEMP\innosetup.exe" -Wait `
            -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/SP-'

      - name: Build Windows installer
        run: |
          $iscc = (Get-ChildItem `
              -Path "$env:ProgramFiles\Inno Setup*\ISCC.exe", `
                    "${env:ProgramFiles(x86)}\Inno Setup*\ISCC.exe" `
              -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
          if (-not $iscc) { throw 'ISCC.exe not found after installing Inno Setup' }
          & $iscc `
            "/DVersion=$($env:GITHUB_REF_NAME -replace '^v','')" `
            "/DTag=$env:GITHUB_REF_NAME" `
            "/DSourceDir=$PWD\build\windows\x64\runner\Release" `
            "packaging\windows\flind-player.iss"
```

（用 Inno 官方 release 资产而非 choco：版本固定、路径确定；`ISCC.exe` 的安装目录在 7.x 可能是 `Program Files` 或 `Program Files (x86)`，故两处都 glob。）

把 `Upload Windows archive` 改为：

```yaml
      - name: Upload Windows archive
        uses: actions/upload-artifact@v7
        with:
          name: windows-release
          path: dist/FlindPlayer-*-windows-x64*
          if-no-files-found: error
          retention-days: 7
```

- [ ] **Step 3: release job —— 新增四个产物并更新说明**

把 `Create GitHub Release` 的 `files:` 中 Linux/Windows 两行改为：

```yaml
            artifacts/linux-release/dist/*
            artifacts/windows-release/dist/*
```

把 `body:`/`### 产物 / Assets` 下的整张表替换为下面这版（mac / ios / android 三行内容不变，只是位置后移）：

```
            | 文件 | 说明 |
            | --- | --- |
            | `FlindPlayer-${{ github.ref_name }}-linux-x64.deb` | Debian/Ubuntu 安装包（`sudo apt install ./FlindPlayer-….deb`；需系统 `libmpv2`） |
            | `FlindPlayer-${{ github.ref_name }}-linux-x64.rpm` | Fedora/RHEL 安装包（`sudo dnf install ./FlindPlayer-….rpm`；需系统 `mpv-libs`） |
            | `FlindPlayer-${{ github.ref_name }}-linux-x64.AppImage` | 免安装、自包含 libmpv（`chmod +x` 后直接运行；需 FUSE） |
            | `FlindPlayer-${{ github.ref_name }}-linux-x64.tar.gz` | Linux 免安装包（解压后运行 `flind_player`；需要系统 `libmpv.so.2`） |
            | `FlindPlayer-${{ github.ref_name }}-windows-x64-setup.exe` | Windows 安装器（可选「仅我」安装，无需管理员；已内置运行时） |
            | `FlindPlayer-${{ github.ref_name }}-windows-x64.zip` | Windows 免安装包（解压后运行 `flind_player.exe`；已内置 mpv 与 VC++ 运行时） |
            | `FlindPlayer-${{ github.ref_name }}-macos-arm64.zip` | macOS 桌面版（Apple Silicon，**未签名**；解压后需 `xattr -dr com.apple.quarantine "Flind Player.app"` 再打开） |
            | `FlindPlayer-${{ github.ref_name }}-ios-unsigned.ipa` | iOS（**未签名**；需用 AltStore / Sideloadly 等工具自行签名安装；暂不支持本地曲库） |
            | `FlindPlayer-${{ github.ref_name }}-arm64-v8a.apk` | **绝大多数现代手机选这个**（体积最小） |
            | `FlindPlayer-${{ github.ref_name }}-armeabi-v7a.apk` | 较老的 32 位 Android 设备 |
            | `FlindPlayer-${{ github.ref_name }}.aab` | Android App Bundle（用于 Google Play 上架） |
```

- [ ] **Step 4: 校验 YAML 语法**

Run:
```bash
python3 -c "import yaml;[yaml.safe_load(open(p)) for p in ['.github/workflows/release.yml','.github/workflows/ci.yml']];print('yaml OK')"
```
Expected: `yaml OK`。

- [ ] **Step 5: 人工复核 workflow 关键点**

Run:
```bash
grep -n "build-deb.sh\|build-rpm.sh\|build-appimage.sh\|stage-crt.ps1\|ISCC.exe\|innosetup\|dist/FlindPlayer" .github/workflows/release.yml
```
Expected: 每个脚本/命令各出现一次，且 `release` job 的 `files:` 指向 `artifacts/{linux,windows}-release/dist/*`。

- [ ] **Step 6: 提交**

```bash
git add .github/workflows/release.yml
git commit -m "ci(release): publish linux deb/rpm/AppImage and windows setup.exe"
```

---

### Task 6: `ci.yml` 集成

**Files:**
- Modify: `.github/workflows/ci.yml`（`build-linux`、`build-windows`）

**Interfaces:**
- 与 Task 5 相同的脚本调用，但**不上传**（仅验证可构建）

- [ ] **Step 1: Linux job**

在 `build-linux` 的 apt 列表追加 `rpm`，并在 `Build Linux bundle` 之后加：

```yaml
      - name: Package Linux installers (smoke)
        run: |
          packaging/linux/build-deb.sh --version "${GITHUB_REF_NAME#v}"
          packaging/linux/build-rpm.sh --version "${GITHUB_REF_NAME#v}"
          packaging/linux/build-appimage.sh --version "${GITHUB_REF_NAME#v}"
```

- [ ] **Step 2: Windows job**

在 `build-windows` 的 `Build Windows bundle` 之后加：

```yaml
      - name: Stage MSVC runtime DLLs (app-local)
        run: |
          & ./packaging/windows/stage-crt.ps1 -ReleaseDir build/windows/x64/runner/Release

      - name: Install Inno Setup
        run: |
          Invoke-WebRequest `
            -Uri 'https://github.com/jrsoftware/issrc/releases/download/is-7_1_0/innosetup-7.1.0-x64.exe' `
            -OutFile "$env:TEMP\innosetup.exe"
          Start-Process -FilePath "$env:TEMP\innosetup.exe" -Wait `
            -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/SP-'

      - name: Build Windows installer (smoke)
        run: |
          $iscc = (Get-ChildItem `
              -Path "$env:ProgramFiles\Inno Setup*\ISCC.exe", `
                    "${env:ProgramFiles(x86)}\Inno Setup*\ISCC.exe" `
              -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
          if (-not $iscc) { throw 'ISCC.exe not found after installing Inno Setup' }
          & $iscc `
            "/DVersion=$($env:GITHUB_REF_NAME -replace '^v','')" `
            "/DTag=$env:GITHUB_REF_NAME" `
            "/DSourceDir=$PWD\build\windows\x64\runner\Release" `
            "packaging\windows\flind-player.iss"
```

- [ ] **Step 3: 校验 YAML 语法**

Run:
```bash
python3 -c "import yaml;yaml.safe_load(open('.github/workflows/ci.yml'));print('yaml OK')"
```
Expected: `yaml OK`。

- [ ] **Step 4: 提交**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: smoke-build the desktop installers on pre-release tags"
```

---

### Task 7: 文档

**Files:**
- Create: `docs/packaging.md`
- Modify: `README.md`（支持平台表、构建与发布、新增「下载与安装」小节）

**Interfaces:**
- Consumes: 前六个任务产出的脚本与产物名
- Produces: 用户与维护者文档

- [ ] **Step 1: 写 `docs/packaging.md`**

创建 `docs/packaging.md`，内容需覆盖：

```markdown
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

见 `docs/superpowers/specs/2026-09-27-desktop-installers-design.md` §11 的探针结论：本项目当前无法构建鸿蒙版（社区分支的 Dart 版本尚未达到本项目要求）。
```

- [ ] **Step 2: 更新 `README.md` 的支持平台表**

把「支持平台」表中 Linux / Windows 两行的说明改为：

```
| Linux | 主推 | deb / rpm / AppImage / tar.gz；deb/rpm 需要系统 `libmpv` |
| Windows | 次要 | `setup.exe` 安装器或免安装 zip，均已内置 mpv 与 VC++ 运行时 |
```

- [ ] **Step 3: `README.md` 新增「下载与安装」小节**

在「🖥️ 支持平台」之后插入：

```markdown
## ⬇️ 下载与安装

从 [Releases](https://github.com/Q-wind520/flind-player/releases) 选择对应产物：

| 系统 | 推荐产物 | 安装 |
| --- | -------- | ---- |
| Debian / Ubuntu | `FlindPlayer-<tag>-linux-x64.deb` | `sudo apt install ./FlindPlayer-<tag>-linux-x64.deb` |
| Fedora / RHEL | `FlindPlayer-<tag>-linux-x64.rpm` | `sudo dnf install ./FlindPlayer-<tag>-linux-x64.rpm` |
| 任意 Linux | `FlindPlayer-<tag>-linux-x64.AppImage` | `chmod +x FlindPlayer-<tag>-linux-x64.AppImage && ./FlindPlayer-<tag>-linux-x64.AppImage` |
| Windows 10/11 x64 | `FlindPlayer-<tag>-windows-x64-setup.exe` | 双击运行（可选「仅我」安装，无需管理员） |

> deb/rpm 需要系统提供 `libmpv.so.2`（Ubuntu 24.04+ / Debian 12+ / Fedora 39+ 一类）。
> AppImage 需要 FUSE；若提示 `libfuse2` 缺失，用 `APPIMAGE_EXTRACT_AND_RUN=1 ./FlindPlayer-….AppImage` 运行。
> Windows 安装器未签名，SmartScreen 会提示；免安装 zip 与 deb/rpm 卸载都不会删除你的本地数据（曲库索引、收藏、离线缓存）。
```

- [ ] **Step 4: 校验文档**

Run:
```bash
test -f docs/packaging.md && echo "packaging doc OK"
grep -c 'FlindPlayer-<tag>-linux-x64.deb' README.md
grep -c 'APPIMAGE_EXTRACT_AND_RUN' README.md docs/packaging.md
```
Expected: `packaging doc OK`；两个 `grep -c` 均 ≥ 1。

- [ ] **Step 5: 提交**

```bash
git add docs/packaging.md README.md
git commit -m "docs: document desktop installer packages"
```

---

### Task 8: 端到端验证（预发布 tag 跑 CI）

**Files:**
- 无代码改动（可能回修前面任务的文件）

**Interfaces:**
- Consumes: 前七个任务全部成果
- Produces: 一份「四个产物真实生成且可安装」的证据

> 本任务会**推送标签**，属于对外可见操作，执行前必须先获得用户确认。

- [ ] **Step 1: 前置检查**

Run:
```bash
git status --short --branch
python3 -c "import yaml;[yaml.safe_load(open(p)) for p in ['.github/workflows/release.yml','.github/workflows/ci.yml']];print('yaml OK')"
flutter analyze
flutter test
```
Expected: 工作区干净；`yaml OK`；analyze 无 issue；测试全绿。

- [ ] **Step 2: 推送分支/主干并打预发布标签**（需用户确认）

Run:
```bash
git push origin master
git tag v0.5.1-pre+1
git push origin v0.5.1-pre+1
```
Expected: CI（`.github/workflows/ci.yml`）被触发。

- [ ] **Step 3: 观察 CI**

Run（需已装 `gh`；否则在网页查看）：
```bash
gh run list --workflow=CI --limit 5
gh run watch --exit-status
```
Expected: `analyze-and-test`、`build-linux`、`build-windows` 全绿；`build-linux` 的 smoke 步骤成功产出 deb/rpm/AppImage；`build-windows` 的 `Build Windows installer (smoke)` 成功。

若失败：按日志修 `packaging/**` 或两个 workflow，回到对应任务补提交，然后删除标签重打（`git push origin :v0.5.1-pre+1`）。

- [ ] **Step 4: 下载并冒烟**

从 CI 产物（或本地 `dist/`）验证：

```bash
# Linux：deb/rpm 文件表与依赖
dpkg-deb -f dist/FlindPlayer-v0.5.1-pre+1-linux-x64.deb Depends
rpm -qpl dist/FlindPlayer-v0.5.1-pre+1-linux-x64.rpm 2>/dev/null || echo "（本机无 rpm，改在容器/CI 校验）"
```

人工确认：
- `.deb` 在 Debian/Ubuntu 容器或真机 `sudo apt install ./…deb` 后，应用菜单出现 “Flind Player”，启动可播放。
- `.rpm` 在 Fedora 容器 `sudo dnf install ./…rpm` 后可启动。
- `.AppImage` 解包后 `usr/lib` 有 libmpv 闭包（Task 3 Step 5 已覆盖），`chmod +x` 后可启动。
- Windows `.setup.exe`：选「仅我」装完直接启动（不弹缺 DLL 错误）；卸载后 `%APPDATA%` 下用户数据仍在。

- [ ] **Step 5: 清理预发布标签**（若只作验证）

Run（需用户确认）：
```bash
git push origin :v0.5.1-pre+1
git tag -d v0.5.1-pre+1
```
Expected: 远端与本地标签均删除；正式发版仍走 `v0.5.0` → 之后的 `v0.6.0` 流程。

- [ ] **Step 6: 记录结果**

把冒烟结果（通过/失败与修复）追加到 `docs/packaging.md` 的「已知边界」末尾，或直接写在提交信息里；若一切通过，无需新提交。

---

## 完成标准

- `dist/` 下能本地生成 `.deb`、`.AppImage`（Windows 与 rpm 视本机工具链）。
- `release.yml` / `ci.yml` YAML 合法且包含全部打包步骤。
- `flutter analyze` 无 issue、`flutter test` 全绿（未触碰 Dart 代码）。
- 预发布 tag 的 CI 上四类产物均构建成功。
- 文档（`README.md`、`docs/packaging.md`）给出安装方式与已知边界。
