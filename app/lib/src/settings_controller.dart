import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted appearance choices owned by the Flutter presentation.
enum MfThemePreference {
  /// Follow the operating-system appearance.
  system,

  /// Always use the light palette.
  light,

  /// Always use the dark palette.
  dark,
}

/// Persisted language choices owned by the Flutter presentation.
enum MfLanguagePreference {
  /// Follow the operating-system language with English fallback.
  system,

  /// Use Traditional Chinese.
  traditionalChinese,

  /// Use English.
  english,
}

/// Languages supported by the MediaForge Flutter shell.
enum MfLanguage {
  /// Traditional Chinese.
  traditionalChinese,

  /// English.
  english,
}

/// Minimal asynchronous preference boundary consumed by settings state.
abstract interface class SettingsStore {
  /// Reads a string or returns `null` when the key is absent.
  Future<String?> getString(String key);

  /// Persists one string value.
  Future<void> setString(String key, String value);
}

/// SharedPreferencesAsync adapter for process-independent settings persistence.
class SharedPreferencesSettingsStore implements SettingsStore {
  /// Creates an adapter around a fresh asynchronous preferences client.
  SharedPreferencesSettingsStore() : _preferences = SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> getString(String key) => _preferences.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      _preferences.setString(key, value);
}

/// Owns settings popover state, platform fallback, and persisted preferences.
class SettingsController extends ChangeNotifier {
  /// Creates settings state around a persistence boundary and platform locales.
  factory SettingsController({
    required SettingsStore store,
    required List<Locale> systemLocales,
    bool initiallyOpen = false,
  }) => SettingsController._(
    store,
    List<Locale>.unmodifiable(systemLocales),
    initiallyOpen,
  );

  SettingsController._(this._store, this._systemLocales, this._popoverOpen);

  static const _themeKey = 'mediaforge.theme';
  static const _languageKey = 'mediaforge.language';

  final SettingsStore _store;
  final List<Locale> _systemLocales;
  bool _popoverOpen;
  MfThemePreference _theme = MfThemePreference.system;
  MfLanguagePreference _language = MfLanguagePreference.system;
  String? _persistenceDiagnostic;
  int _selectionGeneration = 0;
  bool _disposed = false;

  /// Whether the settings popover is visible.
  bool get popoverOpen => _popoverOpen;

  /// Selected appearance preference.
  MfThemePreference get theme => _theme;

  /// Selected language preference.
  MfLanguagePreference get language => _language;

  /// Latest non-fatal storage diagnostic, if persistence failed.
  String? get persistenceDiagnostic => _persistenceDiagnostic;

  /// Resolves the selected language against the initial platform locale list.
  MfLanguage get effectiveLanguage => switch (_language) {
    MfLanguagePreference.traditionalChinese => MfLanguage.traditionalChinese,
    MfLanguagePreference.english => MfLanguage.english,
    MfLanguagePreference.system => _systemLanguage(_systemLocales),
  };

  /// Resolves the selected appearance against the current platform brightness.
  Brightness effectiveBrightness(Brightness platformBrightness) =>
      switch (_theme) {
        MfThemePreference.system => platformBrightness,
        MfThemePreference.light => Brightness.light,
        MfThemePreference.dark => Brightness.dark,
      };

  /// Loads stored values without overwriting choices made while loading.
  Future<void> load() async {
    final generation = _selectionGeneration;
    try {
      final values = await Future.wait<String?>([
        _store.getString(_themeKey),
        _store.getString(_languageKey),
      ]);
      if (_disposed || generation != _selectionGeneration) {
        return;
      }
      _theme = _parseTheme(values[0]);
      _language = _parseLanguage(values[1]);
      _persistenceDiagnostic = null;
      notifyListeners();
    } on Object catch (error) {
      if (_disposed || generation != _selectionGeneration) {
        return;
      }
      _persistenceDiagnostic = error.toString();
      notifyListeners();
    }
  }

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

  /// Applies and persists one appearance choice.
  Future<void> selectTheme(MfThemePreference theme) async {
    if (_theme == theme) {
      return;
    }
    _selectionGeneration += 1;
    _theme = theme;
    _persistenceDiagnostic = null;
    notifyListeners();
    await _persist(_themeKey, theme.name);
  }

  /// Applies and persists one language choice.
  Future<void> selectLanguage(MfLanguagePreference language) async {
    if (_language == language) {
      return;
    }
    _selectionGeneration += 1;
    _language = language;
    _persistenceDiagnostic = null;
    notifyListeners();
    await _persist(_languageKey, language.name);
  }

  Future<void> _persist(String key, String value) async {
    try {
      await _store.setString(key, value);
    } on Object catch (error) {
      if (_disposed) {
        return;
      }
      _persistenceDiagnostic = error.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  static MfThemePreference _parseTheme(String? value) =>
      MfThemePreference.values
          .where((item) => item.name == value)
          .firstOrNull ??
      MfThemePreference.system;

  static MfLanguagePreference _parseLanguage(String? value) =>
      MfLanguagePreference.values
          .where((item) => item.name == value)
          .firstOrNull ??
      MfLanguagePreference.system;

  static MfLanguage _systemLanguage(List<Locale> locales) {
    final locale = locales.firstOrNull;
    if (locale == null || locale.languageCode.toLowerCase() != 'zh') {
      return MfLanguage.english;
    }
    return MfLanguage.traditionalChinese;
  }
}

/// Volatile settings storage for tests and screenshot prototypes.
class MemorySettingsStore implements SettingsStore {
  /// Creates storage initialized from [values].
  MemorySettingsStore([Map<String, String>? values])
    : values = <String, String>{...?values};

  /// Mutable values retained for the lifetime of this adapter.
  final Map<String, String> values;

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}
