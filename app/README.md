# MediaForge Flutter shell

This directory contains the target desktop presentation for MediaForge 0.2.0.
M3 uses media_kit for native preview but still has no dependency on the Rust
application or MediaForge FFmpeg backend.

Run the macOS prototype from this directory:

```bash
bash ../scripts/generate-preview-fixtures.sh
flutter run -d macos
```

The desktop entry point previews the generated HEVC/AAC fixture. Override it
with a local file or another media_kit URI:

```bash
flutter run -d macos \
  --dart-define=MEDIAFORGE_PREVIEW_PATH=/absolute/path/to/video.mov
```

Select a deterministic visual state with a compile-time define:

```bash
flutter run -d macos \
  --dart-define=MEDIAFORGE_PREVIEW_STATE=converting
```

Add `--dart-define=MEDIAFORGE_COMPACT_WINDOW=true` for the 1040×680 approval
viewport. Windows and Linux runners are portability scaffolds only and are not
0.2.0 release targets.
