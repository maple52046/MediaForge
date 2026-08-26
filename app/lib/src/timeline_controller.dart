import 'package:flutter/foundation.dart';

import 'media_time.dart';

/// Owns one source's trim range and independent preview playhead in milliseconds.
class TimelineController extends ChangeNotifier {
  /// Creates a validated timeline state.
  TimelineController({
    int durationMs = 3856,
    int startMs = 250,
    int endMs = 3606,
    int playheadMs = 842,
  }) : _durationMs = durationMs,
       _startMs = startMs,
       _endMs = endMs,
       _playheadMs = playheadMs {
    if (durationMs <= 0 ||
        startMs < 0 ||
        startMs >= endMs ||
        endMs > durationMs ||
        playheadMs < 0 ||
        playheadMs > durationMs) {
      throw ArgumentError('The timeline range is invalid.');
    }
  }

  int _durationMs;

  int _startMs;
  int _endMs;
  int _playheadMs;

  /// Duration reported by Rust metadata for the committed source.
  int get durationMs => _durationMs;

  /// Inclusive trim start in milliseconds.
  int get startMs => _startMs;

  /// Exclusive trim end in milliseconds.
  int get endMs => _endMs;

  /// Current preview position across the complete source.
  int get playheadMs => _playheadMs;

  /// Selected duration in milliseconds.
  int get selectedDurationMs => _endMs - _startMs;

  /// Replaces source duration and resets trim and preview state to its origin.
  void replaceSourceDuration(int valueMs) {
    if (valueMs <= 0) {
      throw ArgumentError.value(valueMs, 'valueMs', 'must be positive');
    }
    _durationMs = valueMs;
    _startMs = 0;
    _endMs = valueMs;
    _playheadMs = 0;
    notifyListeners();
  }

  /// Moves the start handle without allowing an empty selection.
  void setStart(int valueMs) {
    final next = valueMs.clamp(0, _endMs - 1);
    if (_startMs == next) {
      return;
    }
    _startMs = next;
    notifyListeners();
  }

  /// Moves the end handle without allowing an empty selection.
  void setEnd(int valueMs) {
    final next = valueMs.clamp(_startMs + 1, _durationMs);
    if (_endMs == next) {
      return;
    }
    _endMs = next;
    notifyListeners();
  }

  /// Moves the independent preview playhead across the complete source.
  void setPlayhead(int valueMs) {
    final next = valueMs.clamp(0, _durationMs);
    if (_playheadMs == next) {
      return;
    }
    _playheadMs = next;
    notifyListeners();
  }

  /// Parses and commits a start value, returning its bounded result when valid.
  int? commitStartText(String value) {
    final parsed = parseMediaTime(value);
    if (parsed == null) {
      return null;
    }
    setStart(parsed);
    return _startMs;
  }

  /// Parses and commits an end value, returning its bounded result when valid.
  int? commitEndText(String value) {
    final parsed = parseMediaTime(value);
    if (parsed == null) {
      return null;
    }
    setEnd(parsed);
    return _endMs;
  }

  /// Sets the start handle to the current playhead within legal trim bounds.
  void setStartFromPlayhead() => setStart(_playheadMs);

  /// Sets the end handle to the current playhead within legal trim bounds.
  void setEndFromPlayhead() => setEnd(_playheadMs);

  /// Restores the complete source range and seeks presentation state to zero.
  void reset() {
    if (_startMs == 0 && _endMs == _durationMs && _playheadMs == 0) {
      return;
    }
    _startMs = 0;
    _endMs = _durationMs;
    _playheadMs = 0;
    notifyListeners();
  }
}
