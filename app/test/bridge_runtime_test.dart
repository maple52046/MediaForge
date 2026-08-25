import 'package:flutter_test/flutter_test.dart';
import 'package:mediaforge/src/bridge_runtime.dart';

void main() {
  test('bridge runtime initializes the native process exactly once', () async {
    var calls = 0;
    final runtime = BridgeRuntime(
      initializeNative: () async {
        calls += 1;
      },
    );

    await Future.wait<void>([
      runtime.ensureInitialized(),
      runtime.ensureInitialized(),
    ]);
    await runtime.ensureInitialized();
    expect(calls, 1);
  });

  test('bridge runtime retains the first initialization failure', () async {
    var calls = 0;
    final failure = StateError('native bridge unavailable');
    final runtime = BridgeRuntime(
      initializeNative: () async {
        calls += 1;
        throw failure;
      },
    );

    await expectLater(runtime.ensureInitialized(), throwsA(same(failure)));
    await expectLater(runtime.ensureInitialized(), throwsA(same(failure)));
    expect(calls, 1);
  });
}
