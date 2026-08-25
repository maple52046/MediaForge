#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly CONFIG_PATH="${PROJECT_DIR}/flutter_rust_bridge.yaml"

if [[ ! -e "${CONFIG_PATH}" ]]; then
  if find "${PROJECT_DIR}/app/lib" -type f \
    -path '*/bridge_generated*' -print -quit | grep -q .; then
    echo "Generated FRB artifacts exist without flutter_rust_bridge.yaml." >&2
    exit 1
  fi
  exit 0
fi

cd "${PROJECT_DIR}"

codegen_digest() {
  find \
    "${PROJECT_DIR}/app/lib/bridge" \
    "${PROJECT_DIR}/crates/mediaforge-flutter-bridge" \
    -type f -exec shasum -a 256 {} + | LC_ALL=C sort | shasum -a 256 | awk '{print $1}'
}

readonly DIGEST_BEFORE="$(codegen_digest)"
flutter_rust_bridge_codegen generate --config-file "${CONFIG_PATH}"
readonly DIGEST_AFTER="$(codegen_digest)"
if [[ "${DIGEST_BEFORE}" != "${DIGEST_AFTER}" ]]; then
  echo "flutter_rust_bridge generation changed the checked bridge tree." >&2
  exit 1
fi
