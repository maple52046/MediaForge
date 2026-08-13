#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly PREFIX="${PROJECT_DIR}/vendor/ffmpeg/macos-arm64"
readonly APP_DIR="${PROJECT_DIR}/target/release/bundle/macos/MediaForge.app"
readonly CONTENTS_DIR="${APP_DIR}/Contents"
readonly FRAMEWORKS_DIR="${CONTENTS_DIR}/Frameworks"
readonly RESOURCES_DIR="${CONTENTS_DIR}/Resources"
readonly DMG_PATH="${PROJECT_DIR}/target/release/bundle/dmg/MediaForge_0.1.1_aarch64.dmg"
readonly QML_SCAN_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mediaforge-qml-scan.XXXXXX")"

cleanup() {
  rm -rf "${QML_SCAN_DIR}"
}
trap cleanup EXIT

QMAKE="${QMAKE:-$(command -v qmake || true)}"
if [[ -z "${QMAKE}" || ! -x "${QMAKE}" ]]; then
  echo "Missing qmake; set QMAKE to the Qt 6.11.1 qmake executable." >&2
  exit 1
fi
readonly QMAKE
export QMAKE
readonly QT_BIN_DIR="$(dirname "${QMAKE}")"
readonly MACDEPLOYQT="${QT_BIN_DIR}/macdeployqt"
readonly QT_LICENSE_DIR="$(${QMAKE} -query QT_INSTALL_PREFIX)/../..//Licenses"

if [[ "$(${QMAKE} -query QT_VERSION)" != "6.11.1" ]]; then
  echo "MediaForge 0.1.1 requires Qt 6.11.1." >&2
  exit 1
fi
if [[ ! -x "${MACDEPLOYQT}" ]]; then
  echo "Missing macdeployqt next to qmake: ${MACDEPLOYQT}" >&2
  exit 1
fi

"${SCRIPT_DIR}/build-media-deps-macos.sh"

export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig"
export LIBRARY_PATH="${PREFIX}/lib"
export DYLD_FALLBACK_LIBRARY_PATH="${PREFIX}/frameworks:${PREFIX}/lib"
export MACOSX_DEPLOYMENT_TARGET=13.0

cd "${PROJECT_DIR}"
cargo build --release -p mediaforge-qt

rm -rf "${APP_DIR}"
mkdir -p "${CONTENTS_DIR}/MacOS" "${FRAMEWORKS_DIR}" "${RESOURCES_DIR}/licenses"
cp "${PROJECT_DIR}/target/release/mediaforge-qt" "${CONTENTS_DIR}/MacOS/MediaForge"
cp "${PROJECT_DIR}/packaging/macos/Info.plist" "${CONTENTS_DIR}/Info.plist"
cp "${PROJECT_DIR}/packaging/macos/MediaForge.icns" "${RESOURCES_DIR}/MediaForge.icns"
cp "${PREFIX}/frameworks/"*.dylib "${FRAMEWORKS_DIR}/"

cp "${PROJECT_DIR}/qml/Main.qml" "${QML_SCAN_DIR}/"
for directory in components controls lib theme; do
  cp -R "${PROJECT_DIR}/qml/${directory}" "${QML_SCAN_DIR}/"
done

"${MACDEPLOYQT}" "${APP_DIR}" \
  -qmldir="${QML_SCAN_DIR}" \
  -appstore-compliant \
  -always-overwrite \
  -no-codesign \
  -verbose=1

# Constraint: Qt's generic QML dependency metadata pulls LocalStorage into a
# Controls application even though MediaForge does not import or use QtSql.
rm -rf \
  "${CONTENTS_DIR}/PlugIns/sqldrivers" \
  "${FRAMEWORKS_DIR}/QtSql.framework" \
  "${RESOURCES_DIR}/qml/QtQuick/LocalStorage"

# Constraint: 0.1.1 is an Apple Silicon release, while the official Qt SDK
# distributes universal frameworks and plugins by default.
while IFS= read -r binary; do
  if lipo -archs "${binary}" 2>/dev/null | grep -q 'x86_64'; then
    lipo -thin arm64 "${binary}" -output "${binary}.arm64"
    mv "${binary}.arm64" "${binary}"
  fi
done < <(find "${APP_DIR}/Contents" -type f -perm -111 -print)
cp "${PROJECT_DIR}/THIRD_PARTY_NOTICES.md" "${RESOURCES_DIR}/"
cp -R "${PREFIX}/share/licenses/ffmpeg" "${RESOURCES_DIR}/licenses/"
cp -R "${PREFIX}/share/licenses/lame" "${RESOURCES_DIR}/licenses/"
cp "${PROJECT_DIR}/packaging/licenses/MIT-CXX-Qt-Lineicons.txt" \
  "${RESOURCES_DIR}/licenses/"
cp "${QT_LICENSE_DIR}/LICENSE" "${RESOURCES_DIR}/licenses/Qt-LICENSE"
cp "${QT_LICENSE_DIR}/COPYING.txt" "${RESOURCES_DIR}/licenses/Qt-COPYING.txt"

mkdir -p "$(dirname "${DMG_PATH}")"
rm -f "${DMG_PATH}"
hdiutil create \
  -volname "MediaForge 0.1.1" \
  -srcfolder "${APP_DIR}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}"

"${SCRIPT_DIR}/verify-macos-bundle.sh"
