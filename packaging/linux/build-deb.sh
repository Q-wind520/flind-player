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
