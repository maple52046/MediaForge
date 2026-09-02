# Third-party notices

MediaForge application source is licensed under the MIT License. Distribution
artifacts also include dynamically linked third-party components under their
respective licenses.

## Flutter 3.47.0 and Dart 3.13.0

The target desktop shell uses the Flutter engine and Dart runtime under their
BSD-style licenses. Flutter packages and their transitive Dart dependencies are
listed in the generated `App.framework` `flutter_assets/NOTICES.Z` archive.

- Flutter source: <https://github.com/flutter/flutter/tree/3.47.0>
- Dart SDK source: <https://github.com/dart-lang/sdk>
- Package lock: `app/pubspec.lock`
- Deployment recipe: `scripts/bundle-flutter-macos.sh`
- License copies: `licenses/Flutter-LICENSE` and `licenses/Dart-LICENSE`

## flutter_rust_bridge 2.12.0 and Cargokit

The Flutter shell maps plain application values through flutter_rust_bridge.
Cargokit builds the Rust static library and exposes it through a shared macOS
plugin framework. Both projects are available under permissive licenses; the
generated Dart package notice archive covers flutter_rust_bridge and the bundle
also contains Cargokit's license text.

- flutter_rust_bridge source: <https://github.com/fzyzcjy/flutter_rust_bridge/tree/v2.12.0>
- Cargokit source snapshot: `app/rust_builder/cargokit`
- Cargokit license copy: `licenses/Cargokit-LICENSE`

## media_kit 1.2.6 and libmpv

Preview uses media_kit 1.2.6, media_kit_video 2.0.1, and the pinned
media_kit_libs_video 1.0.7 dependency. On macOS the resolved native package is
media_kit_libs_macos_video 1.1.4. It bundles libmpv and an independent FFmpeg
build as named frameworks such as `Mpv.framework` and `Avcodec.framework`.

The native frameworks come from media-kit's `libmpv-xcframeworks` v0.6.0
macOS universal release, whose package recipe pins SHA-256
`84d2ad98e046e82c6dc34d8547d76c2afeaee89c0f53032773be8985c95536d6`.
MediaForge's Apple Silicon build embeds only the arm64 slices selected by
Xcode. libmpv and its FFmpeg build are dynamically linked under LGPL terms;
other libraries in the framework family retain their respective upstream
licenses.

- media_kit source: <https://github.com/media-kit/media-kit>
- Native package source: <https://pub.dev/packages/media_kit_libs_macos_video/versions/1.1.4>
- libmpv build source and recipes: <https://github.com/media-kit/libmpv-darwin-build/tree/v0.6.0>
- Binary release: <https://github.com/media-kit/libmpv-darwin-build/releases/tag/v0.6.0>
- Package license copy: `licenses/media-kit-LICENSE`
- LGPL text: `licenses/ffmpeg/COPYING.LGPLv2.1`
- Relinking: replace compatible media_kit frameworks in `Contents/Frameworks`;
  MediaForge's ad-hoc signature may then be recreated locally and contains no
  technical measure that prohibits replacement

The media_kit FFmpeg frameworks and MediaForge's conversion FFmpeg libraries
intentionally use different install identities. Preview names use framework
identities, while conversion names begin with `libmediaforge_`; do not replace
one family with binaries built for the other ABI.

## Lineicons free icons 1.0.6

The small SVG subset in `app/assets/icons` was exported from
`@lineiconshq/free-icons` and is bundled under the MIT License.

- Project: <https://lineicons.com/>
- Flutter bundle license copy: `licenses/Lineicons-LICENSE`

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
- Flutter deployment recipe: `scripts/bundle-flutter-macos.sh`
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
Flutter release artifacts retain ad-hoc signatures only; after replacing a
compatible library or framework, recipients may recreate that local seal with
`codesign --force --deep --sign - MediaForge.app`.
