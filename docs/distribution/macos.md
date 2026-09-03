# macOS distribution

## Unsigned v0.2.0 artifacts

`bash scripts/bundle-flutter-macos.sh` builds LGPL conversion dependencies from
the pinned FFmpeg submodule and checksummed LAME source, creates the Flutter
release application, bundles its FRB/Cargokit and media_kit/libmpv runtimes,
and produces Apple Silicon app and DMG artifacts under
`target/release/bundle/`. The verifier rejects Flutter SDK, Qt SDK, Homebrew,
`/usr/local`, workspace, or project-local dynamic-library references. The
deployment target is macOS 13.

Before publishing, copy `THIRD_PARTY_NOTICES.md` and the generated dependency
license directory alongside the downloadable artifacts. Retain the repository
gitlink and exact LAME source archive named in the notices, or keep their
upstream URLs available for the required source-offer period.

Unsigned downloads are expected to trigger Gatekeeper. For local testing,
control-click the app and choose Open. Do not tell users to disable Gatekeeper
globally.

## Clean-machine verification

Use an Apple Silicon macOS 13+ Mac without a Flutter or Qt SDK, Homebrew FFmpeg,
or LAME. Install from the DMG, open through the documented unsigned-app flow,
and exercise probe, preview, trim, all applicable output modes, overwrite
confirmation, language/theme persistence, and cancellation. Confirm that
cancelled jobs leave neither destination nor `.part` files.

Run `otool -L` against the app executable and every library in
`Contents/Frameworks`; media dependencies must resolve through `@rpath` and
system libraries must resolve through `/System/Library` or `/usr/lib`.

The direct-download build intentionally does not enable App Sandbox. Selecting
one source file grants a sandboxed process access to that file but not permission
to create MediaForge's atomic temporary output beside it. Native dialogs still
scope user interaction, while the unsandboxed process preserves the documented
default of writing the completed conversion next to the source.

## Signing and notarization follow-up

When Apple Developer credentials become available, enable hardened runtime,
sign nested dylibs, Flutter/plugin frameworks, and resource bundles before the
app container, then notarize the DMG with `notarytool` and staple the accepted
ticket. Credentials and private keys must remain outside the repository.
