import 'package:flutter/foundation.dart';

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
