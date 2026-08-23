import 'package:flutter_test/flutter_test.dart';
import 'package:mediaforge/src/prototype_controllers.dart';

void main() {
  test('media session commits and cancels fake drop replacement', () {
    final controller = MediaSessionPrototypeController(initialHasMedia: false);
    addTearDown(controller.dispose);

    controller.showDropOverlay();
    expect(controller.dropOverlayVisible, isTrue);
    controller.hideDropOverlay();
    expect(controller.dropOverlayVisible, isFalse);
    expect(controller.hasMedia, isFalse);

    controller.showDropOverlay();
    controller.commitFakeSource();
    expect(controller.hasMedia, isTrue);
    expect(controller.dropOverlayVisible, isFalse);
  });

  test('timeline preserves a non-empty bounded integer-ms range', () {
    final controller = TimelinePrototypeController();
    addTearDown(controller.dispose);

    controller.setStart(4000);
    expect(controller.startMs, controller.endMs - 1);
    expect(controller.playheadMs, controller.startMs);

    controller.setEnd(-1);
    expect(controller.endMs, controller.startMs + 1);
    controller.setPlayhead(-500);
    expect(controller.playheadMs, controller.startMs);

    controller.reset();
    expect(controller.startMs, 0);
    expect(controller.endMs, controller.durationMs);
    expect(controller.playheadMs, 0);
  });

  test('timeline rejects invalid initial state', () {
    expect(
      () => TimelinePrototypeController(startMs: 800, endMs: 400),
      throwsArgumentError,
    );
    expect(
      () => TimelinePrototypeController(playheadMs: 3800, endMs: 3600),
      throwsArgumentError,
    );
  });

  test('conversion locks mode while active and supports cancellation', () {
    final controller = ConversionPrototypeController();
    addTearDown(controller.dispose);

    controller.selectMode(PrototypeOutputMode.audioOnly);
    expect(controller.mode, PrototypeOutputMode.audioOnly);
    controller.start();
    expect(controller.converting, isTrue);
    expect(controller.progress, 0.08);

    controller.selectMode(PrototypeOutputMode.videoOnly);
    expect(controller.mode, PrototypeOutputMode.audioOnly);
    controller.cancel();
    expect(controller.converting, isFalse);
    expect(controller.progress, 0);
  });

  test('settings popover and choices remain focused presentation state', () {
    final controller = SettingsPrototypeController();
    addTearDown(controller.dispose);

    controller.togglePopover();
    controller.selectTheme(PrototypeThemePreference.dark);
    controller.selectLanguage(PrototypeLanguagePreference.traditionalChinese);

    expect(controller.popoverOpen, isTrue);
    expect(controller.theme, PrototypeThemePreference.dark);
    expect(controller.language, PrototypeLanguagePreference.traditionalChinese);
    controller.closePopover();
    expect(controller.popoverOpen, isFalse);
  });
}
