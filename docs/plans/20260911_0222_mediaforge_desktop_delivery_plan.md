# MediaForge Desktop Delivery Plan

## 1. Purpose

MediaForge is a focused desktop utility for probing, previewing, trimming, and
converting one local media file at a time. This plan consolidates the original
0.1 implementation, the abandoned Qt migration, the repository-owned media
toolchain, the enforced development harness, the completed Flutter 0.2.0
migration, and the adaptive VideoToolbox quality work into one long-term record.

The active product is the Flutter 0.2.0 application backed by framework-neutral
Rust crates and repository-built FFmpeg 9.0.1/LAME 3.100 shared libraries. The
release gate is an unsigned-for-distribution, ad-hoc-signed Apple Silicon macOS
13+ app and DMG.

## 2. Source Scope

This consolidation covers six manuscript drafts:

- `20260812-mediaforge-v0-1.md`: initial Tauri/React product and media scope.
- `20260813-qt-migration-0-1-1.md`: Qt Quick/CXX-Qt migration design.
- `20260813-build-vendored-ffmpeg-source.md`: pinned repository FFmpeg build.
- `20260813-enforce-development-standards.md`: mandatory development harness.
- `20260819-flutter-migration-0-2-0.md`: UI-first Flutter migration through M12
  and post-migration corrections.
- `20260909-video-quality-presets.md`: adaptive VideoToolbox quality presets and
  representative-media calibration.

Tauri and Qt details are retained only as architectural history and rationale.
Flutter is the sole active presentation shell.

## 3. Consolidated Background

The first implementation used Tauri 2, React, TypeScript, Chakra UI, and a
WebView preview. Media processing already lived in Rust and called FFmpeg shared
libraries directly. Version 0.1.1 briefly migrated the shell to Qt Quick/QML,
Qt Multimedia, and CXX-Qt while extracting `mediaforge-application` for
framework-neutral job coordination.

Version 0.2.0 replaced Qt with Flutter after two explicit UI-first approval
gates. Flutter now owns desktop presentation and media_kit preview, while Rust
owns metadata, validation, job state, and conversion. Qt, QML, and CXX-Qt were
removed after functional and packaging parity passed.

The media toolchain also moved from host-installed libraries to a pinned FFmpeg
`n9.0.1` submodule at commit
`bf1b838f2ab88b4f8fd83443325c782ea0e0f7fa`, paired with `ffmpeg-next 9.0.0`,
Rust 1.88.0, and LAME 3.100. Generated libraries use relocatable `@rpath`
identities and are bundled with the application.

## 4. Confirmed Decisions

- The active version is MediaForge 0.2.0 (`0.2.0+1` for Flutter) with bundle
  identifier `app.mediaforge.desktop`.
- Apple Silicon macOS 13+ is the only supported 0.2.0 release target. Windows
  and Linux runners are portability scaffolds, not supported releases.
- Flutter is the sole UI shell. Rust remains the primary implementation
  language and the authority for probe and conversion capabilities.
- media_kit owns preview. Preview failure must never prevent conversion.
- Runtime conversion uses the repository-built FFmpeg libraries directly and
  never spawns `ffmpeg` or `ffprobe`.
- FFmpeg stays LGPL-compatible: H.264 uses VideoToolbox, AAC uses the native
  encoder, and MP3 uses LAME. `libx264`, GPL, and nonfree components remain
  disabled.
- Only one selected source and one active conversion job are supported.
- English and Traditional Chinese are supported. Language and System/Light/Dark
  appearance preferences persist; first launch follows the platform.
- The direct-download build is intentionally outside App Sandbox because a
  single-file Powerbox grant cannot create the sibling transactional output.
  file_picker bypasses its entitlement check accordingly.
- Distribution remains ad-hoc signed only. Developer ID signing, notarization,
  telemetry, and auto-update are not part of 0.2.0.
