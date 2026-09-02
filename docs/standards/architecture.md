# Architecture Standard

This project follows **The Clean Architecture** (Robert C. Martin). This
document adapts its load-bearing rule—the Dependency Rule—to a Rust application
with a Flutter presentation edge.

> Source of the underlying principles: Robert C. Martin, *The Clean
> Architecture*, 2012. <https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html>

## The Dependency Rule

Source-code dependencies point **inwards only**. An inner layer must never name
anything declared in an outer layer. Data crossing a boundary is a plain value
owned by the inner layer, never a framework-shaped or driver-shaped value.

Enforce the rule at crate and module boundaries: core crates expose domain
types and port traits but never depend on adapter crates, runtimes, or framework
types. Generated flutter_rust_bridge values remain in the outermost adapter.
Shared types belong to the innermost layer that owns their meaning.

## Layers (inner to outer)

1. **Domain.** Pure media types, validation, and port contracts. It has no I/O,
   concurrency runtime, FFmpeg, or presentation-framework dependency.
2. **Use cases.** Application policy coordinating one job, cancellation,
   progress, and terminal states. It depends on domain-owned ports rather than
   a concrete backend or presentation framework.
3. **Interface adapters.** FFmpeg implements the media port. The Flutter bridge
   maps application values into plain values generated for Dart.
4. **Frameworks and drivers.** Flutter, FFmpeg, the filesystem, native dialogs,
   and worker threads are concrete details wired at executable composition
   roots.

## Ports and composition

Rust ports are small traits defined by the consuming inner crate. Inject
implementations through generics when static dispatch helps, or `dyn Trait` at
runtime boundaries. Select concrete implementations only at an executable
composition root. Do not use service locators or import a concrete adapter from
an inner crate.

The Flutter adapter exposes plain application values through
flutter_rust_bridge. Inner crates must never depend on Flutter, Dart,
flutter_rust_bridge, or generated bridge types.

## Project rules

- `mediaforge-core` MUST NOT depend on adapters, FFmpeg, presentation
  frameworks, or a concurrency runtime.
- `mediaforge-application` depends on core ports and domain types, not concrete
  FFmpeg or presentation implementations.
- `mediaforge-ffmpeg` implements core ports without exposing FFmpeg values
  beyond the adapter.
- `mediaforge-flutter-bridge` is the outer Rust adapter and composition root
  for backend initialization, application wiring, and plain boundary mapping.
- `app/` owns Flutter presentation, preview, native interaction, localization,
  and preferences; conversion capability remains authoritative in the backend.
- Side-effecting details remain at the edges, and all cross-layer failures keep
  their stable application-owned error category.

## Repository layout

```text
crates/
  mediaforge-core/         # entities, validation, and inward-owned ports
  mediaforge-application/  # framework-independent job coordination
  mediaforge-ffmpeg/       # FFmpeg port implementation
  mediaforge-flutter-bridge/ # outer Rust adapter and composition root
app/                       # Flutter presentation and desktop runners
```

This layout expresses dependency direction; it is not a reason to create empty
packages. Generated flutter_rust_bridge artifacts remain at the outer framework
boundary and never enter an inner crate.

## Testability consequence

Domain and application policy are unit-testable without Flutter, FFmpeg, the
filesystem, or a real worker runtime. Test doubles implement the ports. Adapter
integration tests exercise repository-built FFmpeg libraries, while Flutter
unit, widget, and desktop integration tests exercise presentation behavior.
