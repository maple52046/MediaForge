# MediaForge

MediaForge is a focused macOS desktop application for probing, previewing,
trimming, and converting one media file at a time. Rust calls FFmpeg libraries
directly, while Flutter owns the desktop presentation and native preview.

## Development

Requirements:

- Apple Silicon Mac running macOS 13 or later
- Rust 1.88.0 with `rustfmt` and `clippy`
- Flutter 3.47.0 with Dart 3.13.0
- `flutter_rust_bridge_codegen` 2.12.0
- Clang, `make`, `pkg-config`, `curl`, `tar`, and Xcode command-line tools

Initialize the pinned FFmpeg source after cloning:

```bash
git submodule update --init third_parties/FFmpeg
```

Build the repository media dependencies and run the desktop application:

```bash
bash scripts/build-media-deps-macos.sh
cd app
flutter pub get --enforce-lockfile
flutter run -d macos
```

Run the complete source, integration, and release-package verification suite:

```bash
bash scripts/verify.sh
```

The ignored FFmpeg integration test creates synthetic fixtures with a
developer-only `ffmpeg` CLI, then exercises the application's direct library
backend:

```bash
cargo test -p mediaforge-ffmpeg --test transcode -- --ignored
```

## Reproducible media dependencies

Build FFmpeg 9.0.1 from the pinned submodule and install the LGPL shared
libraries into ignored repository-local output under
`vendor/ffmpeg/macos-arm64`:

```bash
bash scripts/build-media-deps-macos.sh
```

The dependency script refuses a missing, dirty, or incorrectly tagged FFmpeg
checkout. It separately verifies the LAME 3.100 source archive checksum,
disables GPL and nonfree FFmpeg components and CLI programs, enables
VideoToolbox and native AAC, and links LAME for MP3. Stable bundled library
names and `@rpath` install names keep build-machine and FFmpeg ABI paths out of
the application bundle.

Create unsigned Apple Silicon app and DMG artifacts and verify their linkage:

```bash
bash scripts/bundle-flutter-macos.sh
bash scripts/verify-flutter-macos-bundle.sh
```

The artifacts are written to
`target/release/bundle/macos/MediaForge.app` and
`target/release/bundle/dmg/MediaForge_0.2.0_aarch64.dmg`.

See [Third-party notices](THIRD_PARTY_NOTICES.md) and
[macOS distribution](docs/distribution/macos.md) for licensing, clean-machine
verification, signing, and notarization guidance.