- Every repository-changing task follows the fail-closed
  `develop-by-standards` workflow, automated gates, and semantic audit.

## 5. Architecture and Design Principles

- `mediaforge-core` owns domain types, ports, output/trim validation, errors,
  progress, and cancellation abstractions. It depends on no UI, runtime, or
  FFmpeg framework.
- `mediaforge-application` owns probe use cases and `JobCoordinator`: single-job
  exclusivity, background execution, cancellation, state transitions,
  monotonic progress throttled to at most 10 Hz, and terminal events.
- `mediaforge-ffmpeg` implements the media backend. FFmpeg types remain inside
  the adapter; VideoToolbox selection and encoder options are macOS details.
- `mediaforge-flutter-bridge` is the outer FRB composition root. It initializes
  the shared backend, canonicalizes paths, reconstructs domain requests, maps
  stable errors and plain DTOs, and exposes the event stream.
- `app/` owns Flutter presentation, media acquisition, media_kit preview,
  timeline interaction, localization, preferences, and window lifecycle.
- Dependencies point inward. Data crossing boundaries is represented by
  domain-owned values or immediately mapped plain bridge values.
- Source replacement is transactional: probe succeeds before the selected
  media and preview are replaced. Failed or stale probes preserve the prior
  session.
- Conversion output is transactional: write a sibling partial, clean it after
  cancellation/failure, and atomically commit only after success. A no-overwrite
  request protects destinations created during conversion.
- Native preview surfaces are unmounted before media_kit sessions close so
  integration cases cannot retain textures across controller lifecycles.

## 6. Functional Scope

- Select one local media file with a native picker, or replace it by dropping a
  local file anywhere in the main window.
- Clear the current source explicitly. Selection, replacement, and clearing are
  disabled while conversion owns the active job.
- Probe canonical metadata and primary streams through the Rust FFmpeg backend.
- Preview supported H.264/HEVC MOV/MP4 and audio with play, pause, seek, volume,
  letterboxing, and a non-blocking fallback state.
- Edit an integer-millisecond range using start/end handles, playhead, click and
  keyboard seek, editable timestamps, Set Start, Set End, Reset, and Play
  Selection with automatic pause at the end.
- Produce Video + Audio MP4 (H.264/AAC), Video Only MP4 (H.264), and Audio Only
  MP3 when Rust-reported stream topology allows the mode.
- Select Smaller, Balanced, or High content-adaptive video quality. Audio Only
  retains High/Medium/Low MP3 quality at 256/192/128 kbps.
- Display preparing, progress, cancelling, completed, cancelled, and structured
  failed states; cancel explicitly or during safe application close.
- Edit the destination directory and filename. Extensionless names gain the
  mode-appropriate `.mp4` or `.mp3`; conflicting extensions, separators, empty
  names, and source collisions remain invalid.
- Retry `outputExists` only after explicit overwrite confirmation.

## 7. Constraints and Rules

- `0 <= start_ms < end_ms <= duration_ms`; zero/unknown duration cannot enter a
  conversion-capable media session.
- The source and output paths must be losslessly representable and canonical at
  the Rust boundary. Default output lives beside the source and uses
  `-converted` when the original extension would otherwise alias the source.
- Video modes require a video stream; Video + Audio also requires audio; Audio
  Only requires audio. The backend rejects invalid requests even when the UI
  hides unavailable modes.
- Progress is monotonic, bounded, and correlated to the active job. A terminal
  event must not be lost when the Flutter subscriber is temporarily absent.
- Controls affecting source, mode, quality, trim, or destination are locked
  during an active conversion.
- Closing during conversion requests cancellation and waits for a terminal
  event and backend cleanup before destroying the native window.
- Existing output is untouched until successful commit. Cancellation, failure,
  or destination races remove MediaForge's partial file.
- UI layout must remain usable without overflow, clipping, control wrapping, or
  whole-window scrolling at the 1040×680 minimum.
