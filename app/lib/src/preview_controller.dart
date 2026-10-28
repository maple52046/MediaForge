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

/// Linear preview gain envelope expressed on the source timeline.
class PreviewAudioFadeEnvelope {
  /// Creates one trim-relative envelope with non-overlapping source spans.
  const PreviewAudioFadeEnvelope({
    required this.startMs,
    required this.endMs,
    required this.fadeInSourceMs,
    required this.fadeOutSourceMs,
  });

  /// Inclusive selected-source boundary.
  final int startMs;

  /// Exclusive selected-source boundary.
  final int endMs;

  /// Source-timeline span occupied by fade-in.
  final int fadeInSourceMs;

  /// Source-timeline span occupied by fade-out.
  final int fadeOutSourceMs;

  /// Returns linear gain for [positionMs], restoring full gain outside trim.
  double gainAt(int positionMs) {
    if (positionMs < startMs || positionMs >= endMs) {
      return 1;
    }
    var gain = 1.0;
    if (fadeInSourceMs > 0 && positionMs < startMs + fadeInSourceMs) {
      gain = (positionMs - startMs) / fadeInSourceMs;
    }
    if (fadeOutSourceMs > 0 && positionMs > endMs - fadeOutSourceMs) {
      final fadeOutGain = (endMs - positionMs) / fadeOutSourceMs;
      if (fadeOutGain < gain) {
        gain = fadeOutGain;
      }
    }
    return gain.clamp(0, 1);
  }

  @override
  bool operator ==(Object other) =>
      other is PreviewAudioFadeEnvelope &&
      startMs == other.startMs &&
      endMs == other.endMs &&
      fadeInSourceMs == other.fadeInSourceMs &&
      fadeOutSourceMs == other.fadeOutSourceMs;

  @override
  int get hashCode =>
      Object.hash(startMs, endMs, fadeInSourceMs, fadeOutSourceMs);
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

  /// Current source playback-rate multiplier.
  double get playbackRate;

  /// Diagnostic detail retained for logs when preview is unavailable.
  String? get diagnostic;

  /// Toggles playback when the preview is available.
  void togglePlayback();

  /// Plays a non-empty selection and pauses when preview reaches its end.
  void playSelection(int startMs, int endMs);

  /// Seeks to a bounded integer-millisecond position.
  void seek(int positionMs);

  /// Sets preview volume after constraining it to a percentage.
  void setVolume(int volumePercent);

  /// Applies a positive playback-rate multiplier without changing position.
  void setPlaybackRate(double rate);

  /// Applies or clears a trim-relative audio fade without changing playback.
  void setAudioFadeEnvelope(PreviewAudioFadeEnvelope? envelope);
}
