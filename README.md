# MediaForge

MediaForge is a focused macOS desktop application for probing, previewing,
trimming, and converting one media file at a time. Rust calls FFmpeg libraries
directly; React and TypeScript provide the Tauri desktop interface.

## Development

Requirements:

- Apple Silicon Mac running macOS 12 or later
- Rust 1.88.0 with `rustfmt` and `clippy`
- Node.js 20.19 or later and npm
- Clang, `make`, `pkg-config`, `curl`, `tar`, and Xcode command-line tools

Initialize the pinned FFmpeg source after cloning:

```bash
git submodule update --init third_parties/FFmpeg
```

Install JavaScript dependencies and run the desktop application:

```bash
npm install
npm run tauri dev
```

Run the complete source verification suite:

```bash
npm run verify
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
npm run media:deps
```

The dependency script refuses a missing, dirty, or incorrectly tagged FFmpeg
checkout. It separately verifies the LAME 3.100 source archive checksum,
disables GPL and nonfree FFmpeg components and CLI programs, enables
VideoToolbox and native AAC, and links LAME for MP3. Stable bundled library
names and `@rpath` install names keep build-machine and FFmpeg ABI paths out of
the application bundle.

Create unsigned Apple Silicon app and DMG artifacts and verify their linkage:

```bash
npm run bundle:macos
npm run bundle:verify
```

See [Third-party notices](THIRD_PARTY_NOTICES.md) and
[macOS distribution](docs/distribution/macos.md) for licensing, clean-machine
verification, signing, and notarization guidance.