- Public Rust APIs require rustdoc; non-obvious intent, rationale, contracts,
  invariants, constraints, risks, side effects, domain mappings, and operational
  context require semantic comments without narrating the code.
- Rustfmt, Clippy warnings-as-errors, strict Dart analysis, Flutter formatting,
  tests, FRB drift, packaging verification, `git diff --check`, and semantic
  audit are mandatory before handoff.

## 8. Data Model and Format Notes

- `MediaInfo` includes canonical path, filename, size, format, duration in
  milliseconds, primary video/audio metadata, and Rust-authoritative available
  output modes.
- `OutputMode` is `VideoWithAudio`, `VideoOnly`, or `AudioOnly`.
- `TrimRange` uses integer milliseconds and enforces a non-empty bounded range.
- Normal time labels use `HH:MM:SS`; editable and accessibility values accept
  or expose `HH:MM:SS[.mmm]` with exactly three fractional digits.
- `VideoQuality` is domain-owned: `Smaller`, `Balanced`, and `High`, with
  `Balanced` as the default. The adapter maps them to VideoToolbox global
  quality values 35, 45, and 55.
- Constant-quality video deliberately leaves `rc_max_rate` unset. VideoToolbox
  treats maximum data rate as a competing rate-control mode and otherwise makes
  the presets byte-identical. Consequently, output size depends on content and
  is not guaranteed to remain below an already efficient source bitrate.
- The encoder omits the realtime hint, permits VideoToolbox software fallback,
  and uses an approximately two-second GOP: `round(fps * 2)`. A 54.51 FPS source
  therefore uses 109 frames.
- Video estimates display “depends on content.” MP3 estimates use selected
  duration and the 256/192/128 kbps bitrate.
- AAC remains 160 kbps; mono is preserved, other layouts become stereo, and the
  output sample rate is at most 48 kHz.
- Job events are a tagged union: preparing, progress, completed, cancelled, and
  failed. Errors carry a stable code for UI mapping and a diagnostic cause for
  structured local logs.

## 9. CLI / API / Config Notes

The application has no runtime conversion CLI. A developer-only FFmpeg CLI may
generate synthetic fixtures, but probe and transcode acceptance always exercise
the library backend.

The FRB bridge exposes the functional equivalents of:

- backend initialization and capability discovery;
- media probe and default-output-path calculation;
- start transcode with source, destination, mode, audio/video quality, trim,
  and overwrite policy;
- cancellation by job identifier;
- a process-wide ordered job-event stream.

Flutter/Rust code generation is pinned to flutter_rust_bridge 2.12.0 with the
stable Cargokit backend. Generated Dart and Rust files are centralized at the
bridge boundary and verified by deterministic regeneration and drift checks.

Repository configuration pins Flutter 3.47.0, Dart 3.13.0, Rust 1.88.0,
FFmpeg/ffmpeg-next 9.0.1/9.0.0, LAME 3.100, shadcn_ui 0.56.1, media_kit 1.2.6,
media_kit_video 2.0.1, media_kit_libs_video 1.0.7, flutter_svg 2.3.0,
file_picker 11.0.3, desktop_drop 0.7.1, shared_preferences 2.5.5, and
window_manager 0.5.2.

## 10. Implementation Plan

1. Maintain the clean-architecture Rust crates and plain FRB boundary; reject
   framework or FFmpeg leakage into core/application during every change.
2. Maintain transactional source acquisition, media_kit preview fallback, and
   the synchronized accessible millisecond timeline.
3. Maintain all three output modes, single-job coordination, terminal-aware
   cancellation, destination-race protection, and partial cleanup.
4. Complete the adaptive-video-quality delivery: carry `VideoQuality` through
   core, application, bridge, generated Dart, and Flutter; keep VideoToolbox
   quality-only rate control; preserve color-range metadata; and retain the
   corrected two-second GOP.
