import 'preview_controller.dart';

/// Owns deterministic preview values without loading a native player.
class PreviewPrototypeController extends PreviewController {
  bool _playing = false;
  int _positionMs = 842;
  int _volumePercent = 78;
  int? _selectionEndMs;

  @override
  PreviewAvailability get availability => PreviewAvailability.placeholder;

  @override
  String? get diagnostic => null;

  @override
  int get durationMs => 3856;

  /// Whether the fake preview is playing.
  @override
  bool get playing => _playing;

  /// Current fake preview position in integer milliseconds.
  @override
  int get positionMs => _positionMs;

  /// Current fake preview volume from zero through one hundred.
  @override
  int get volumePercent => _volumePercent;

  /// Toggles fake preview playback.
  @override
  void togglePlayback() {
    _selectionEndMs = null;
    _playing = !_playing;
    notifyListeners();
  }

  /// Starts fake playback at the selected trim boundary.
  @override
  void playSelection(int startMs, int endMs) {
    final start = startMs.clamp(0, durationMs);
    final end = endMs.clamp(0, durationMs);
    if (start >= end) {
      return;
    }
    _positionMs = start;
    _selectionEndMs = end;
    _playing = true;
    notifyListeners();
  }

  /// Moves the fake preview to a timeline position.
  @override
  void seek(int positionMs) {
    final next = positionMs.clamp(0, durationMs);
    _selectionEndMs = null;
    if (_positionMs == next) {
      return;
    }
    _positionMs = next;
    notifyListeners();
  }

  /// Advances deterministic playback and enforces a pending selection boundary.
  void updatePlaybackPosition(int positionMs) {
    final next = positionMs.clamp(0, durationMs);
    final selectionEnd = _selectionEndMs;
    if (selectionEnd != null && next >= selectionEnd) {
      _positionMs = selectionEnd;
      _selectionEndMs = null;
      _playing = false;
    } else {
      _positionMs = next;
    }
    notifyListeners();
  }

  /// Updates fake preview volume while keeping it in the valid percentage range.
  @override
  void setVolume(int volumePercent) {
    final next = volumePercent.clamp(0, 100);
    if (_volumePercent == next) {
      return;
    }
    _volumePercent = next;
    notifyListeners();
  }
}
