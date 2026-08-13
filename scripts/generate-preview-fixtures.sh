#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly FIXTURE_DIR="${PROJECT_DIR}/target/test-fixtures"

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "Missing developer-only ffmpeg CLI required for synthetic fixtures." >&2
  exit 1
fi

mkdir -p "${FIXTURE_DIR}"
for codec in h264 hevc; do
  if [[ "${codec}" == "h264" ]]; then
    encoder=libx264
  else
    encoder=libx265
  fi
  ffmpeg \
    -hide_banner \
    -loglevel error \
    -f lavfi \
    -i "testsrc=size=320x180:rate=24" \
    -f lavfi \
    -i "sine=frequency=1000:sample_rate=48000" \
    -t 2 \
    -c:v "${encoder}" \
    -b:v 2M \
    -pix_fmt yuv420p \
    -c:a aac \
    -shortest \
    -y \
    "${FIXTURE_DIR}/preview-${codec}.mp4"
done
