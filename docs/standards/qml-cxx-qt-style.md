# QML and CXX-Qt Style Standard

Qt Quick/QML is MediaForge's desktop presentation layer. CXX-Qt is the narrow
adapter between QML and the Rust application layer. This standard applies to
QML, QML JavaScript modules, CXX-Qt bridge declarations, build scripts that
generate C++ code, and any handwritten C++ required at the Qt boundary.

## Baseline

- Target the Qt version pinned by the workspace and use only APIs available on
  the declared minimum macOS version.
- Let `qmlformat` own QML formatting. Treat every `qmllint` warning as a failed
  gate unless a repository standard documents a specific exception.
- Use Cargo as the root build system. CXX-Qt build scripts may invoke Qt build
  tooling internally, but contributors do not maintain a second root CMake
  project.
- Keep QML declarative. Move reusable calculations and state policy to small,
  tested JavaScript modules or inward Rust layers rather than imperative signal
  handlers.

## Architecture and boundaries

- QML owns presentation state and Qt Multimedia playback. It must not decide
  media capability, transcode validity, job exclusivity, cancellation state, or
  filesystem commit policy.
- The application crate owns use-case events and values. CXX-Qt converts those
  values to Qt-compatible properties and signals without leaking `QString`,
  `QUrl`, QObject, or Qt enums inward.
- A worker thread never mutates a QObject directly. Queue every worker result
  through CXX-Qt's Qt-thread handle and let the queued closure perform property
  changes and signal emission.
- `MediaForgeController` is the primary QML bridge. Add another QObject only
  when a separate lifecycle or reusable Qt model makes the boundary clearer.
- Native dialogs, settings storage, theme observation, drag/drop, and preview
  stay in the Qt/QML layer. FFmpeg remains the only authority for conversion
  metadata and supported output modes.

## QML modules and files

- Organize QML under `qml/` by components, controls, theme, assets, and tests.
  Components use `UpperCamelCase.qml`; JavaScript modules use `lower_snake_case.js`.
- Declare required properties and use explicit signal signatures. Avoid
  untyped ad-hoc objects when a property set or Rust bridge contract is stable.
- Prefer anchors or one layout system per visual subtree. Do not mix anchors
  with layout-managed geometry on the same item.
- Bind presentation directly to source state. Do not copy a property into local
  state unless the copy has a defined edit/commit lifecycle.
- Give interactive controls accessible names, keyboard behavior, focus order,
  and visible focus. Custom pointer interaction must have an equivalent keyboard
  path.
- Store media time as integer milliseconds. Convert to seconds only at the Qt
  Multimedia boundary and format it only for display.

## QML JavaScript

- Use `.pragma library` for stateless reusable modules. Functions must have one
  clear purpose and avoid hidden mutation.
- Treat values received from QML as untrusted. Validate strings, numeric
  finiteness, and bounds before returning a domain-relevant value.
- Throw only `Error` objects for exceptional programming failures. Represent
  expected parse failure with `null` or another explicit result value.

## CXX-Qt and C++

- Keep bridge signatures small and Qt-compatible. Convert paths and user input
  immediately, validate through inward Rust APIs, and preserve stable error
  codes at the boundary.
- Document every public Rust item and every non-obvious bridge contract. Bridge
  comments follow `comment-content-rule.md`; generated-code mechanics do not
  need narration.
- Handwritten C++ uses C++17 or later, RAII ownership, `nullptr`, scoped enums,
  and Qt value types at the boundary only. No raw owning pointer or unchecked
  cast is permitted.
- Every Rust `unsafe` block follows `rust-style.md`. An `unsafe extern` bridge
  declaration is limited to the generated interop contract and must not become
  a route for framework types into the application layer.

## Errors and concurrency

- Expose stable error codes separately from diagnostic text. QML localizes the
  code; structured Rust logs retain the complete cause.
- A background operation owns its cancellation handle and reports exactly one
  terminal event. Closing the UI requests cancellation and waits for that event.
- Progress displayed in QML must already be monotonic and throttled by the
  application layer; QML must not repair backend ordering.

## Testing and verification

- Run `qmllint` for every production and test QML file and `qmlformat --check`
  for QML and QML JavaScript sources.
- Put pure QML/JavaScript behavior tests under `qml/tests/` and run them with
  `qmltestrunner` using the repository import paths.
- Test the controller mapping and worker lifecycle with Rust fakes. GUI smoke
  tests verify actual file dialogs, drag/drop, preview fallback, timeline input,
  conversion controls, overwrite confirmation, cancellation, and close safety.
- Build scripts and packaging tests must reject absolute Qt SDK, Homebrew,
  repository, or media-build paths from distributable binaries.