5. Preserve focused Rust, bridge, Flutter, macOS runner, synthetic FFmpeg, and
   representative-media regression coverage for quality selection, request
   mapping, preview lifecycle, trim, output topology, cancellation, and file
   safety.
6. Build the repository FFmpeg/LAME dependencies from pinned sources and run
   `bash scripts/verify.sh` for each deliverable change.
7. Package only the canonical Flutter release under
   `target/release/bundle/`; remove/reject obsolete transitional bundle paths.
8. Keep the app and DMG relocatable, arm64-only, macOS 13+, ad-hoc signed, and
   complete with privacy resources and LGPL/MIT notices and relinking details.
9. Before release, perform the outstanding manual checks with native panels,
   Finder drop, representative iPhone media, and a clean target machine.

## 11. Non-goals

- Batch conversion, multiple concurrent jobs, filters, subtitles, timeline
  editing tracks, or multi-source projects.
- FFmpeg/ffprobe CLI execution by the shipped application.
- `libx264`, GPL/nonfree FFmpeg components, static Qt, or static replacement of
  LGPL shared-library obligations.
- Restoring Tauri, React, TypeScript, Qt, QML, or CXX-Qt presentation shells.
- Windows/Linux release claims for 0.2.0.
- Apple credential handling, Developer ID signing, notarization, telemetry,
  or auto-update.
- A guaranteed output file size or fixed compression ratio for constant-quality
  video.

## 12. Open Questions

- Has the canonical packaged application been manually exercised end-to-end
  with native picker and Finder drop after the latest adaptive-quality change?
- Do all three packaged workflows, overwrite confirmation, cancellation, and
  close-during-conversion pass with representative iPhone MOV/MP4 files?
- Does the final app and DMG pass on a clean Apple Silicon macOS 13+ machine
  without Flutter, Qt, Homebrew FFmpeg, or LAME installed?
- Should a later release add an optional explicit data-rate ceiling through a
  separate rate-control mode instead of weakening the current quality presets?
- What supported-release version should follow 0.2.0 once the remaining manual
  gates are complete?

## 13. Future Work

- Add Developer ID signing and notarization when valid Apple credentials and a
  release process are available.
- Validate and package Windows and Linux only after platform-specific preview,
  encoder, filesystem-safety, linkage, and installer work is designed.
- Consider batch processing and richer editing only as separate product scopes
  that preserve current single-job invariants or deliberately replace them.
- If users need deterministic sizes, design a separate bitrate-targeted mode
  with honest estimates and VideoToolbox-specific validation rather than mixing
  it into the adaptive quality selector.
- Continue representative-media calibration across screen recordings, camera
  footage, portrait video, H.264, and HEVC while avoiding universal size claims.

### Consolidated delivery evidence

- The UI-first Flutter M1 and M2 screenshot/interaction gates were approved.
- Flutter milestones M3–M12 delivered preview, FRB, probe, trim, conversion,
  cancellation, secondary modes, file workflows, localization/preferences,
  packaging, and complete removal of Qt.
- The latest complete `bash scripts/verify.sh` run passed Dart formatting,
  strict analysis, 69 Flutter tests, 17 standard macOS integration tests,
  Cargokit and FRB drift gates, debug/release builds, Cargo format/Clippy/tests,
  synthetic VideoToolbox integration tests, and package verification.
- With representative media enabled, all 20 macOS integration tests and the
  four FFmpeg integration gates passed.
- For `ScreenRecording_08-26-2026 23-39-21_1.MP4`, Balanced produced
  40,823,603 bytes with 1,938,589 bps H.264, 163,769 bps AAC, 154,754 ms
  duration, original 1284×2778 dimensions, and preserved full-range color. The
  292,001,050-byte source remained unchanged.
- The verified canonical artifacts are
  `target/release/bundle/macos/MediaForge.app` and
  `target/release/bundle/dmg/MediaForge_0.2.0_aarch64.dmg`.
