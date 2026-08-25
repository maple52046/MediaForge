This local Flutter FFI plugin contains the FRB 2.12.0 Cargokit integration used
to compile `mediaforge-flutter-bridge` as part of each desktop runner build.

The `cargokit/` subtree is generated from the pinned FRB release and retained
verbatim except for MediaForge-owned plugin manifests and three narrow
compatibility changes: exact rustup toolchain names, Cargo package-to-native
library artifact normalization, and suppression of full build-environment
logging. The first two changes have focused tests in `build_tool/test/`.
Regenerate the subtree with the repository's pinned
`flutter_rust_bridge_codegen`, then reapply only these documented changes.

The macOS podspec also links and embeds the repository-built
`libmediaforge_*.dylib` set. Those libraries keep their `@rpath` identities so
the debug Flutter runner exercises the same adapter boundary that M11 will
package and verify for release.
