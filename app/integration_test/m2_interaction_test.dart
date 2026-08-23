import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mediaforge/src/mediaforge_app.dart';
import 'package:mediaforge/src/prototype_state.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('macOS runner opens and closes settings', (
    WidgetTester tester,
  ) async {
    await _mountLoadedPrototype(tester);

    await tester.tap(find.byKey(const Key('settings-button')));
    await _pumpPrototypeMotion(tester);
    expect(find.byKey(const Key('settings-popover')), findsOneWidget);

    await tester.tap(find.byKey(const Key('close-settings')));
    await _pumpPrototypeMotion(tester);
    expect(find.byKey(const Key('settings-popover')), findsNothing);
  });

  testWidgets('macOS runner changes the output mode', (
    WidgetTester tester,
  ) async {
    await _mountLoadedPrototype(tester);

    await tester.tap(find.byKey(const Key('mode-audioOnly')));
    await _pumpPrototypeMotion(tester);
    expect(find.text('Convert audio'), findsOneWidget);
  });

  testWidgets('macOS runner starts and cancels fake conversion', (
    WidgetTester tester,
  ) async {
    await _mountLoadedPrototype(tester);

    await tester.tap(find.byKey(const Key('start-conversion')));
    await _pumpPrototypeMotion(tester);
    expect(find.byKey(const Key('cancel-conversion')), findsOneWidget);

    await tester.tap(find.byKey(const Key('cancel-conversion')));
    await _pumpPrototypeMotion(tester);
    expect(find.byKey(const Key('start-conversion')), findsOneWidget);
  });

  testWidgets('macOS runner replaces the fake source', (
    WidgetTester tester,
  ) async {
    await _mountLoadedPrototype(tester);

    await tester.tap(find.byKey(const Key('replace-source')));
    await _pumpPrototypeMotion(tester);
    expect(find.byKey(const Key('drop-overlay')), findsOneWidget);

    await tester.tap(find.byKey(const Key('accept-drop')));
    await _pumpPrototypeMotion(tester);
    expect(find.byKey(const Key('conversion-pane')), findsOneWidget);
  });
}

Future<void> _mountLoadedPrototype(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1200, 780);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    const MediaForgePrototypeApp(state: PrototypeState.loaded),
  );
  await _pumpPrototypeMotion(tester);
}

Future<void> _pumpPrototypeMotion(WidgetTester tester) async {
  // Contract: M2 motion tokens complete within 180 ms.
  await tester.pump(const Duration(milliseconds: 250));
}
