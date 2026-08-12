# MediaForge

MediaForge is a focused macOS desktop application for probing, previewing,
trimming, and converting one media file at a time. Rust calls FFmpeg libraries
directly; React and TypeScript provide the Tauri desktop interface.

## Development

Requirements:

- Apple Silicon Mac running macOS 12 or later
- Rust 1.85.1 with `rustfmt` and `clippy`
- Node.js 20.19 or later and npm
- Clang, `make`, `pkg-config`, `curl`, `tar`, and Xcode command-line tools
- FFmpeg 8 shared libraries discoverable through `pkg-config` for ordinary
  development, or the reproducible dependency build below

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

Build the pinned LGPL shared libraries into `vendor/ffmpeg/macos-arm64`:

```bash
npm run media:deps
```

The dependency script verifies SHA-256 checksums, disables GPL and nonfree
components, enables VideoToolbox and native AAC, and links LAME 3.100 for MP3.
It also rewrites bundled library identities to `@rpath`.

Create unsigned Apple Silicon app and DMG artifacts and verify their linkage:

```bash
npm run bundle:macos
npm run bundle:verify
```

See [Third-party notices](THIRD_PARTY_NOTICES.md) and
[macOS distribution](docs/distribution/macos.md) for licensing, clean-machine
verification, signing, and notarization guidance.
