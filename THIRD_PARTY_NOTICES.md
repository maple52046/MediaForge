# Third-party notices

MediaForge application source is licensed under the MIT License. Distribution
artifacts also include dynamically linked third-party components under their
respective licenses.

## Qt 6.11.1

MediaForge dynamically links the Qt Core, GUI, Quick, QML, Network, and
Multimedia shared frameworks under the Qt Community LGPLv3 terms. The bundle
is intentionally unsigned and does not use static Qt linking.

- Project and source: <https://code.qt.io/cgit/qt/>
- Release source: <https://download.qt.io/archive/qt/6.11/6.11.1/submodules/>
- Deployment recipe: `scripts/bundle-macos.sh` using `macdeployqt`
- Relinking: replace compatible frameworks and plugins in the app bundle;
  MediaForge contains no technical measure that prohibits replacement

## CXX-Qt 0.9.1

CXX-Qt provides the generated Rust/C++ Qt bridge and is licensed under MIT or
Apache-2.0. MediaForge uses the MIT option for its bundled notice.

- Project and source: <https://github.com/KDAB/cxx-qt/tree/v0.9.1>

## Lineicons free icons 1.0.6

The small SVG subset in `assets/icons` was exported from
`@lineiconshq/free-icons` and is bundled under the MIT License.

- Project: <https://lineicons.com/>

## FFmpeg 9.0.1

MediaForge's reproducible configuration disables GPL and nonfree components and
builds FFmpeg as shared libraries under the GNU Lesser General Public License,
version 2.1 or later. The build enables Apple VideoToolbox, Apple AudioToolbox,
and the external LAME encoder. It does not enable libx264.

- Project: <https://ffmpeg.org/>
- Source: repository submodule `third_parties/FFmpeg`, pinned to upstream tag
  `n9.0.1` at commit `bf1b838f2ab88b4f8fd83443325c782ea0e0f7fa`
- Upstream: <https://github.com/FFmpeg/FFmpeg/tree/n9.0.1>
- Build recipe: `scripts/build-media-deps-macos.sh`
- License copies in built artifacts: `share/licenses/ffmpeg`

## LAME 3.100

LAME is dynamically linked to provide MP3 encoding under the GNU Lesser
General Public License, version 2 or later.

- Project: <https://lame.sourceforge.io/>
- Source: <https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz>
- Build recipe: `scripts/build-media-deps-macos.sh`
- License copy in built artifacts: `share/licenses/lame`

Recipients may replace the bundled shared libraries with compatible modified
versions. Clone this repository with `--recurse-submodules`, or run
`git submodule update --init third_parties/FFmpeg`, to obtain the exact FFmpeg
source. The checksummed LAME source archive and complete build instructions
above provide the remaining source and relinking information for this release.
