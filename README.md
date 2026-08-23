# MediaForge

MediaForge is a focused macOS desktop application for probing, previewing,
trimming, and converting one media file at a time. Rust calls FFmpeg libraries
directly. Version 0.2.0 is migrating the desktop presentation from Qt to
Flutter through explicit visual and functional parity gates.

## Development

Requirements:

- Apple Silicon Mac running macOS 13 or later
- Rust 1.88.0 with `rustfmt` and `clippy`
- Flutter 3.47.0 with Dart 3.13.0
- `flutter_rust_bridge_codegen` 2.12.0
- Qt 6.11.1 Desktop for macOS installed by the Qt Online Installer
- Clang, `make`, `pkg-config`, `curl`, `tar`, and Xcode command-line tools

Initialize the pinned FFmpeg source after cloning:

```bash
git submodule update --init third_parties/FFmpeg
```

Run the UI-first Flutter prototype:

```bash
cd app
flutter pub get
flutter run -d macos
```

The Flutter shell uses fake data until both UI approval milestones pass. The
Qt shell remains the functional application and a required verification gate
during this transition.

Point Cargo at Qt and run the desktop application:

```bash
export QMAKE="$HOME/Qt/6.11.1/macos/bin/qmake"
bash scripts/build-media-deps-macos.sh
cargo run -p mediaforge-qt
```

Run the complete dual-shell source verification suite:

```bash
QMAKE="$HOME/Qt/6.11.1/macos/bin/qmake" bash scripts/verify.sh
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
QMAKE="$HOME/Qt/6.11.1/macos/bin/qmake" bash scripts/bundle-macos.sh
bash scripts/verify-macos-bundle.sh
```

See [Third-party notices](THIRD_PARTY_NOTICES.md) and
[macOS distribution](docs/distribution/macos.md) for licensing, clean-machine
verification, signing, and notarization guidance.
