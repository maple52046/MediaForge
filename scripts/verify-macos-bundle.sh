#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly APP_DIR="${PROJECT_DIR}/target/release/bundle/macos/MediaForge.app"
readonly EXECUTABLE="${APP_DIR}/Contents/MacOS/MediaForge"
readonly FRAMEWORKS_DIR="${APP_DIR}/Contents/Frameworks"
readonly RESOURCES_DIR="${APP_DIR}/Contents/Resources"
readonly DMG_PATH="${PROJECT_DIR}/target/release/bundle/dmg/MediaForge_0.2.0_aarch64.dmg"

if [[ ! -x "${EXECUTABLE}" ]]; then
  echo "Missing bundled executable: ${EXECUTABLE}" >&2
  exit 1
fi

for library in \
  libmediaforge_avcodec.dylib \
  libmediaforge_avfilter.dylib \
  libmediaforge_avformat.dylib \
  libmediaforge_avutil.dylib \
  libmediaforge_swresample.dylib \
  libmediaforge_swscale.dylib \
  libmediaforge_mp3lame.dylib; do
  if [[ ! -e "${FRAMEWORKS_DIR}/${library}" ]]; then
    echo "Missing bundled media library: ${library}" >&2
    exit 1
  fi
done

for notice in \
  THIRD_PARTY_NOTICES.md \
  licenses/ffmpeg/COPYING.LGPLv2.1 \
  licenses/ffmpeg/COPYING.LGPLv3 \
  licenses/lame/COPYING \
  licenses/MIT-CXX-Qt-Lineicons.txt \
  licenses/Qt-LICENSE \
  licenses/Qt-COPYING.txt; do
  if [[ ! -f "${RESOURCES_DIR}/${notice}" ]]; then
    echo "Missing bundled legal notice: ${notice}" >&2
    exit 1
  fi
done

for required in \
  "${FRAMEWORKS_DIR}/QtCore.framework" \
  "${FRAMEWORKS_DIR}/QtMultimedia.framework" \
  "${APP_DIR}/Contents/PlugIns/platforms/libqcocoa.dylib" \
  "${RESOURCES_DIR}/qml/QtQuick"; do
  if [[ ! -e "${required}" ]]; then
    echo "Missing deployed Qt runtime: ${required}" >&2
    exit 1
  fi
done

while IFS= read -r binary; do
  if otool -L "${binary}" | grep '^[[:space:]]' | grep -E \
    '/opt/homebrew|/usr/local|/Users/|/vendor/ffmpeg|/Qt/6\.11\.1'; then
    echo "Bundle contains a development-machine path: ${binary}" >&2
    exit 1
  fi
  if otool -l "${binary}" | grep ' path ' | grep -E \
    '/opt/homebrew|/usr/local|/Users/|/vendor/ffmpeg|/Qt/6\.11\.1'; then
    echo "Bundle contains a development-machine rpath: ${binary}" >&2
    exit 1
  fi
  if [[ "$(lipo -archs "${binary}")" != "arm64" ]]; then
    echo "Bundle is not Apple Silicon-only: ${binary}" >&2
    exit 1
  fi
done < <(find "${APP_DIR}/Contents" -type f -perm -111 -print)

if ! otool -l "${EXECUTABLE}" | grep -q '@executable_path/../Frameworks'; then
  echo "Bundle executable is missing its Frameworks rpath." >&2
  exit 1
fi

if [[ "$(plutil -extract CFBundleShortVersionString raw "${APP_DIR}/Contents/Info.plist")" != "0.2.0" ]] || \
  [[ "$(plutil -extract LSMinimumSystemVersion raw "${APP_DIR}/Contents/Info.plist")" != "13.0" ]]; then
  echo "Bundle version or deployment target is incorrect." >&2
  exit 1
fi

if [[ ! -f "${DMG_PATH}" ]]; then
  echo "Missing DMG: ${DMG_PATH}" >&2
  exit 1
fi

echo "Verified relocatable MediaForge app and DMG: ${APP_DIR}"
