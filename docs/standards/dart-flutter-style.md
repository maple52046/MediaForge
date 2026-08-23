# Dart and Flutter Style Standard

Flutter is MediaForge's target desktop presentation layer. This standard
applies to Dart source, widgets, platform runners, generated bridge code,
assets, and Flutter build configuration.

## Baseline

- Use the Flutter and Dart versions pinned by the migration manuscript and
  lock every direct package dependency to an exact version.
- Let `dart format` own Dart formatting. Treat analyzer infos and warnings as
  failed gates.
- Keep analyzer strict casts, inference, and raw types enabled. Use `Object?`
  for untrusted values and narrow them explicitly; do not use `dynamic` to
  avoid modelling a boundary.
- Prefer immutable values, `const` constructors, named parameters, and small
  widgets with one presentation responsibility.
- Document exported APIs with `///` comments that state useful contracts.
  Implementation comments follow `comment-content-rule.md`.

## Architecture and state

- Flutter is an outer presentation adapter. It must not determine conversion
  capability, trim validity at execution time, job exclusivity, cancellation
  policy, or filesystem commit behavior.
- Dart owns preview, interaction, localization, theme, settings, dialogs, and
  accessibility. Rust metadata is authoritative once the backend is connected.
- Controllers expose focused `ChangeNotifier` state and widgets observe them
  with `ListenableBuilder`. Do not introduce another state framework in 0.2.0.
- Plain enum, struct, string, and integer values cross flutter_rust_bridge.
  Generated bridge types stay at the outer edge and are mapped immediately.
- Keep time as integer milliseconds. Convert only at media-player boundaries
  and format only for presentation.

## Widgets and visual system

- Use MediaForge design tokens for spacing, radius, motion, color, and text.
  Do not scatter visual constants through feature widgets.
- Prefer shadcn_ui primitives or focused MediaForge controls. Do not introduce
  default Material visual controls into the desktop interface.
- A responsive subtree may adapt its own geometry, but normal supported window
  sizes must not wrap controls, clip content, overflow, or require a full-window
  scroll view.
- Every interactive control needs a semantic label, keyboard behavior, focus
  affordance, and an equivalent non-pointer action.
- Reusable icons load through `MfIcon` from repository-owned SVG assets. Do not
  address package-cache or developer-machine asset paths at runtime.

## Controllers and failures

- Separate media session, preview, timeline, conversion, and settings state.
  A controller must not become a service locator for unrelated features.
- Represent expected failure as explicit state with a stable error code and a
  diagnostic cause. Localize the code; keep the cause for structured logs.
- Await operations whose failure or lifetime matters. Never discard a future
  that owns cancellation, a native resource, or a terminal job event.
- A source replacement commits only after probe succeeds. Preview failure is a
  degradable presentation state and must not invalidate conversion metadata.

## Testing and generated code

- Put pure Dart tests beside their feature or under `test/`; use widget tests
  for layout, semantics, and observable interaction.
- Test every supported minimum viewport and fail on overflow, clipping, control
  wrapping, or unexpected full-window scrolling.
- Keep flutter_rust_bridge output in the bridge directory. The committed output
  must reproduce exactly from the pinned generator and canonical config.
- Do not hand-edit generated plugin registrants or flutter_rust_bridge output.
  Review generated changes when a manifest or boundary changes.

## Verification

Run these gates from `app/`:

```text
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos --fatal-warnings
flutter test
flutter build macos --debug
```

The repository `scripts/verify.sh` owns these checks alongside every active Qt
and Rust gate during migration. Remove Qt requirements only when M12 formally
removes that shell.
