import 'dart:async';

import 'package:flutter/foundation.dart';

import 'media_metadata.dart';
import 'preview_controller.dart';

/// Theme choices displayed by the fake settings popover.
enum PrototypeThemePreference {
  /// Follow the operating-system appearance.
  system,

  /// Request the future light theme.
  light,

  /// Use the current dark prototype theme.
  dark,
}

/// Language choices displayed by the fake settings popover.
enum PrototypeLanguagePreference {
  /// Follow the operating-system language.
  system,

  /// Use Traditional Chinese.
  traditionalChinese,

  /// Use English.
  english,
}

/// Owns deterministic preview values without loading a native player.
class PreviewPrototypeController extends PreviewController {
  bool _playing = false;
  int _positionMs = 842;
  int _volumePercent = 78;

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
    _playing = !_playing;
    notifyListeners();
  }

  /// Starts fake playback at the selected trim boundary.
  @override
  void playSelection(int startMs) {
    _positionMs = startMs;
    _playing = true;
    notifyListeners();
  }

  /// Moves the fake preview to a timeline position.
  @override
  void seek(int positionMs) {
    if (_positionMs == positionMs) {
      return;
    }
    _positionMs = positionMs;
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

/// Owns the M2 trim range and playhead as integer milliseconds.
class TimelinePrototypeController extends ChangeNotifier {
  /// Creates a validated fake timeline range.
  TimelinePrototypeController({
    this.durationMs = 3856,
    int startMs = 250,
    int endMs = 3606,
    int playheadMs = 842,
  }) : _startMs = startMs,
       _endMs = endMs,
       _playheadMs = playheadMs {
    if (durationMs <= 0 ||
        startMs < 0 ||
        startMs >= endMs ||
        endMs > durationMs ||
        playheadMs < startMs ||
        playheadMs > endMs) {
      throw ArgumentError('The prototype timeline range is invalid.');
    }
  }

  /// Duration of the fake source in milliseconds.
  final int durationMs;

  int _startMs;
  int _endMs;
  int _playheadMs;

  /// Inclusive trim start in milliseconds.
  int get startMs => _startMs;

  /// Prototype trim end boundary in milliseconds.
  int get endMs => _endMs;

  /// Current timeline playhead in milliseconds.
  int get playheadMs => _playheadMs;

  /// Selected duration in milliseconds.
  int get selectedDurationMs => _endMs - _startMs;

  /// Moves the start handle without allowing an empty selection.
  void setStart(int valueMs) {
    final next = valueMs.clamp(0, _endMs - 1);
    if (_startMs == next) {
      return;
    }
    _startMs = next;
    if (_playheadMs < next) {
      _playheadMs = next;
    }
    notifyListeners();
  }

  /// Moves the end handle without allowing an empty selection.
  void setEnd(int valueMs) {
    final next = valueMs.clamp(_startMs + 1, durationMs);
    if (_endMs == next) {
      return;
    }
    _endMs = next;
    if (_playheadMs > next) {
      _playheadMs = next;
    }
    notifyListeners();
  }

  /// Moves the playhead inside the current selection.
  void setPlayhead(int valueMs) {
    final next = valueMs.clamp(_startMs, _endMs);
    if (_playheadMs == next) {
      return;
    }
    _playheadMs = next;
    notifyListeners();
  }

  /// Sets the start handle to the current playhead.
  void setStartFromPlayhead() => setStart(_playheadMs);

  /// Sets the end handle to the current playhead.
  void setEndFromPlayhead() => setEnd(_playheadMs);

  /// Restores the complete fake source range.
  void reset() {
    if (_startMs == 0 && _endMs == durationMs && _playheadMs == 0) {
      return;
    }
    _startMs = 0;
    _endMs = durationMs;
    _playheadMs = 0;
    notifyListeners();
  }
}

/// Owns fake output selection, progress, and cancellation state.
class ConversionPrototypeController extends ChangeNotifier {
  /// Creates deterministic conversion state for the M2 prototype.
  ConversionPrototypeController({
    bool initiallyConverting = false,
    this.autoAdvanceProgress = false,
  }) : _converting = initiallyConverting,
       _progress = initiallyConverting ? 0.62 : 0 {
    if (_converting) {
      _startProgressTimer();
    }
  }

  /// Whether the prototype advances progress on a presentation-only timer.
  final bool autoAdvanceProgress;
  Timer? _progressTimer;
  List<MediaOutputMode> _availableModes = MediaOutputMode.values;
  MediaOutputMode _mode = MediaOutputMode.videoWithAudio;
  bool _converting;
  double _progress;

  /// Selected fake output mode.
  MediaOutputMode get mode => _mode;

  /// Rust-authoritative recipes available for the committed source.
  List<MediaOutputMode> get availableModes => _availableModes;

  /// Whether fake conversion is active.
  bool get converting => _converting;

  /// Fake conversion completion from zero through one.
  double get progress => _progress;

  /// Selects an output mode while conversion is idle.
  void selectMode(MediaOutputMode mode) {
    if (_converting || _mode == mode || !_availableModes.contains(mode)) {
      return;
    }
    _mode = mode;
    notifyListeners();
  }

  /// Replaces mode availability with the ordered recipes from Rust metadata.
  void setAvailableModes(List<MediaOutputMode> modes) {
    if (modes.isEmpty) {
      throw ArgumentError.value(modes, 'modes', 'must not be empty');
    }
    final next = List<MediaOutputMode>.unmodifiable(modes);
    final nextMode = next.contains(_mode) ? _mode : next.first;
    if (listEquals(_availableModes, next) && _mode == nextMode) {
      return;
    }
    _availableModes = next;
    _mode = nextMode;
    notifyListeners();
  }

  /// Starts the fake conversion and optional animated progress.
  void start() {
    if (_converting) {
      return;
    }
    _converting = true;
    _progress = 0.08;
    _startProgressTimer();
    notifyListeners();
  }

  /// Cancels fake conversion and returns to the ready state.
  void cancel() {
    if (!_converting) {
      return;
    }
    _progressTimer?.cancel();
    _progressTimer = null;
    _converting = false;
    _progress = 0;
    notifyListeners();
  }

  void _startProgressTimer() {
    if (!autoAdvanceProgress || _progressTimer != null) {
      return;
    }
    _progressTimer = Timer.periodic(const Duration(milliseconds: 180), (
      Timer timer,
    ) {
      if (!_converting) {
        timer.cancel();
        _progressTimer = null;
        return;
      }
      _progress = (_progress + 0.012).clamp(0, 0.96);
      if (_progress >= 0.96) {
        timer.cancel();
        _progressTimer = null;
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }
}

/// Owns fake popover, theme, and language choices for M2.
class SettingsPrototypeController extends ChangeNotifier {
  /// Creates deterministic settings-popover state.
  SettingsPrototypeController({bool initiallyOpen = false})
    : _popoverOpen = initiallyOpen;

  bool _popoverOpen;
  PrototypeThemePreference _theme = PrototypeThemePreference.system;
  PrototypeLanguagePreference _language = PrototypeLanguagePreference.system;

  /// Whether the settings popover is visible.
  bool get popoverOpen => _popoverOpen;

  /// Selected fake theme preference.
  PrototypeThemePreference get theme => _theme;

  /// Selected fake language preference.
  PrototypeLanguagePreference get language => _language;

  /// Toggles the settings popover.
  void togglePopover() {
    _popoverOpen = !_popoverOpen;
    notifyListeners();
  }

  /// Closes the settings popover when it is open.
  void closePopover() {
    if (!_popoverOpen) {
      return;
    }
    _popoverOpen = false;
    notifyListeners();
  }

  /// Selects a fake theme preference.
  void selectTheme(PrototypeThemePreference theme) {
    if (_theme == theme) {
      return;
    }
    _theme = theme;
    notifyListeners();
  }

  /// Selects a fake language preference.
  void selectLanguage(PrototypeLanguagePreference language) {
    if (_language == language) {
      return;
    }
    _language = language;
    notifyListeners();
  }
}
