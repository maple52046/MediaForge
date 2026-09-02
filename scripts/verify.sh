#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly PREFIX="${PROJECT_DIR}/vendor/ffmpeg/macos-arm64"

"${SCRIPT_DIR}/build-media-deps-macos.sh"

export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig"
export LIBRARY_PATH="${PREFIX}/lib"
export DYLD_FALLBACK_LIBRARY_PATH="${PREFIX}/frameworks:${PREFIX}/lib"
export MACOSX_DEPLOYMENT_TARGET=13.0

cd "${PROJECT_DIR}"
"${SCRIPT_DIR}/generate-preview-fixtures.sh"
"${SCRIPT_DIR}/verify-flutter.sh"
"${SCRIPT_DIR}/bundle-flutter-macos.sh"
cargo fmt --check
cargo clippy --workspace --all-targets --all-features -- -D warnings
cargo test --workspace

cargo test -p mediaforge-ffmpeg --test transcode -- --ignored
