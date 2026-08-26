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
