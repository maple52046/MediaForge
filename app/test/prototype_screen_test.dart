import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediaforge/src/mediaforge_app.dart';
import 'package:mediaforge/src/mf_icon.dart';
import 'package:mediaforge/src/mf_timeline.dart';
import 'package:mediaforge/src/preview_controller.dart';
import 'package:mediaforge/src/prototype_state.dart';

void main() {
  const supportedSizes = <Size>[
    Size(1040, 680),
    Size(1200, 780),
    Size(1440, 900),
  ];

  for (final size in supportedSizes) {
    for (final state in PrototypeState.values) {
      testWidgets(
        '${state.name} fits ${size.width.toInt()}×${size.height.toInt()}',
        (WidgetTester tester) async {
          await _setSurfaceSize(tester, size);
          await tester.pumpWidget(MediaForgePrototypeApp(state: state));
          await tester.pumpAndSettle();

          expect(find.byKey(const Key('app-header')), findsOneWidget);
          expect(tester.takeException(), isNull);
          _expectNoWorkspaceScrollable(tester);
        },
      );
    }
  }

  testWidgets('minimum size fits settings and drop overlays', (
    WidgetTester tester,
  ) async {
    await _setSurfaceSize(tester, supportedSizes.first);
    await tester.pumpWidget(
      const MediaForgePrototypeApp(
        state: PrototypeState.loaded,
        showDropOverlay: true,
        showSettingsPopover: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-popover')), findsOneWidget);
    expect(find.byKey(const Key('drop-overlay')), findsOneWidget);
    expect(tester.takeException(), isNull);
    _expectNoWorkspaceScrollable(tester);
  });

  testWidgets('settings popover responds to choices and close', (
    WidgetTester tester,
  ) async {
    await _setSurfaceSize(tester, const Size(1200, 780));
    await tester.pumpWidget(
      const MediaForgePrototypeApp(state: PrototypeState.loaded),
    );

    await tester.tap(find.byKey(const Key('settings-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-popover')), findsOneWidget);

    await tester.tap(find.byKey(const Key('theme-dark')));
    await tester.tap(find.byKey(const Key('language-traditionalChinese')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('close-settings')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-popover')), findsNothing);
  });

  testWidgets('output segmentation updates fake presentation values', (
    WidgetTester tester,
  ) async {
    await _setSurfaceSize(tester, const Size(1200, 780));
    await tester.pumpWidget(
      const MediaForgePrototypeApp(state: PrototypeState.loaded),
    );

    await tester.tap(find.byKey(const Key('mode-audioOnly')));
    await tester.pumpAndSettle();
    expect(find.text('MP3'), findsOneWidget);
    expect(find.text('MP3 · 192 kbps'), findsOneWidget);
    expect(find.text('Convert audio'), findsOneWidget);
    expect(find.text('ScreenRecording_08-13-2026.mp3'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mode-videoOnly')));
    await tester.pumpAndSettle();
    expect(find.text('None'), findsOneWidget);
    expect(find.text('Convert video'), findsOneWidget);
  });

  testWidgets('fake conversion starts, reports progress, and cancels', (
    WidgetTester tester,
  ) async {
    await _setSurfaceSize(tester, const Size(1200, 780));
    await tester.pumpWidget(
      const MediaForgePrototypeApp(state: PrototypeState.loaded),
    );

    await tester.tap(find.byKey(const Key('start-conversion')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cancel-conversion')), findsOneWidget);
    expect(find.text('8%'), findsOneWidget);
    expect(find.byKey(const Key('start-conversion')), findsNothing);

    await tester.tap(find.byKey(const Key('cancel-conversion')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('start-conversion')), findsOneWidget);
    expect(find.byKey(const Key('cancel-conversion')), findsNothing);
  });

  testWidgets('source replacement overlay supports cancel and commit', (
    WidgetTester tester,
  ) async {
    await _setSurfaceSize(tester, const Size(1200, 780));
    await tester.pumpWidget(
      const MediaForgePrototypeApp(state: PrototypeState.loaded),
    );

    await tester.tap(find.byKey(const Key('replace-source')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('drop-overlay')), findsOneWidget);
    expect(find.text('Drop to replace the current source'), findsOneWidget);

    await tester.tap(find.byKey(const Key('cancel-drop')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('drop-overlay')), findsNothing);

    await tester.tap(find.byKey(const Key('replace-source')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('accept-drop')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('conversion-pane')), findsOneWidget);
    expect(find.byKey(const Key('drop-overlay')), findsNothing);
  });

  testWidgets('empty session commits fake media through the drop overlay', (
    WidgetTester tester,
  ) async {
    await _setSurfaceSize(tester, const Size(1040, 680));
    await tester.pumpWidget(
      const MediaForgePrototypeApp(state: PrototypeState.empty),
    );

    await tester.tap(find.byKey(const Key('open-media')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('drop-overlay')), findsOneWidget);

    await tester.tap(find.byKey(const Key('accept-drop')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('empty-drop-zone')), findsNothing);
    expect(find.byKey(const Key('conversion-pane')), findsOneWidget);
  });

  testWidgets('preview play controls expose pressed state changes', (
    WidgetTester tester,
  ) async {
    await _setSurfaceSize(tester, const Size(1200, 780));
    await tester.pumpWidget(
      const MediaForgePrototypeApp(state: PrototypeState.loaded),
    );

    MfIcon icon = tester.widget<MfIcon>(
      find.descendant(
        of: find.byKey(const Key('preview-play')),
        matching: find.byType(MfIcon),
      ),
    );
    expect(icon.icon, MfIconData.play);

    await tester.tap(find.byKey(const Key('preview-play')));
    await tester.pumpAndSettle();
    icon = tester.widget<MfIcon>(
      find.descendant(
        of: find.byKey(const Key('preview-play')),
        matching: find.byType(MfIcon),
      ),
    );
    expect(icon.icon, MfIconData.pause);
  });

  testWidgets('timeline input and preview position stay synchronized', (
    WidgetTester tester,
  ) async {
    await _setSurfaceSize(tester, const Size(1200, 780));
    final preview = _TrackingPreviewController();
    await tester.pumpWidget(
      MediaForgePrototypeApp(
        state: PrototypeState.loaded,
        previewController: preview,
      ),
    );

    preview.emitPosition(1700);
    await tester.pump();
    expect(tester.widget<MfTimeline>(find.byType(MfTimeline)).playheadMs, 1700);

    final startInput = find.descendant(
      of: find.byKey(const Key('start-time-input')),
      matching: find.byType(EditableText),
    );
    await tester.enterText(startInput, '00:00:01.200');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(preview.seekCommands.last, 1200);
    expect(tester.widget<MfTimeline>(find.byType(MfTimeline)).startMs, 1200);

    await tester.enterText(startInput, '00:60:00');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(tester.widget<EditableText>(startInput).controller.text, '00:60:00');
    expect(preview.seekCommands.last, 1200);
    await tester.tap(find.text('Trim range'));
    await tester.pump();
    expect(
      tester.widget<EditableText>(startInput).controller.text,
      '00:00:01.200',
    );

    await tester.tap(find.byKey(const Key('play-selection')));
    expect(preview.selectionCommands.last, (1200, 3606));

    await tester.tap(find.byKey(const Key('reset-trim')));
    await tester.pump();
    expect(preview.seekCommands.last, 0);
    expect(tester.widget<MfTimeline>(find.byType(MfTimeline)).startMs, 0);
    expect(tester.widget<MfTimeline>(find.byType(MfTimeline)).endMs, 3856);
  });

  testWidgets('preview failure degrades without hiding conversion', (
    WidgetTester tester,
  ) async {
    await _setSurfaceSize(tester, const Size(1200, 780));
    await tester.pumpWidget(
      MediaForgePrototypeApp(
        state: PrototypeState.loaded,
        previewController: _UnavailablePreviewController(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('preview-fallback')), findsOneWidget);
    expect(find.text('Preview unavailable'), findsWidgets);
    expect(
      find.text('Conversion remains available for this source.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('preview-center-play')), findsNothing);
    expect(find.byKey(const Key('start-conversion')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('converting initial state exposes cancellation', (
    WidgetTester tester,
  ) async {
    await _setSurfaceSize(tester, const Size(1200, 780));
    await tester.pumpWidget(
      const MediaForgePrototypeApp(state: PrototypeState.converting),
    );

    expect(find.text('62%'), findsOneWidget);
    expect(find.byKey(const Key('cancel-conversion')), findsOneWidget);
    expect(find.byKey(const Key('start-conversion')), findsNothing);
    expect(find.byKey(const Key('replace-source')), findsNothing);
    expect(find.text('Source locked'), findsOneWidget);
  });
}

Future<void> _setSurfaceSize(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void _expectNoWorkspaceScrollable(WidgetTester tester) {
  for (final element in find.byType(Scrollable).evaluate()) {
    final renderObject = element.renderObject;
    if (renderObject is RenderBox) {
      expect(renderObject.size.height, lessThan(100));
    }
  }
}

class _UnavailablePreviewController extends PreviewController {
  @override
  PreviewAvailability get availability => PreviewAvailability.unavailable;

  @override
  String? get diagnostic => 'Synthetic preview failure';

  @override
  int get durationMs => 3856;

  @override
  bool get playing => false;

  @override
  int get positionMs => 0;

  @override
  int get volumePercent => 78;

  @override
  void playSelection(int startMs, int endMs) {}

  @override
  void seek(int positionMs) {}

  @override
  void setVolume(int volumePercent) {}

  @override
  void togglePlayback() {}
}

class _TrackingPreviewController extends PreviewController {
  int _positionMs = 842;
  bool _playing = false;
  final List<int> seekCommands = <int>[];
  final List<(int, int)> selectionCommands = <(int, int)>[];

  @override
  PreviewAvailability get availability => PreviewAvailability.placeholder;

  @override
  String? get diagnostic => null;

  @override
  int get durationMs => 3856;

  @override
  bool get playing => _playing;

  @override
  int get positionMs => _positionMs;

  @override
  int get volumePercent => 78;

  void emitPosition(int valueMs) {
    _positionMs = valueMs;
    notifyListeners();
  }

  @override
  void playSelection(int startMs, int endMs) {
    selectionCommands.add((startMs, endMs));
    _positionMs = startMs;
    _playing = true;
    notifyListeners();
  }

  @override
  void seek(int positionMs) {
    seekCommands.add(positionMs);
    _positionMs = positionMs;
    notifyListeners();
  }

  @override
  void setVolume(int volumePercent) {}

  @override
  void togglePlayback() {
    _playing = !_playing;
    notifyListeners();
  }
}
