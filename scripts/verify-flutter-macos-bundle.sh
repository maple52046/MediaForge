#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly BUNDLE_DIR="${PROJECT_DIR}/target/release/bundle"
readonly APP_DIR="${BUNDLE_DIR}/macos/MediaForge.app"
readonly EXECUTABLE="${APP_DIR}/Contents/MacOS/MediaForge"
readonly FRAMEWORKS_DIR="${APP_DIR}/Contents/Frameworks"
readonly RESOURCES_DIR="${APP_DIR}/Contents/Resources"
readonly LICENSES_DIR="${RESOURCES_DIR}/licenses"
readonly DMG_PATH="${BUNDLE_DIR}/dmg/MediaForge_0.2.0_aarch64.dmg"

if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "arm64" ]]; then
  echo "MediaForge 0.2.0 Flutter verification requires Apple Silicon macOS." >&2
  exit 1
fi
for tool in codesign file find grep hdiutil lipo otool plutil; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "Missing required bundle verification tool: ${tool}" >&2
    exit 1
  fi
done

if [[ ! -x "${EXECUTABLE}" ]]; then
  echo "Missing Flutter bundle executable: ${EXECUTABLE}" >&2
  exit 1
fi
if [[ -e "${APP_DIR}/Contents/MacOS/MediaForge.debug.dylib" || \
  -e "${APP_DIR}/Contents/MacOS/__preview.dylib" || \
  -e "${FRAMEWORKS_DIR}/App.framework/Versions/A/Resources/flutter_assets/test/fixtures" ]]; then
  echo "Flutter release bundle contains development-only binaries or fixtures." >&2
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
  if [[ ! -f "${FRAMEWORKS_DIR}/${library}" ]]; then
    echo "Missing Flutter conversion library: ${library}" >&2
    exit 1
  fi
done

for required in \
  "${FRAMEWORKS_DIR}/App.framework/Versions/A/App" \
  "${FRAMEWORKS_DIR}/FlutterMacOS.framework/Versions/A/FlutterMacOS" \
  "${FRAMEWORKS_DIR}/Mpv.framework/Versions/A/Mpv" \
  "${FRAMEWORKS_DIR}/Avcodec.framework/Versions/A/Avcodec" \
  "${FRAMEWORKS_DIR}/media_kit_libs_macos_video.framework/Versions/A/media_kit_libs_macos_video" \
  "${FRAMEWORKS_DIR}/media_kit_video.framework/Versions/A/media_kit_video" \
  "${FRAMEWORKS_DIR}/mediaforge_flutter_bridge.framework/Versions/A/mediaforge_flutter_bridge" \
  "${RESOURCES_DIR}/desktop_drop_desktop_drop.bundle/Contents/Resources/PrivacyInfo.xcprivacy" \
  "${RESOURCES_DIR}/file_picker_file_picker.bundle/Contents/Resources/PrivacyInfo.xcprivacy" \
  "${RESOURCES_DIR}/shared_preferences_foundation_shared_preferences_foundation.bundle/Contents/Resources/PrivacyInfo.xcprivacy" \
  "${FRAMEWORKS_DIR}/App.framework/Versions/A/Resources/flutter_assets/NOTICES.Z"; do
  if [[ ! -f "${required}" ]]; then
    echo "Missing Flutter runtime or privacy resource: ${required}" >&2
    exit 1
  fi
done

for notice in \
  THIRD_PARTY_NOTICES.md \
  licenses/MediaForge-LICENSE \
  licenses/Flutter-LICENSE \
  licenses/Dart-LICENSE \
  licenses/Cargokit-LICENSE \
  licenses/Lineicons-LICENSE \
  licenses/media-kit-LICENSE \
  licenses/ffmpeg/COPYING.LGPLv2.1 \
  licenses/ffmpeg/COPYING.LGPLv3 \
  licenses/lame/COPYING; do
  if [[ ! -f "${RESOURCES_DIR}/${notice}" ]]; then
    echo "Missing Flutter bundled legal notice: ${notice}" >&2
    exit 1
  fi
done

