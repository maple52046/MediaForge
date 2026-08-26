import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mediaforge/src/conversion_controller.dart';
import 'package:mediaforge/src/conversion_service.dart';
import 'package:mediaforge/src/media_metadata.dart';
import 'package:mediaforge/src/media_probe_service.dart';

void main() {
  test('functional controller enables only primary Video + Audio', () async {
    final conversionService = _FakeConversionService();
    final pathService = _FakeProbeService('/tmp/source.mp4');
    final controller = ConversionController(
      service: conversionService,
      outputPathService: pathService,
    );
    addTearDown(() async {
      await controller.close();
      controller.dispose();
      await conversionService.close();
    });

    controller.setMedia(_media());
    await _drainEvents();

    expect(controller.availableModes, const <MediaOutputMode>[
      MediaOutputMode.videoWithAudio,
    ]);
    expect(controller.outputPath, '/tmp/source.mp4');
    expect(controller.canStart, isTrue);
    controller.selectMode(MediaOutputMode.audioOnly);
    expect(controller.mode, MediaOutputMode.videoWithAudio);

    await controller.start(startMs: 200, endMs: 1200);
    final request = conversionService.requests.single;
    expect(request.inputPath, '/tmp/source.mov');
    expect(request.outputPath, '/tmp/source.mp4');
    expect(request.mode, MediaOutputMode.videoWithAudio);
    expect(request.startMs, 200);
    expect(request.endMs, 1200);
    expect(request.overwrite, isFalse);
    expect(controller.converting, isTrue);

    conversionService.emit(
      const ConversionJobEvent(
        kind: ConversionJobEventKind.completed,
        jobId: 7,
        outputPath: '/tmp/source.mp4',
      ),
    );
    await _drainEvents();
    expect(controller.converting, isFalse);
    expect(controller.completedOutputPath, '/tmp/source.mp4');
    expect(controller.failure, isNull);
  });

  test(
    'terminal event arriving before start response remains correlated',
    () async {
      final conversionService = _FakeConversionService(delayStart: true);
      final controller = ConversionController(
        service: conversionService,
        outputPathService: _FakeProbeService('/tmp/source.mp4'),
      );
      addTearDown(() async {
        await controller.close();
        controller.dispose();
        await conversionService.close();
      });
      controller.setMedia(_media());
      await _drainEvents();

      final start = controller.start(startMs: 0, endMs: 2000);
      await _drainEvents();
      conversionService.emit(
        const ConversionJobEvent(
          kind: ConversionJobEventKind.completed,
          jobId: 7,
          outputPath: '/tmp/source.mp4',
        ),
      );
      conversionService.completeStart();
      await start;
      await _drainEvents();

      expect(controller.converting, isFalse);
      expect(controller.completedOutputPath, '/tmp/source.mp4');
    },
  );

  test('structured failure unlocks the controller for retry', () async {
    final conversionService = _FakeConversionService();
    final controller = ConversionController(
      service: conversionService,
      outputPathService: _FakeProbeService('/tmp/source.mp4'),
    );
    addTearDown(() async {
      await controller.close();
      controller.dispose();
      await conversionService.close();
    });
    controller.setMedia(_media());
    await _drainEvents();
    await controller.start(startMs: 0, endMs: 2000);

    conversionService.emit(
      const ConversionJobEvent(
        kind: ConversionJobEventKind.failed,
        jobId: 7,
        failure: ConversionFailure(
          code: ConversionErrorCode.encoderUnavailable,
          diagnostic: 'h264_videotoolbox',
        ),
      ),
    );
    await _drainEvents();

    expect(controller.converting, isFalse);
    expect(controller.failure?.code, ConversionErrorCode.encoderUnavailable);
    expect(controller.canStart, isTrue);
  });

  test('source without both streams cannot start the M7 workflow', () async {
    final conversionService = _FakeConversionService();
    final controller = ConversionController(
      service: conversionService,
      outputPathService: _FakeProbeService('/tmp/source.mp4'),
    );
    addTearDown(() async {
      await controller.close();
      controller.dispose();
      await conversionService.close();
    });
    controller.setMedia(
      MediaMetadata(
        path: '/tmp/video.mov',
        fileName: 'video.mov',
        fileSizeBytes: 1,
        durationMs: 2000,
        format: 'mov',
        video: _media().video,
        audio: null,
        availableOutputModes: const <MediaOutputMode>[
          MediaOutputMode.videoOnly,
        ],
      ),
    );
    await _drainEvents();

    expect(controller.availableModes, isEmpty);
    expect(controller.canStart, isFalse);
    expect(controller.failure?.code, ConversionErrorCode.unsupportedInput);
    expect(conversionService.requests, isEmpty);
  });
}

Future<void> _drainEvents() => Future<void>.delayed(Duration.zero);

MediaMetadata _media() {
  return const MediaMetadata(
    path: '/tmp/source.mov',
    fileName: 'source.mov',
    fileSizeBytes: 1024,
    durationMs: 2000,
    format: 'mov',
    video: VideoMetadata(
      codec: 'h264',
      width: 320,
      height: 180,
      frameRate: 24,
      bitrate: 1000000,
      pixelFormat: 'yuv420p',
    ),
    audio: AudioMetadata(
      codec: 'aac',
      sampleRate: 48000,
      channels: 1,
      bitrate: 128000,
    ),
    availableOutputModes: <MediaOutputMode>[
      MediaOutputMode.videoWithAudio,
      MediaOutputMode.videoOnly,
      MediaOutputMode.audioOnly,
    ],
  );
}

class _FakeConversionService implements ConversionService {
  _FakeConversionService({this.delayStart = false});

  final bool delayStart;
  final StreamController<ConversionJobEvent> _events =
      StreamController<ConversionJobEvent>.broadcast();
  final List<ConversionRequest> requests = <ConversionRequest>[];
  Completer<ConversionJobSnapshot>? _pendingStart;

  @override
  Stream<ConversionJobEvent> get jobEvents => _events.stream;

  @override
  Future<ConversionJobSnapshot> start(ConversionRequest request) {
    requests.add(request);
    if (delayStart) {
      return (_pendingStart ??= Completer<ConversionJobSnapshot>()).future;
    }
    return Future<ConversionJobSnapshot>.value(_snapshot);
  }

  void emit(ConversionJobEvent event) => _events.add(event);

  void completeStart() => _pendingStart?.complete(_snapshot);

  Future<void> close() => _events.close();

  static const _snapshot = ConversionJobSnapshot(
    jobId: 7,
    state: ConversionJobState.preparing,
    inputPath: '/tmp/source.mov',
    outputPath: '/tmp/source.mp4',
  );
}

class _FakeProbeService implements MediaProbeService {
  const _FakeProbeService(this.outputPath);

  final String outputPath;

  @override
  Future<String> defaultOutputPath(String path, MediaOutputMode mode) async =>
      outputPath;

  @override
  Future<MediaBackendCapabilities> initializeBackend() async {
    return const MediaBackendCapabilities(
      ffmpegVersion: 'fake',
      h264Available: true,
      aacAvailable: true,
      mp3Available: true,
    );
  }

  @override
  Future<MediaMetadata> probe(String path) async => _media();
}
