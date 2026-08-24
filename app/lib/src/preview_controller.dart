import 'package:flutter/foundation.dart';

/// Observable lifecycle states for the presentation-owned media preview.
enum PreviewAvailability {
  /// Deterministic visual content is standing in for a native player.
  placeholder,

  /// A native source is being opened.
  opening,

  /// The native source is available for playback and seeking.
  ready,

  /// Native preview failed without invalidating the conversion session.
  unavailable,
}

/// Presentation contract shared by fake and native preview controllers.
abstract class PreviewController extends ChangeNotifier {
  /// Current preview lifecycle state.
  PreviewAvailability get availability;

  /// Whether preview playback is active.
  bool get playing;

  /// Current preview position in integer milliseconds.
  int get positionMs;

  /// Current preview duration in integer milliseconds, or zero while unknown.
  int get durationMs;

  /// Current preview volume from zero through one hundred.
  int get volumePercent;

  /// Diagnostic detail retained for logs when preview is unavailable.
  String? get diagnostic;

  /// Toggles playback when the preview is available.
  void togglePlayback();

  /// Seeks to the selection start and begins playback.
  void playSelection(int startMs);

  /// Seeks to a bounded integer-millisecond position.
  void seek(int positionMs);

  /// Sets preview volume after constraining it to a percentage.
  void setVolume(int volumePercent);
}
