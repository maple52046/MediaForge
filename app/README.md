# MediaForge Flutter shell

This directory contains the target desktop presentation for MediaForge 0.2.0.
During M0–M2 it is a fake-data visual prototype and has no dependency on the
Rust application or FFmpeg backend.

Run the macOS prototype from this directory:

```bash
flutter run -d macos
```

Select a deterministic screenshot state with a compile-time define:

```bash
flutter run -d macos \
  --dart-define=MEDIAFORGE_PREVIEW_STATE=converting
```

Add `--dart-define=MEDIAFORGE_COMPACT_WINDOW=true` for the 1040×680 approval
viewport. Windows and Linux runners are portability scaffolds only and are not
0.2.0 release targets.
