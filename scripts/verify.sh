#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly PREFIX="${PROJECT_DIR}/vendor/ffmpeg/macos-arm64"

QMAKE="${QMAKE:-$(command -v qmake || true)}"
if [[ -z "${QMAKE}" || ! -x "${QMAKE}" ]]; then
  echo "Missing qmake; set QMAKE to the Qt 6.11.1 qmake executable." >&2
  exit 1
fi
readonly QMAKE
export QMAKE
readonly QT_BIN_DIR="$(dirname "${QMAKE}")"

if [[ "$(${QMAKE} -query QT_VERSION)" != "6.11.1" ]]; then
  echo "The transitional MediaForge Qt shell requires Qt 6.11.1." >&2
  exit 1
fi

"${SCRIPT_DIR}/build-media-deps-macos.sh"

export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig"
export LIBRARY_PATH="${PREFIX}/lib"
export DYLD_FALLBACK_LIBRARY_PATH="${PREFIX}/frameworks:${PREFIX}/lib"
export MACOSX_DEPLOYMENT_TARGET=13.0
export PATH="${QT_BIN_DIR}:${PATH}"

cd "${PROJECT_DIR}"
"${SCRIPT_DIR}/generate-preview-fixtures.sh"
"${SCRIPT_DIR}/verify-flutter.sh"
cargo fmt --check
cargo clippy --workspace --all-targets --all-features -- -D warnings
cargo test --workspace
cargo build -p mediaforge-qt

qml_module_root="$(find "${PROJECT_DIR}/target/debug/build" -type d \
  -path '*/out/qt-build-utils/qml_modules' -print -quit)"
if [[ -z "${qml_module_root}" ]]; then
  echo "CXX-Qt did not generate the QML module metadata." >&2
  exit 1
fi

"${SCRIPT_DIR}/check-qml-format.sh"
qmllint -W 0 -I "${qml_module_root}" \
  "${PROJECT_DIR}/qml/Main.qml" \
  "${PROJECT_DIR}/qml/components/"*.qml \
  "${PROJECT_DIR}/qml/controls/"*.qml \
  "${PROJECT_DIR}/qml/tests/"*.qml \
  "${PROJECT_DIR}/qml/theme/"*.qml
QT_QPA_PLATFORM=offscreen qmltestrunner \
  -input "${PROJECT_DIR}/qml/tests" \
  -import "${PROJECT_DIR}/qml" \
  -o -,txt

cargo test -p mediaforge-ffmpeg --test transcode -- --ignored

"${SCRIPT_DIR}/bundle-macos.sh"
