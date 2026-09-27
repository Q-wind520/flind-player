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