if [[ "$(plutil -extract CFBundleIdentifier raw "${APP_DIR}/Contents/Info.plist")" != \
  "app.mediaforge.desktop" ]] || \
  [[ "$(plutil -extract CFBundleShortVersionString raw "${APP_DIR}/Contents/Info.plist")" != \
  "0.2.0" ]] || \
  [[ "$(plutil -extract CFBundleVersion raw "${APP_DIR}/Contents/Info.plist")" != "1" ]] || \
  [[ "$(plutil -extract LSMinimumSystemVersion raw "${APP_DIR}/Contents/Info.plist")" != \
  "13.0" ]]; then
  echo "Flutter bundle identity, version, or deployment target is incorrect." >&2
  exit 1
fi

readonly CONVERSION_CODEC="${FRAMEWORKS_DIR}/libmediaforge_avcodec.dylib"
readonly PREVIEW_CODEC="${FRAMEWORKS_DIR}/Avcodec.framework/Versions/A/Avcodec"
if [[ "$(otool -D "${CONVERSION_CODEC}" | tail -n 1)" != \
  "@rpath/libmediaforge_avcodec.dylib" ]]; then
  echo "Conversion FFmpeg has an unexpected install identity." >&2
  exit 1
fi
if [[ "$(otool -D "${PREVIEW_CODEC}" | tail -n 1)" != \
  "@rpath/Avcodec.framework/Versions/A/Avcodec" ]]; then
  echo "media_kit FFmpeg has an unexpected install identity." >&2
  exit 1
fi

readonly BRIDGE="${FRAMEWORKS_DIR}/mediaforge_flutter_bridge.framework/Versions/A/mediaforge_flutter_bridge"
if ! otool -L "${BRIDGE}" | grep -q \
  '@rpath/libmediaforge_avcodec.dylib'; then
  echo "Flutter Rust bridge is not linked to namespaced conversion FFmpeg." >&2
  exit 1
fi
if ! otool -L "${EXECUTABLE}" | grep -q \
  '@rpath/FlutterMacOS.framework/Versions/A/FlutterMacOS'; then
  echo "Flutter executable is not linked to the bundled engine framework." >&2
  exit 1
fi
if ! otool -l "${EXECUTABLE}" | grep ' path ' | grep -q \
  '@executable_path/../Frameworks'; then
  echo "Flutter executable is missing its bundled Frameworks rpath." >&2
  exit 1
fi

while IFS= read -r binary; do
  if ! file "${binary}" | grep -q 'Mach-O'; then
    continue
  fi
  if otool -L "${binary}" | grep '^[[:space:]]' | grep -E \
    '/opt/homebrew|/usr/local|/Users/|/vendor/ffmpeg|/Qt/|/flutter/'; then
    echo "Flutter bundle contains a development-machine path: ${binary}" >&2
    exit 1
  fi
  if otool -l "${binary}" | grep ' path ' | grep -E \
    '/opt/homebrew|/usr/local|/Users/|/vendor/ffmpeg|/Qt/|/flutter/'; then
    echo "Flutter bundle contains a development-machine rpath: ${binary}" >&2
    exit 1
  fi
  if [[ "$(lipo -archs "${binary}")" != "arm64" ]]; then
    echo "Flutter bundle is not Apple Silicon-only: ${binary}" >&2
    exit 1
  fi
done < <(find "${APP_DIR}/Contents" -type f -perm -111 -print)

readonly SIGNATURE_INFO="$(codesign -dv --verbose=4 "${APP_DIR}" 2>&1)"
if ! grep -q '^Signature=adhoc$' <<<"${SIGNATURE_INFO}" || \
  ! grep -q '^TeamIdentifier=not set$' <<<"${SIGNATURE_INFO}"; then
  echo "Flutter bundle must use only an ad-hoc signature." >&2
  exit 1
fi
codesign --verify --deep --strict --verbose=2 "${APP_DIR}"

if [[ ! -f "${DMG_PATH}" ]]; then
  echo "Missing Flutter DMG: ${DMG_PATH}" >&2
  exit 1
fi
hdiutil verify "${DMG_PATH}"

echo "Verified relocatable Flutter app and DMG: ${APP_DIR}"
