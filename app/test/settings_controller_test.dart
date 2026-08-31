import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mediaforge/src/settings_controller.dart';

void main() {
  test('stored preferences load and override platform defaults', () async {
    final controller = SettingsController(
      store: MemorySettingsStore(<String, String>{
        'mediaforge.theme': 'light',
        'mediaforge.language': 'english',
      }),
      systemLocales: const <Locale>[Locale('zh', 'TW')],
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.theme, MfThemePreference.light);
    expect(controller.language, MfLanguagePreference.english);
    expect(controller.effectiveLanguage, MfLanguage.english);
    expect(controller.effectiveBrightness(Brightness.dark), Brightness.light);
  });

  test('system language supports Chinese and falls back to English', () {
    final chinese = SettingsController(
      store: MemorySettingsStore(),
      systemLocales: const <Locale>[Locale('zh', 'TW')],
    );
    final unsupported = SettingsController(
      store: MemorySettingsStore(),
      systemLocales: const <Locale>[Locale('ja', 'JP')],
    );
    addTearDown(chinese.dispose);
    addTearDown(unsupported.dispose);

    expect(chinese.effectiveLanguage, MfLanguage.traditionalChinese);
    expect(unsupported.effectiveLanguage, MfLanguage.english);
  });

  test('late storage load cannot overwrite an explicit selection', () async {
    final store = _DelayedSettingsStore();
    final controller = SettingsController(
      store: store,
      systemLocales: const <Locale>[Locale('en', 'US')],
    );
    addTearDown(controller.dispose);

    final load = controller.load();
    await controller.selectTheme(MfThemePreference.dark);
    store.completeReads(theme: 'light', language: 'traditionalChinese');
    await load;

    expect(controller.theme, MfThemePreference.dark);
    expect(controller.language, MfLanguagePreference.system);
  });
}

class _DelayedSettingsStore implements SettingsStore {
  final Map<String, Completer<String?>> _reads = <String, Completer<String?>>{};

  @override
  Future<String?> getString(String key) =>
      (_reads[key] ??= Completer<String?>()).future;

  @override
  Future<void> setString(String key, String value) async {}

  void completeReads({required String theme, required String language}) {
    _reads['mediaforge.theme']!.complete(theme);
    _reads['mediaforge.language']!.complete(language);
  }
}
