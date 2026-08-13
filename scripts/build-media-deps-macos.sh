#!/usr/bin/env bash
set -euo pipefail

readonly FFMPEG_RELEASE="n9.0.1"
readonly LAME_VERSION="3.100"
readonly LAME_SHA256="ddfe36cab873794038ae2c1210557ad34857a4b6bdc515785d1da9e175b1da1e"

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly FFMPEG_SOURCE_DIR="${PROJECT_DIR}/third_parties/FFmpeg"
readonly PREFIX="${PROJECT_DIR}/vendor/ffmpeg/macos-arm64"
readonly CACHE_DIR="${TMPDIR:-/tmp}/mediaforge-source-cache"
readonly WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mediaforge-media-deps.XXXXXX")"

cleanup() {
  rm -rf "${WORK_DIR}"
}
trap cleanup EXIT

if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "arm64" ]]; then
  echo "MediaForge 0.1.1 media dependencies require Apple Silicon macOS." >&2
  exit 1
fi

for tool in clang curl git install_name_tool make otool pkg-config shasum tar; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "Missing required tool: ${tool}" >&2
    exit 1
  fi
done

if [[ ! -f "${FFMPEG_SOURCE_DIR}/configure" ]]; then
  echo "FFmpeg submodule is missing; run: git submodule update --init third_parties/FFmpeg" >&2
  exit 1
fi

readonly FFMPEG_COMMIT="$(git -C "${FFMPEG_SOURCE_DIR}" rev-parse HEAD)"
readonly FFMPEG_DESCRIBE="$(git -C "${FFMPEG_SOURCE_DIR}" describe --tags --exact-match HEAD 2>/dev/null || true)"
readonly BUILD_FINGERPRINT="ffmpeg-${FFMPEG_COMMIT}-lame-${LAME_VERSION}-${LAME_SHA256}-recipe-4"

if [[ "${FFMPEG_DESCRIBE}" != "${FFMPEG_RELEASE}" ]]; then
  echo "Expected FFmpeg ${FFMPEG_RELEASE}, found ${FFMPEG_DESCRIBE:-an untagged commit}." >&2
  exit 1
fi
if [[ -n "$(git -C "${FFMPEG_SOURCE_DIR}" status --porcelain)" ]]; then
  echo "FFmpeg submodule must be clean before building dependencies." >&2
  exit 1
fi
dependencies_are_current() {
  [[ -f "${PREFIX}/.build-fingerprint" ]] || return 1
  [[ "$(<"${PREFIX}/.build-fingerprint")" == "${BUILD_FINGERPRINT}" ]] || return 1
  for library in \
    libmediaforge_avcodec.dylib \
    libmediaforge_avfilter.dylib \
    libmediaforge_avformat.dylib \
    libmediaforge_avutil.dylib \
    libmediaforge_mp3lame.dylib \
    libmediaforge_swresample.dylib \
    libmediaforge_swscale.dylib; do
    [[ -f "${PREFIX}/frameworks/${library}" ]] || return 1
  done
}

if dependencies_are_current; then
  echo "Using media dependencies built from FFmpeg ${FFMPEG_RELEASE} in ${PREFIX}"
  exit 0
fi

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

readonly LAME_ARCHIVE="${CACHE_DIR}/lame-${LAME_VERSION}.tar.gz"
download_and_verify \
  "https://downloads.sourceforge.net/project/lame/lame/${LAME_VERSION}/lame-${LAME_VERSION}.tar.gz" \
  "${LAME_ARCHIVE}" \
  "${LAME_SHA256}"

rm -rf "${PREFIX}"
mkdir -p "${PREFIX}"
tar -xf "${LAME_ARCHIVE}" -C "${WORK_DIR}"

export MACOSX_DEPLOYMENT_TARGET=13.0

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

readonly FFMPEG_BUILD_DIR="${WORK_DIR}/ffmpeg-build"
mkdir -p "${FFMPEG_BUILD_DIR}"
pushd "${FFMPEG_BUILD_DIR}" >/dev/null
PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig" "${FFMPEG_SOURCE_DIR}/configure" \
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
cp "${FFMPEG_SOURCE_DIR}/COPYING.LGPLv2.1" \
  "${PREFIX}/share/licenses/ffmpeg/"
cp "${FFMPEG_SOURCE_DIR}/COPYING.LGPLv3" \
  "${PREFIX}/share/licenses/ffmpeg/"
cp "${WORK_DIR}/lame-${LAME_VERSION}/COPYING" \
  "${PREFIX}/share/licenses/lame/"

mkdir -p "${PREFIX}/frameworks"
for library in "${PREFIX}"/lib/*.dylib; do
  if [[ -L "${library}" ]]; then
    continue
  fi
  case "$(basename "${library}")" in
    libavcodec.* | libavfilter.* | libavformat.* | libavutil.* | \
      libmp3lame.* | libswresample.* | libswscale.*)
      library_stem="$(basename "${library}" | cut -d. -f1)"
      bundle_name="libmediaforge_${library_stem#lib}.dylib"
      ;;
    *)
      echo "Unexpected media library: ${library}" >&2
      exit 1
      ;;
  esac
  # Constraint: Qt Multimedia ships its own FFmpeg ABI, so MediaForge libraries
  # need namespaced identities to coexist in one process without dyld collisions.
  install_name_tool -id "@rpath/${bundle_name}" "${library}"
  while IFS= read -r dependency; do
    if [[ "${dependency}" == "${PREFIX}"/lib/* ]]; then
      dependency_stem="$(basename "${dependency}" | cut -d. -f1)"
      install_name_tool -change \
        "${dependency}" \
        "@rpath/libmediaforge_${dependency_stem#lib}.dylib" \
        "${library}"
    fi
  done < <(otool -L "${library}" | tail -n +2 | awk '{print $1}')
  cp "${library}" "${PREFIX}/frameworks/${bundle_name}"
  ln -sf "$(basename "${library}")" "${PREFIX}/lib/${bundle_name}"
done

printf '%s\n' "${BUILD_FINGERPRINT}" >"${PREFIX}/.build-fingerprint"
echo "Built media dependencies from FFmpeg ${FFMPEG_RELEASE} in ${PREFIX}"
