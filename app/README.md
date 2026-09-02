# MediaForge Flutter application

This directory contains the MediaForge 0.2.0 desktop presentation. Flutter owns
native preview and interaction; the generated flutter_rust_bridge boundary
connects probing and conversion to the framework-independent Rust application
and repository FFmpeg adapter.

Build the repository media dependencies, then run the macOS application from
this directory:

```bash
bash ../scripts/build-media-deps-macos.sh
flutter pub get --enforce-lockfile
flutter run -d macos
```

Use the in-app picker or Finder drag-and-drop to load a local media file.
Windows and Linux runners are portability scaffolds only and are not 0.2.0
release targets.
