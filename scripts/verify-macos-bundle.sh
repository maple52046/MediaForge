#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly APP_DIR="${PROJECT_DIR}/target/release/bundle/macos/MediaForge.app"
readonly EXECUTABLE="${APP_DIR}/Contents/MacOS/mediaforge-app"
readonly FRAMEWORKS_DIR="${APP_DIR}/Contents/Frameworks"
readonly RESOURCES_DIR="${APP_DIR}/Contents/Resources"

if [[ ! -x "${EXECUTABLE}" ]]; then
  echo "Missing bundled executable: ${EXECUTABLE}" >&2
  exit 1
fi

for library in \
  libavcodec.62.dylib \
  libavfilter.11.dylib \
  libavformat.62.dylib \
  libavutil.60.dylib \
  libswresample.6.dylib \
  libswscale.9.dylib \
  libmp3lame.0.dylib; do
  if [[ ! -e "${FRAMEWORKS_DIR}/${library}" ]]; then
    echo "Missing bundled media library: ${library}" >&2
    exit 1
  fi
done

for notice in \
  THIRD_PARTY_NOTICES.md \
  licenses/ffmpeg/COPYING.LGPLv2.1 \
  licenses/ffmpeg/COPYING.LGPLv3 \
  licenses/lame/COPYING; do
  if [[ ! -f "${RESOURCES_DIR}/${notice}" ]]; then
    echo "Missing bundled legal notice: ${notice}" >&2
    exit 1
  fi
done

if otool -L "${EXECUTABLE}" "${FRAMEWORKS_DIR}"/*.dylib | \
  grep -E '/opt/homebrew|/usr/local|/vendor/ffmpeg'; then
  echo "Bundle contains a development-machine media-library path." >&2
  exit 1
fi

if ! otool -l "${EXECUTABLE}" | grep -q '@executable_path/../Frameworks'; then
  echo "Bundle executable is missing its Frameworks rpath." >&2
  exit 1
fi

echo "Verified relocatable MediaForge bundle: ${APP_DIR}"
