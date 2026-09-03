import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediaforge/src/conversion_controller.dart';
import 'package:mediaforge/src/conversion_service.dart';
import 'package:mediaforge/src/file_selection.dart';
import 'package:mediaforge/src/media_metadata.dart';
import 'package:mediaforge/src/media_probe_service.dart';
import 'package:mediaforge/src/window_close_coordinator.dart';

void main() {
  test('functional controller enables every Rust-authoritative mode', () async {
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

    expect(controller.availableModes, MediaOutputMode.values);
    expect(controller.outputPath, '/tmp/source.mp4');
    expect(controller.canStart, isTrue);
    controller.selectMode(MediaOutputMode.audioOnly);
    expect(controller.mode, MediaOutputMode.audioOnly);
    controller.selectMode(MediaOutputMode.videoWithAudio);
    await _drainEvents();

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

  test('video-only source selects its sole authoritative mode', () async {
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

    expect(controller.availableModes, const <MediaOutputMode>[
      MediaOutputMode.videoOnly,
    ]);
    expect(controller.mode, MediaOutputMode.videoOnly);
    expect(controller.canStart, isTrue);
    expect(controller.failure, isNull);
    expect(conversionService.requests, isEmpty);
  });

  test('audio-only source selects its sole authoritative mode', () async {
    final conversionService = _FakeConversionService();
    final controller = ConversionController(
      service: conversionService,
      outputPathService: _FakeProbeService('/tmp/source.mp3'),
    );
    addTearDown(() async {
      await controller.close();
      controller.dispose();
      await conversionService.close();
    });
    controller.setMedia(
      MediaMetadata(
        path: '/tmp/audio.m4a',
        fileName: 'audio.m4a',
        fileSizeBytes: 1,
        durationMs: 2000,
        format: 'mov',
        video: null,
        audio: _media().audio,
        availableOutputModes: const <MediaOutputMode>[
          MediaOutputMode.audioOnly,
        ],
      ),
    );
    await _drainEvents();

    expect(controller.availableModes, const <MediaOutputMode>[
      MediaOutputMode.audioOnly,
    ]);
    expect(controller.mode, MediaOutputMode.audioOnly);
    expect(controller.canStart, isTrue);
    expect(controller.outputPath, '/tmp/source.mp3');
  });

  test('audio quality reaches the request and locks while active', () async {
    final conversionService = _FakeConversionService();
    final controller = ConversionController(
      service: conversionService,
      outputPathService: _FakeProbeService('/tmp/source.mp3'),
    );
    addTearDown(() async {
      await controller.close();
      controller.dispose();
      await conversionService.close();
    });
    controller.setMedia(_media());
    controller.selectMode(MediaOutputMode.audioOnly);
    controller.selectAudioQuality(ConversionAudioQuality.high);
    await _drainEvents();

    await controller.start(startMs: 0, endMs: 2000);
    final request = conversionService.requests.single;
    expect(request.mode, MediaOutputMode.audioOnly);
    expect(request.audioQuality, ConversionAudioQuality.high);
    controller.selectAudioQuality(ConversionAudioQuality.low);
    expect(controller.audioQuality, ConversionAudioQuality.high);

    conversionService.emit(
      const ConversionJobEvent(
        kind: ConversionJobEventKind.cancelled,
        jobId: 7,
      ),
    );
    await _drainEvents();
  });

  test('destination directory and filename remain mode-safe', () async {
    final conversionService = _FakeConversionService();
    final controller = ConversionController(
      service: conversionService,
      outputPathService: const _ModeProbeService(),
      directoryPicker: const PrototypeFileSelection(
        sourcePath: null,
        directoryPath: '/exports',
      ),
    );
    addTearDown(() async {
      await controller.close();
      controller.dispose();
      await conversionService.close();
    });
    controller.setMedia(_media());
    await _drainEvents();

    expect(controller.outputDirectory, '/tmp');
    expect(controller.outputFileName, 'source.mp4');
    expect(await controller.chooseOutputDirectory(), isTrue);
    expect(controller.outputPath, '/exports/source.mp4');

    controller.setOutputFileName('../source.mp4');
    expect(
      controller.destinationError,
      DestinationValidationError.pathSeparator,
    );
    expect(controller.canStart, isFalse);
    controller.setOutputFileName('source.mp3');
    expect(
      controller.destinationError,
      DestinationValidationError.wrongExtension,
    );
    controller.setOutputFileName('custom');
    expect(controller.destinationError, isNull);
    expect(controller.outputPath, '/exports/custom.mp4');
    controller.setOutputFileName('custom.mp4');
    expect(controller.outputPath, '/exports/custom.mp4');

    controller.selectMode(MediaOutputMode.audioOnly);
    await _drainEvents();
    expect(controller.outputDirectory, '/exports');
    expect(controller.outputFileName, 'source.mp3');
    expect(controller.outputPath, '/exports/source.mp3');
    controller.setOutputFileName('audio');
    expect(controller.destinationError, isNull);
    expect(controller.outputPath, '/exports/audio.mp3');
  });

  test(
    'existing output retries only after explicit overwrite approval',
    () async {
      final conversionService = _FakeConversionService(
        startFailures: <ConversionFailure>[
          const ConversionFailure(
            code: ConversionErrorCode.outputExists,
            diagnostic: 'destination already exists',
          ),
        ],
      );
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

      await controller.start(startMs: 100, endMs: 1200);
      expect(controller.overwriteConfirmationRequired, isTrue);
      expect(conversionService.requests.single.overwrite, isFalse);

      await controller.confirmOverwrite();
      expect(controller.overwriteConfirmationRequired, isFalse);
      expect(conversionService.requests.last.overwrite, isTrue);
      expect(conversionService.requests.last.startMs, 100);
      expect(conversionService.requests.last.endMs, 1200);
      conversionService.emit(
        const ConversionJobEvent(
          kind: ConversionJobEventKind.completed,
          jobId: 7,
          outputPath: '/tmp/source.mp4',
        ),
      );
      await _drainEvents();
    },
  );

  test(
    'new audiovisual source restores its authoritative default mode',
    () async {
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
      controller.selectMode(MediaOutputMode.audioOnly);
      controller.selectAudioQuality(ConversionAudioQuality.high);
      await _drainEvents();

      controller.setMedia(_media());
      await _drainEvents();

      expect(controller.mode, MediaOutputMode.videoWithAudio);
      expect(controller.audioQuality, ConversionAudioQuality.high);
    },
  );

  test('progress remains monotonic and preserves backend telemetry', () async {
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
    await controller.start(startMs: 200, endMs: 1200);

    conversionService.emit(
      const ConversionJobEvent(
        kind: ConversionJobEventKind.progress,
        jobId: 7,
        percent: 40,
        processedMs: 400,
        totalMs: 1000,
        framesPerSecond: 58.25,
        speed: 2.4,
      ),
    );
    conversionService.emit(
      const ConversionJobEvent(
        kind: ConversionJobEventKind.progress,
        jobId: 7,
        percent: 30,
        processedMs: 300,
        totalMs: 1000,
        framesPerSecond: 57,
        speed: 2.2,
      ),
    );
    await _drainEvents();

    expect(controller.progress, 0.4);
    expect(controller.processedMs, 400);
    expect(controller.totalMs, 1000);
    expect(controller.framesPerSecond, 57);
    expect(controller.speed, 2.2);
    expect(controller.jobState, ConversionJobState.running);

    conversionService.emit(
      const ConversionJobEvent(
        kind: ConversionJobEventKind.completed,
        jobId: 7,
        outputPath: '/tmp/source.mp4',
      ),
    );
    await _drainEvents();
  });

  test(
    'early cancellation waits for job identity and terminal cleanup',
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
      final cancelled = controller.cancelAndWaitForTerminal();
      expect(controller.cancelling, isTrue);
      expect(conversionService.cancelledJobIds, isEmpty);

      conversionService.completeStart();
      await start;
      expect(conversionService.cancelledJobIds, <int>[7]);
      var reachedTerminal = false;
      unawaited(cancelled.then((_) => reachedTerminal = true));
      await _drainEvents();
      expect(reachedTerminal, isFalse);

      conversionService.emit(
        const ConversionJobEvent(
          kind: ConversionJobEventKind.cancelled,
          jobId: 7,
        ),
      );
      await cancelled;
      expect(controller.converting, isFalse);
      expect(controller.jobState, ConversionJobState.cancelled);
      expect(controller.failure, isNull);
    },
  );

  test('repeated cancellation sends one native request', () async {
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

    await controller.cancel();
    await controller.cancel();
    expect(conversionService.cancelledJobIds, <int>[7]);

    conversionService.emit(
      const ConversionJobEvent(
        kind: ConversionJobEventKind.cancelled,
        jobId: 7,
      ),
    );
    await _drainEvents();
  });

  test(
    'terminal race waits for the matching event after job not found',
    () async {
      final conversionService = _FakeConversionService(
        cancelFailure: const ConversionFailure(
          code: ConversionErrorCode.jobNotFound,
          diagnostic: 'job became terminal before cancellation acquired it',
        ),
      );
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

      final cancelled = controller.cancelAndWaitForTerminal();
      await _drainEvents();
      expect(controller.converting, isTrue);
      expect(controller.failure, isNull);

      conversionService.emit(
        const ConversionJobEvent(
          kind: ConversionJobEventKind.completed,
          jobId: 7,
          outputPath: '/tmp/source.mp4',
        ),
      );
      await cancelled;
      expect(controller.jobState, ConversionJobState.completed);
    },
  );

  test(
    'window close destroys only after cancellation becomes terminal',
    () async {
      final conversionService = _FakeConversionService();
      final controller = ConversionController(
        service: conversionService,
        outputPathService: _FakeProbeService('/tmp/source.mp4'),
      );
      final window = _FakeWindowClosePort();
      final coordinator = ConversionWindowCloseCoordinator(controller, window);
      addTearDown(() async {
        await controller.close();
        controller.dispose();
        await conversionService.close();
      });
      controller.setMedia(_media());
      await _drainEvents();
      await controller.start(startMs: 0, endMs: 2000);
      await coordinator.attach();

      final close = coordinator.requestClose();
      await _drainEvents();
      expect(conversionService.cancelledJobIds, <int>[7]);
      expect(window.destroyCount, 0);

      conversionService.emit(
        const ConversionJobEvent(
          kind: ConversionJobEventKind.cancelled,
          jobId: 7,
        ),
      );
      await close;
      expect(window.destroyCount, 1);
      expect(window.onClose, isNull);
      await coordinator.requestClose();
      expect(window.destroyCount, 1);
    },
  );

  test(
    'dispose suppresses notifications while native cleanup finishes',
    () async {
      final conversionService = _FakeConversionService();
      final controller = ConversionController(
        service: conversionService,
        outputPathService: _FakeProbeService('/tmp/source.mp4'),
      );
      controller.setMedia(_media());
      await _drainEvents();
      await controller.start(startMs: 0, endMs: 2000);

      controller.dispose();
      await _drainEvents();
      expect(conversionService.cancelledJobIds, <int>[7]);

      conversionService.emit(
        const ConversionJobEvent(
          kind: ConversionJobEventKind.cancelled,
          jobId: 7,
        ),
      );
      await _drainEvents();
      await controller.close();
      await conversionService.close();
    },
  );
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
  _FakeConversionService({
    this.delayStart = false,
    this.cancelFailure,
    List<ConversionFailure>? startFailures,
  }) : startFailures = <ConversionFailure>[...?startFailures];

  final bool delayStart;
  final ConversionFailure? cancelFailure;
  final List<ConversionFailure> startFailures;
  final StreamController<ConversionJobEvent> _events =
      StreamController<ConversionJobEvent>.broadcast();
  final List<ConversionRequest> requests = <ConversionRequest>[];
  final List<int> cancelledJobIds = <int>[];
  Completer<ConversionJobSnapshot>? _pendingStart;

  @override
  Stream<ConversionJobEvent> get jobEvents => _events.stream;

  @override
  Future<ConversionJobSnapshot> start(ConversionRequest request) {
    requests.add(request);
    if (startFailures.isNotEmpty) {
      return Future<ConversionJobSnapshot>.error(startFailures.removeAt(0));
    }
    if (delayStart) {
      return (_pendingStart ??= Completer<ConversionJobSnapshot>()).future;
    }
    return Future<ConversionJobSnapshot>.value(_snapshot);
  }

  @override
  Future<void> cancel(int jobId) async {
    cancelledJobIds.add(jobId);
    final failure = cancelFailure;
    if (failure != null) {
      throw failure;
    }
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

class _FakeWindowClosePort implements WindowClosePort {
  VoidCallback? onClose;
  int destroyCount = 0;

  @override
  Future<void> attach(VoidCallback onClose) async {
    this.onClose = onClose;
  }

  @override
  Future<void> detach() async {
    onClose = null;
  }

  @override
  Future<void> destroy() async {
    destroyCount += 1;
  }
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

class _ModeProbeService implements MediaProbeService {
  const _ModeProbeService();

  @override
  Future<String> defaultOutputPath(String path, MediaOutputMode mode) async =>
      mode == MediaOutputMode.audioOnly ? '/tmp/source.mp3' : '/tmp/source.mp4';

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
