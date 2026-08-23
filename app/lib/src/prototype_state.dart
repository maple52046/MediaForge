/// Static visual states used by the M1 screenshot gate.
enum PrototypeState {
  /// A probed source is ready for conversion.
  loaded,

  /// No source has been selected.
  empty,

  /// A conversion is in progress.
  converting;

  /// Maps an external state name to a safe visual default.
  static PrototypeState fromName(String name) {
    return switch (name) {
      'empty' => PrototypeState.empty,
      'converting' => PrototypeState.converting,
      _ => PrototypeState.loaded,
    };
  }
}
