#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly FLUTTER_PROJECT_DIR="${PROJECT_DIR}/app"
readonly PREFIX="${PROJECT_DIR}/vendor/ffmpeg/macos-arm64"
readonly SOURCE_APP="${FLUTTER_PROJECT_DIR}/build/macos/Build/Products/Release/MediaForge.app"
readonly BUNDLE_DIR="${PROJECT_DIR}/target/release/bundle"
readonly APP_DIR="${BUNDLE_DIR}/macos/MediaForge.app"
readonly FRAMEWORKS_DIR="${APP_DIR}/Contents/Frameworks"
readonly RESOURCES_DIR="${APP_DIR}/Contents/Resources"
readonly LICENSES_DIR="${RESOURCES_DIR}/licenses"
readonly FLUTTER_ASSETS_DIR="${FRAMEWORKS_DIR}/App.framework/Versions/A/Resources/flutter_assets"
readonly DMG_PATH="${BUNDLE_DIR}/dmg/MediaForge_0.2.0_aarch64.dmg"
readonly EXPECTED_FLUTTER_VERSION="3.47.0"

FLUTTER="${FLUTTER:-$(command -v flutter || true)}"
if [[ -z "${FLUTTER}" || ! -x "${FLUTTER}" ]]; then
  echo "Missing Flutter ${EXPECTED_FLUTTER_VERSION}; set FLUTTER to its executable." >&2
  exit 1
fi
readonly FLUTTER

if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "arm64" ]]; then
  echo "MediaForge 0.2.0 Flutter packaging requires Apple Silicon macOS." >&2
  exit 1
fi
for tool in codesign ditto hdiutil install_name_tool otool plutil sed; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "Missing required packaging tool: ${tool}" >&2
    exit 1
  fi
done

actual_flutter_version="$(${FLUTTER} --version --machine | \
  sed -n 's/.*"frameworkVersion":[[:space:]]*"\([^"]*\)".*/\1/p')"
if [[ "${actual_flutter_version}" != "${EXPECTED_FLUTTER_VERSION}" ]]; then
  echo "MediaForge requires Flutter ${EXPECTED_FLUTTER_VERSION}." >&2
  exit 1
fi

"${SCRIPT_DIR}/build-media-deps-macos.sh"
export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig"
export LIBRARY_PATH="${PREFIX}/lib"
export DYLD_FALLBACK_LIBRARY_PATH="${PREFIX}/frameworks:${PREFIX}/lib"
export MACOSX_DEPLOYMENT_TARGET=13.0

cd "${FLUTTER_PROJECT_DIR}"
"${FLUTTER}" pub get --enforce-lockfile
"${FLUTTER}" build macos --release --build-name=0.2.0 --build-number=1

if [[ ! -d "${SOURCE_APP}" ]]; then
  echo "Flutter did not produce the expected release app: ${SOURCE_APP}" >&2
  exit 1
fi

rm -rf "${APP_DIR}"
mkdir -p "$(dirname "${APP_DIR}")" "${LICENSES_DIR}"
ditto "${SOURCE_APP}" "${APP_DIR}"

# Invariant: conversion FFmpeg keeps a namespaced identity independent from
# media_kit's framework-packaged FFmpeg ABI in the same process.
cp "${PREFIX}/frameworks/"*.dylib "${FRAMEWORKS_DIR}/"

# Constraint: Flutter 3.47.0's engine carries an unused local-build search path
# that would make the release artifact depend on `/usr/local` policy.
install_name_tool -delete_rpath \
  "/usr/local/lib/." \
  "${FRAMEWORKS_DIR}/FlutterMacOS.framework/Versions/A/FlutterMacOS"
cp "${PROJECT_DIR}/THIRD_PARTY_NOTICES.md" "${RESOURCES_DIR}/"
cp "${PROJECT_DIR}/LICENSE" "${LICENSES_DIR}/MediaForge-LICENSE"
cp "${PROJECT_DIR}/packaging/licenses/Flutter-LICENSE" "${LICENSES_DIR}/"
cp "${PROJECT_DIR}/packaging/licenses/Dart-LICENSE" "${LICENSES_DIR}/"
cp "${PROJECT_DIR}/packaging/licenses/Lineicons-LICENSE" "${LICENSES_DIR}/"
cp "${PROJECT_DIR}/packaging/licenses/media-kit-LICENSE" "${LICENSES_DIR}/"
cp "${PROJECT_DIR}/app/rust_builder/cargokit/LICENSE" \
  "${LICENSES_DIR}/Cargokit-LICENSE"
cp -R "${PREFIX}/share/licenses/ffmpeg" "${LICENSES_DIR}/"
cp -R "${PREFIX}/share/licenses/lame" "${LICENSES_DIR}/"

# Intent: release artifacts exclude synthetic media used only by integration
# tests even though Flutter's shared asset manifest includes that fixture path.
rm -rf "${FLUTTER_ASSETS_DIR}/test/fixtures"

# Constraint: adding legal resources and refreshing conversion dylibs changes
# Xcode's sealed bundle, so the unsigned release needs a fresh ad-hoc seal.
codesign --force --deep --sign - --timestamp=none "${APP_DIR}"

mkdir -p "$(dirname "${DMG_PATH}")"
rm -f "${DMG_PATH}"
hdiutil create \
  -volname "MediaForge 0.2.0" \
  -srcfolder "${APP_DIR}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}"

"${SCRIPT_DIR}/verify-flutter-macos-bundle.sh"
