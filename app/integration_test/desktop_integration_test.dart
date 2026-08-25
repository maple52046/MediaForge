import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mediaforge/bridge/api/handshake.dart';
import 'package:mediaforge/src/bridge_runtime.dart';
import 'package:mediaforge/src/media_kit_preview.dart';
import 'package:mediaforge/src/mediaforge_app.dart';
import 'package:mediaforge/src/preview_controller.dart';
import 'package:mediaforge/src/prototype_state.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final bridgeRuntime = BridgeRuntime();

  setUpAll(bridgeRuntime.ensureInitialized);

  testWidgets('macOS runner exchanges structured Rust bridge values', (
    WidgetTester tester,
  ) async {
    final handshake = await negotiateBridge(
      request: const BridgeHandshakeRequest(
        clientName: '  MediaForge Flutter  ',
        protocolVersion: 1,
      ),
    );
    expect(handshake.clientName, 'MediaForge Flutter');
    expect(handshake.protocolVersion, 1);
    expect(handshake.bridgeVersion, '0.2.0');

    await expectLater(
      negotiateBridge(
        request: const BridgeHandshakeRequest(
          clientName: 'MediaForge Flutter',
          protocolVersion: 2,
        ),
      ),
      throwsA(
        isA<BridgeError>()
            .having(
              (BridgeError error) => error.code,
              'code',
              BridgeErrorCode.unsupportedProtocol,
            )
            .having(
              (BridgeError error) => error.diagnostic,
              'diagnostic',
              contains('expected 1'),
            ),
      ),
    );
  });

  testWidgets('macOS runner receives an ordered terminal Rust stream', (
    WidgetTester tester,
  ) async {
    final events = await bridgeEventStream(seed: 41).toList();
    expect(events.map((BridgeEvent event) => event.kind), <BridgeEventKind>[
      BridgeEventKind.ready,
      BridgeEventKind.sample,
      BridgeEventKind.sample,
      BridgeEventKind.finished,
    ]);
    expect(events[0].protocolVersion, 1);
    expect(events[1].sequence, 0);
    expect(events[1].value, 41);
    expect(events[2].sequence, 1);
    expect(events[2].value, 42);
    expect(events[3].sampleCount, 2);
  });

  testWidgets('FRB process initialization is idempotent', (
    WidgetTester tester,
  ) async {
    await bridgeRuntime.ensureInitialized();
    await bridgeRuntime.ensureInitialized();
  });

  testWidgets('macOS desktop opens and closes settings', (
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

  testWidgets('macOS workspace composes native preview at desktop size', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 780);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final session = MediaKitPreviewSession(
      source: 'asset:///test/fixtures/preview-hevc.mp4',
    );
    addTearDown(session.preview.close);

    await tester.pumpWidget(
      MediaForgePrototypeApp(
        state: PrototypeState.loaded,
        previewController: session.preview,
        previewSurface: MediaKitVideoSurface(controller: session.video),
      ),
    );
    await _waitForNativeState(
      tester,
      () => find.byKey(const Key('native-preview-video')).evaluate().isNotEmpty,
    );

    expect(find.byKey(const Key('preview-fallback')), findsNothing);
    expect(find.byKey(const Key('conversion-pane')), findsOneWidget);
    expect(find.byType(Scrollable), findsNothing);
    expect(tester.takeException(), isNull);
  });

  const previewFixtures = <({String name, String source, bool portrait})>[
    (
      name: 'H.264/AAC',
      source: 'asset:///test/fixtures/preview-h264.mp4',
      portrait: false,
    ),
    (
      name: 'HEVC/AAC',
      source: 'asset:///test/fixtures/preview-hevc.mp4',
      portrait: false,
    ),
    (
      name: 'portrait HEVC/AAC',
      source: 'asset:///test/fixtures/preview-portrait-hevc.mp4',
      portrait: true,
    ),
  ];

  for (final fixture in previewFixtures) {
    testWidgets('macOS media_kit previews ${fixture.name}', (
      WidgetTester tester,
    ) async {
      final session = MediaKitPreviewSession(source: fixture.source);
      addTearDown(session.preview.close);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 640,
            height: 480,
            child: MediaKitVideoSurface(controller: session.video),
          ),
        ),
      );
      await session.preview.initialized;
      await _waitForNativeState(
        tester,
        () =>
            session.preview.availability == PreviewAvailability.ready &&
            session.preview.durationMs > 0 &&
            session.video.player.state.width != null &&
            session.video.player.state.height != null,
      );

      final video = tester.widget<Video>(
        find.byKey(const Key('native-preview-video')),
      );
      expect(video.fit, BoxFit.contain);
      final width = session.video.player.state.width!;
      final height = session.video.player.state.height!;
      expect(height > width, fixture.portrait);

      session.preview.togglePlayback();
      await _waitForNativeState(tester, () => session.preview.playing);
      session.preview.seek(600);
      await _waitForNativeState(
        tester,
        () => session.preview.positionMs >= 500,
      );
      session.preview.setVolume(42);
      await _waitForNativeState(
        tester,
        () => session.preview.volumePercent == 42,
      );
      session.preview.togglePlayback();
      await _waitForNativeState(tester, () => !session.preview.playing);
    });
  }
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

Future<void> _waitForNativeState(
  WidgetTester tester,
  bool Function() predicate,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for native preview state.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();
  }
}
