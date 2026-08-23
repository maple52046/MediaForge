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

flutter_rust_bridge_codegen generate --config-file "${CONFIG_PATH}"
if ! git -C "${PROJECT_DIR}" diff --exit-code -- \
  app/lib/bridge crates/mediaforge-flutter-bridge; then
  echo "flutter_rust_bridge generated artifacts are out of date." >&2
  exit 1
fi
