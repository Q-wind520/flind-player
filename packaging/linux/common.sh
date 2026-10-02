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
  # A leading '-' or '+' yields an empty/invalid rpm Version (rpm_version()
  # splits on '-', rpm forbids a leading '+').
  case "${VERSION}" in
    -* | +*) die "version must not start with '-' or '+': ${VERSION}" ;;
  esac
}

ensure_bundle() {
  [ -x "${BUNDLE_DIR}/${BIN_NAME}" ] ||
    die "bundle binary not found: ${BUNDLE_DIR}/${BIN_NAME} (run: flutter build linux --release)"
  [ -f "${BUNDLE_DIR}/share/applications/${BIN_NAME}.desktop" ] ||
    die "desktop file not found under ${BUNDLE_DIR}/share/applications"
  [ -f "${BUNDLE_DIR}/share/icons/hicolor/256x256/apps/${BIN_NAME}.png" ] ||
    die "icon not found under ${BUNDLE_DIR}/share/icons"
  # A release bundle is AOT (libapp.so). A kernel_blob.bin is a stale JIT
  # artifact from a debug / `flutter run` session that `flutter build` leaves in
  # place; packaging it bloats the installer by ~100 MiB. Refuse to package.
  [ ! -e "${BUNDLE_DIR}/data/flutter_assets/kernel_blob.bin" ] ||
    die "stale kernel_blob.bin in the release bundle (run: flutter clean && flutter build linux --release)"
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
 完整文本随包附于 /usr/share/doc/flind-player/LICENSE；在 Debian/Ubuntu 上亦可指向
 /usr/share/common-licenses/GPL-3。

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
