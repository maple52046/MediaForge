import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediaforge/src/mediaforge_app.dart';
import 'package:mediaforge/src/mf_icon.dart';
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
          expect(find.byType(Scrollable), findsNothing);
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
    expect(find.byType(Scrollable), findsNothing);
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
