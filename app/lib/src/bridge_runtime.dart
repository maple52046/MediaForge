import '../bridge/frb_generated.dart';

/// Owns exactly-once initialization of the process-wide native Rust bridge.
class BridgeRuntime {
  /// Creates a runtime with an injectable native initializer for unit tests.
  BridgeRuntime({Future<void> Function()? initializeNative})
    : _initializeNative = initializeNative ?? MediaForgeRustLib.init;

  final Future<void> Function() _initializeNative;
  Future<void>? _initialization;

  /// Returns the same initialization result for every caller in this process.
  ///
  /// A failed native initialization is retained because FRB may have partially
  /// initialized process-global state and does not support an automatic retry.
  Future<void> ensureInitialized() => _initialization ??= _initializeNative();
}
