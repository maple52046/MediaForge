#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly FLUTTER_PROJECT_DIR="${PROJECT_DIR}/app"
readonly EXPECTED_FLUTTER_VERSION="3.47.0"
readonly EXPECTED_FRB_CODEGEN_VERSION="2.12.0"

FLUTTER="${FLUTTER:-$(command -v flutter || true)}"
if [[ -z "${FLUTTER}" || ! -x "${FLUTTER}" ]]; then
  echo "Missing Flutter ${EXPECTED_FLUTTER_VERSION}; set FLUTTER to its executable." >&2
  exit 1
fi
readonly FLUTTER
readonly DART="${DART:-$(dirname "${FLUTTER}")/dart}"

if [[ ! -x "${DART}" ]]; then
  echo "Missing Dart next to the pinned Flutter executable: ${DART}" >&2
  exit 1
fi

actual_flutter_version="$(${FLUTTER} --version --machine | \
  sed -n 's/.*"frameworkVersion":[[:space:]]*"\([^"]*\)".*/\1/p')"
if [[ "${actual_flutter_version}" != "${EXPECTED_FLUTTER_VERSION}" ]]; then
  echo "MediaForge requires Flutter ${EXPECTED_FLUTTER_VERSION}." >&2
  exit 1
fi

if ! command -v flutter_rust_bridge_codegen >/dev/null 2>&1; then
  echo "Missing flutter_rust_bridge_codegen ${EXPECTED_FRB_CODEGEN_VERSION}." >&2
  exit 1
fi
actual_frb_version="$(flutter_rust_bridge_codegen --version | awk '{print $2}')"
if [[ "${actual_frb_version}" != "${EXPECTED_FRB_CODEGEN_VERSION}" ]]; then
  echo "MediaForge requires flutter_rust_bridge_codegen ${EXPECTED_FRB_CODEGEN_VERSION}." >&2
  exit 1
fi

cd "${FLUTTER_PROJECT_DIR}"
"${FLUTTER}" pub get --enforce-lockfile
"${DART}" format --output=none --set-exit-if-changed .
"${FLUTTER}" analyze --fatal-infos --fatal-warnings
"${FLUTTER}" test
"${FLUTTER}" test integration_test -d macos
"${FLUTTER}" build macos --debug
"${SCRIPT_DIR}/verify-frb-codegen.sh"
