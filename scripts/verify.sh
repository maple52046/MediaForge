#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly PREFIX="${PROJECT_DIR}/vendor/ffmpeg/macos-arm64"

"${SCRIPT_DIR}/build-media-deps-macos.sh"

export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig"
export LIBRARY_PATH="${PREFIX}/lib"
export DYLD_FALLBACK_LIBRARY_PATH="${PREFIX}/lib"

cd "${PROJECT_DIR}"
npm run format:check
npm run lint
npm run test
npm run build
cargo fmt --check
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace
