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
# Order matters: linuxdeploy walks EVERY ELF file already present in the AppDir.
# Running it before the Flutter bundle is copied in keeps the deployment to
# libmpv's closure only, leaving GTK3 a system dependency by design (spec 2.5)
# instead of bundling a GTK stack without its loaders/schemas.
ARCH=x86_64 "${tools}/linuxdeploy" --appimage-extract-and-run \
  --appdir "${appdir}" \
  --desktop-file "${appdir}/usr/share/applications/${BIN_NAME}.desktop" \
  --icon-file "${appdir}/usr/share/icons/hicolor/256x256/apps/${BIN_NAME}.png" \
  --library "${LIBMPV_SO}"

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
