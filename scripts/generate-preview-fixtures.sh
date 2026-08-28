#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly FIXTURE_DIR="${PROJECT_DIR}/target/test-fixtures"
readonly FLUTTER_FIXTURE_DIR="${PROJECT_DIR}/app/test/fixtures"

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "Missing developer-only ffmpeg CLI required for synthetic fixtures." >&2
  exit 1
fi

mkdir -p "${FIXTURE_DIR}" "${FLUTTER_FIXTURE_DIR}"

generate_fixture() {
  local encoder="$1"
  local size="$2"
  local name="$3"
  local duration="${4:-2}"
  local rate="${5:-24}"
  ffmpeg \
    -hide_banner \
    -loglevel error \
    -f lavfi \
    -i "testsrc=size=${size}:rate=${rate}" \
    -f lavfi \
    -i "sine=frequency=1000:sample_rate=48000" \
    -t "${duration}" \
    -c:v "${encoder}" \
    -b:v 2M \
    -pix_fmt yuv420p \
    -c:a aac \
    -shortest \
    -y \
    "${FIXTURE_DIR}/${name}.mp4"
  cp \
    "${FIXTURE_DIR}/${name}.mp4" \
    "${FLUTTER_FIXTURE_DIR}/${name}.mp4"
}

generate_fixture libx264 320x180 preview-h264
generate_fixture libx265 320x180 preview-hevc
generate_fixture libx265 180x320 preview-portrait-hevc
generate_fixture libx264 640x360 cancellation-h264 30 60

ffmpeg \
  -hide_banner \
  -loglevel error \
  -f lavfi \
  -i "sine=frequency=1000:sample_rate=48000" \
  -t 2 \
  -c:a aac \
  -b:a 160k \
  -movflags +faststart \
  -y \
  "${FIXTURE_DIR}/preview-audio.m4a"
cp \
  "${FIXTURE_DIR}/preview-audio.m4a" \
  "${FLUTTER_FIXTURE_DIR}/preview-audio.m4a"
