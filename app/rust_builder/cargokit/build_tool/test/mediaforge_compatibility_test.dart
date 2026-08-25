import 'package:build_tool/src/cargo.dart';
import 'package:build_tool/src/options.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('accepts the repository-pinned semver Rust toolchain', () {
    final options = CargoBuildOptions.parse(
      loadYamlNode('toolchain: "1.88.0"\nextra_flags: []'),
    );

    expect(options.toolchain, '1.88.0');
    expect(options.flags, isEmpty);
  });

  test('rejects an empty Rust toolchain', () {
    expect(
      () => CargoBuildOptions.parse(loadYamlNode('toolchain: ""')),
      throwsA(isA<SourceSpanException>()),
    );
  });

  test('normalizes Cargo package names only for native artifacts', () {
    final crate = CrateInfo.parseManifest('''
[package]
name = "mediaforge-flutter-bridge"
''');

    expect(crate.packageName, 'mediaforge-flutter-bridge');
    expect(crate.libraryName, 'mediaforge_flutter_bridge');
  });
}
