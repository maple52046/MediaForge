#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly QMLFORMAT="${QMLFORMAT:-qmlformat}"
readonly WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mediaforge-qml-format.XXXXXX")"

cleanup() {
  rm -rf "${WORK_DIR}"
}
trap cleanup EXIT

if ! command -v "${QMLFORMAT}" >/dev/null 2>&1; then
  echo "Missing qmlformat; add Qt 6.11.1 bin to PATH or set QMLFORMAT." >&2
  exit 1
fi

status=0
while IFS= read -r source; do
  relative="${source#${PROJECT_DIR}/}"
  formatted="${WORK_DIR}/${relative}"
  mkdir -p "$(dirname "${formatted}")"
  "${QMLFORMAT}" "${source}" >"${formatted}"
  if ! cmp -s "${source}" "${formatted}"; then
    echo "QML formatting differs: ${relative}" >&2
    diff -u "${source}" "${formatted}" || true
    status=1
  fi
done < <(find "${PROJECT_DIR}/qml" -type f \( -name '*.qml' -o -name '*.js' \) | sort)

exit "${status}"
