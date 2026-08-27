import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mediaforge/bridge/api/handshake.dart';
import 'package:mediaforge/bridge/api/media.dart' as bridge;
import 'package:mediaforge/src/bridge_runtime.dart';
import 'package:mediaforge/src/conversion_service.dart';
import 'package:mediaforge/src/media_kit_preview.dart';
import 'package:mediaforge/src/media_probe_service.dart';
import 'package:mediaforge/src/mediaforge_app.dart';
import 'package:mediaforge/src/mf_timeline.dart';
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

  testWidgets('macOS runner probes media through repository FFmpeg libraries', (
    WidgetTester tester,
  ) async {
    final fixture = _bundledProbeFixture();
    expect(fixture.existsSync(), isTrue);

    final capabilities = await bridge.initializeBackend();
    expect(capabilities.ffmpegVersion, isNotEmpty);
    expect(capabilities.h264Available, isTrue);
    expect(capabilities.aacAvailable, isTrue);
    expect(capabilities.mp3Available, isTrue);

    final bridge.MediaInfoDto media;
    try {
      media = await bridge.probeMedia(path: fixture.path);
    } on bridge.MediaBridgeError catch (error) {
      fail('${error.code.name}: ${error.diagnostic}');
    }
    expect(media.path, fixture.resolveSymbolicLinksSync());
    expect(media.fileName, 'preview-hevc.mp4');
    expect(media.durationMs, greaterThan(0));
    expect(media.video?.codec, 'hevc');
    expect(media.audio?.codec, 'aac');
    expect(media.availableOutputModes, <bridge.MediaOutputMode>[
      bridge.MediaOutputMode.videoWithAudio,
      bridge.MediaOutputMode.videoOnly,
      bridge.MediaOutputMode.audioOnly,
    ]);
    expect(
      await bridge.defaultOutputPath(
        path: media.path,
        mode: bridge.MediaOutputMode.audioOnly,
      ),
      endsWith('preview-hevc.mp3'),
    );
    expect(
      await bridge.defaultOutputPath(
        path: media.path,
        mode: bridge.MediaOutputMode.videoWithAudio,
      ),
      endsWith('preview-hevc-converted.mp4'),
    );

    await expectLater(
      bridge.probeMedia(path: '${fixture.path}.missing'),
      throwsA(
        isA<bridge.MediaBridgeError>().having(
          (bridge.MediaBridgeError error) => error.code,
          'code',
          bridge.MediaBridgeErrorCode.cannotOpenInput,
        ),
      ),
    );
  });

  testWidgets('successful Rust probe composes committed native preview', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 780);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final fixture = _bundledProbeFixture();

    await tester.pumpWidget(
      MediaForgePrototypeApp(
        state: PrototypeState.empty,
        previewSource: fixture.path,
        mediaProbeService: const RustMediaProbeService(),
        conversionService: const RustConversionService(),
      ),
    );
    await _waitForNativeState(
      tester,
      () =>
          find.byKey(const Key('conversion-pane')).evaluate().isNotEmpty &&
          find.byKey(const Key('native-preview-video')).evaluate().isNotEmpty,
    );

    expect(find.text('preview-hevc.mp4'), findsOneWidget);
    expect(find.byKey(const Key('preview-fallback')), findsNothing);
    final timeline = tester.widget<MfTimeline>(find.byType(MfTimeline));
    expect(timeline.durationMs, 2000);
    expect(timeline.startMs, 0);
    expect(timeline.endMs, 2000);
    expect(tester.takeException(), isNull);
  });

  testWidgets('macOS runner completes primary Rust conversion with trim', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 780);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'mediaforge-m7-',
    );
    final input = File('${temporaryDirectory.path}/primary.mov');
    final output = File('${temporaryDirectory.path}/primary.mp4');
    await _bundledFixture('preview-h264.mp4').copy(input.path);

    try {
      await tester.pumpWidget(
        MediaForgePrototypeApp(
          state: PrototypeState.empty,
          previewSource: input.path,
          mediaProbeService: const RustMediaProbeService(),
          conversionService: const RustConversionService(),
        ),
      );
      await _waitForNativeState(
        tester,
        () =>
            find.text('primary.mp4').evaluate().isNotEmpty &&
            find.byKey(const Key('start-conversion')).evaluate().isNotEmpty,
      );
      expect(find.byKey(const Key('mode-videoWithAudio')), findsOneWidget);
      expect(find.byKey(const Key('mode-videoOnly')), findsNothing);
      expect(find.byKey(const Key('mode-audioOnly')), findsNothing);

      final startInput = find.descendant(
        of: find.byKey(const Key('start-time-input')),
        matching: find.byType(EditableText),
      );
      final endInput = find.descendant(
        of: find.byKey(const Key('end-time-input')),
        matching: find.byType(EditableText),
      );
      await tester.enterText(startInput, '00:00:00.200');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.enterText(endInput, '00:00:01.200');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      await tester.tap(find.byKey(const Key('start-conversion')));
      await _waitForNativeState(
        tester,
        () =>
            find.byKey(const Key('conversion-completed')).evaluate().isNotEmpty,
        timeout: const Duration(seconds: 20),
      );

      expect(await output.exists(), isTrue);
      final outputInfo = await bridge.probeMedia(path: output.path);
      expect(outputInfo.video, isNotNull);
      expect(outputInfo.audio, isNotNull);
      expect(outputInfo.durationMs, inInclusiveRange(900, 1300));
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
    }
  });

  testWidgets(
    'macOS runner cancels Rust conversion and removes partial output',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 780);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final temporaryDirectory = await Directory.systemTemp.createTemp(
        'mediaforge-m8-',
      );
      final input = File('${temporaryDirectory.path}/cancellation.mov');
      final output = File('${temporaryDirectory.path}/cancellation.mp4');
      await _bundledFixture('cancellation-h264.mp4').copy(input.path);

      try {
        await tester.pumpWidget(
          MediaForgePrototypeApp(
            state: PrototypeState.empty,
            previewSource: input.path,
            mediaProbeService: const RustMediaProbeService(),
            conversionService: const RustConversionService(),
          ),
        );
        await _waitForNativeState(
          tester,
          () => find.byKey(const Key('start-conversion')).evaluate().isNotEmpty,
        );

        await tester.tap(find.byKey(const Key('start-conversion')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('cancel-conversion')));
        await _waitForNativeState(
          tester,
          () => find
              .byKey(const Key('conversion-cancelled'))
              .evaluate()
              .isNotEmpty,
          timeout: const Duration(seconds: 20),
        );

        expect(await output.exists(), isFalse);
        final partials = await temporaryDirectory
            .list()
            .where(
              (FileSystemEntity entity) => entity.path.contains('.mediaforge-'),
            )
            .toList();
        expect(partials, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (await temporaryDirectory.exists()) {
          await temporaryDirectory.delete(recursive: true);
        }
      }
    },
  );

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
    _expectNoWorkspaceScrollable(tester);
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

      session.preview.playSelection(200, 500);
      await _waitForNativeState(tester, () => session.preview.playing);
      await _waitForNativeState(
        tester,
        () => !session.preview.playing && session.preview.positionMs == 500,
      );
    });
  }
}

File _bundledProbeFixture() {
  return _bundledFixture('preview-hevc.mp4');
}

File _bundledFixture(String name) {
  final contentsDirectory = File(Platform.resolvedExecutable).parent.parent;
  return File(
    '${contentsDirectory.path}/Frameworks/App.framework/Versions/A/Resources/'
    'flutter_assets/test/fixtures/$name',
  );
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

void _expectNoWorkspaceScrollable(WidgetTester tester) {
  for (final element in find.byType(Scrollable).evaluate()) {
    final renderObject = element.renderObject;
    if (renderObject is RenderBox) {
      expect(renderObject.size.height, lessThan(100));
    }
  }
}

Future<void> _waitForNativeState(
  WidgetTester tester,
  bool Function() predicate, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for native preview state.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();
  }
}
