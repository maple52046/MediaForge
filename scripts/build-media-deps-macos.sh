#!/usr/bin/env bash
set -euo pipefail

readonly FFMPEG_VERSION="8.1.1"
readonly FFMPEG_SHA256="b6863adde98898f42602017462871b5f6333e65aec803fdd7a6308639c52edf3"
readonly LAME_VERSION="3.100"
readonly LAME_SHA256="ddfe36cab873794038ae2c1210557ad34857a4b6bdc515785d1da9e175b1da1e"
readonly BUILD_FINGERPRINT="ffmpeg-${FFMPEG_VERSION}-${FFMPEG_SHA256}-lame-${LAME_VERSION}-${LAME_SHA256}-recipe-2"

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly PREFIX="${PROJECT_DIR}/vendor/ffmpeg/macos-arm64"
readonly CACHE_DIR="${TMPDIR:-/tmp}/mediaforge-source-cache"
readonly WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mediaforge-media-deps.XXXXXX")"

cleanup() {
  rm -rf "${WORK_DIR}"
}
trap cleanup EXIT

if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "arm64" ]]; then
  echo "MediaForge v0.1 media dependencies require Apple Silicon macOS." >&2
  exit 1
fi

if [[ -f "${PREFIX}/.build-fingerprint" ]] && \
  [[ "$(<"${PREFIX}/.build-fingerprint")" == "${BUILD_FINGERPRINT}" ]]; then
  echo "Using verified media dependencies in ${PREFIX}"
  exit 0
fi

for tool in clang curl install_name_tool make otool pkg-config shasum tar; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "Missing required tool: ${tool}" >&2
    exit 1
  fi
done

MEDIAFORGE_BUILD_JOBS="$(sysctl -n hw.logicalcpu 2>/dev/null || true)"
if [[ ! "${MEDIAFORGE_BUILD_JOBS}" =~ ^[1-9][0-9]*$ ]]; then
  MEDIAFORGE_BUILD_JOBS=4
fi

mkdir -p "${CACHE_DIR}"

download_and_verify() {
  local url="$1"
  local archive="$2"
  local checksum="$3"
  if [[ ! -f "${archive}" ]]; then
    curl -L --fail --retry 3 --output "${archive}" "${url}"
  fi
  printf '%s  %s\n' "${checksum}" "${archive}" | shasum -a 256 -c -
}

readonly FFMPEG_ARCHIVE="${CACHE_DIR}/ffmpeg-${FFMPEG_VERSION}.tar.xz"
readonly LAME_ARCHIVE="${CACHE_DIR}/lame-${LAME_VERSION}.tar.gz"
download_and_verify \
  "https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz" \
  "${FFMPEG_ARCHIVE}" \
  "${FFMPEG_SHA256}"
download_and_verify \
  "https://downloads.sourceforge.net/project/lame/lame/${LAME_VERSION}/lame-${LAME_VERSION}.tar.gz" \
  "${LAME_ARCHIVE}" \
  "${LAME_SHA256}"

rm -rf "${PREFIX}"
mkdir -p "${PREFIX}"
tar -xf "${LAME_ARCHIVE}" -C "${WORK_DIR}"
tar -xf "${FFMPEG_ARCHIVE}" -C "${WORK_DIR}"

pushd "${WORK_DIR}/lame-${LAME_VERSION}" >/dev/null
# LAME 3.100 makes this legacy entry point private while its Darwin export list
# still names it; removing only that stale export preserves the public API used
# by FFmpeg and allows a shared arm64 library to link.
sed -i.bak '/^lame_init_old$/d' include/libmp3lame.sym
rm include/libmp3lame.sym.bak
./configure \
  --prefix="${PREFIX}" \
  --build=arm-apple-darwin \
  --disable-static \
  --enable-shared \
  --disable-frontend
make -j"${MEDIAFORGE_BUILD_JOBS}"
make install
popd >/dev/null

pushd "${WORK_DIR}/ffmpeg-${FFMPEG_VERSION}" >/dev/null
PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig" ./configure \
  --prefix="${PREFIX}" \
  --arch=arm64 \
  --target-os=darwin \
  --cc=clang \
  --enable-shared \
  --disable-static \
  --disable-debug \
  --disable-doc \
  --disable-programs \
  --disable-avdevice \
  --disable-autodetect \
  --disable-gpl \
  --disable-nonfree \
  --enable-audiotoolbox \
  --enable-videotoolbox \
  --enable-libmp3lame \
  --extra-cflags="-I${PREFIX}/include" \
  --extra-ldflags="-L${PREFIX}/lib"
make -j"${MEDIAFORGE_BUILD_JOBS}"
make install
popd >/dev/null

mkdir -p "${PREFIX}/share/licenses/ffmpeg" "${PREFIX}/share/licenses/lame"
cp "${WORK_DIR}/ffmpeg-${FFMPEG_VERSION}/COPYING.LGPLv2.1" \
  "${PREFIX}/share/licenses/ffmpeg/"
cp "${WORK_DIR}/ffmpeg-${FFMPEG_VERSION}/COPYING.LGPLv3" \
  "${PREFIX}/share/licenses/ffmpeg/"
cp "${WORK_DIR}/lame-${LAME_VERSION}/COPYING" \
  "${PREFIX}/share/licenses/lame/"

for library in "${PREFIX}"/lib/*.dylib; do
  if [[ -L "${library}" ]]; then
    continue
  fi
  case "$(basename "${library}")" in
    libavcodec.*) bundle_name="libavcodec.62.dylib" ;;
    libavfilter.*) bundle_name="libavfilter.11.dylib" ;;
    libavformat.*) bundle_name="libavformat.62.dylib" ;;
    libavutil.*) bundle_name="libavutil.60.dylib" ;;
    libmp3lame.*) bundle_name="libmp3lame.0.dylib" ;;
    libswresample.*) bundle_name="libswresample.6.dylib" ;;
    libswscale.*) bundle_name="libswscale.9.dylib" ;;
    *)
      echo "Unexpected media library: ${library}" >&2
      exit 1
      ;;
  esac
  install_name_tool -id "@rpath/${bundle_name}" "${library}"
  while IFS= read -r dependency; do
    if [[ "${dependency}" == "${PREFIX}"/lib/* ]]; then
      install_name_tool -change \
        "${dependency}" \
        "@rpath/$(basename "${dependency}")" \
        "${library}"
    fi
  done < <(otool -L "${library}" | tail -n +2 | awk '{print $1}')
done

printf '%s\n' "${BUILD_FINGERPRINT}" >"${PREFIX}/.build-fingerprint"
echo "Built reproducible media dependencies in ${PREFIX}"
