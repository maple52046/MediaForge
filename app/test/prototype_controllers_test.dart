import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mediaforge/src/media_metadata.dart';
import 'package:mediaforge/src/media_probe_service.dart';
import 'package:mediaforge/src/media_session_controller.dart';
import 'package:mediaforge/src/prototype_controllers.dart';

void main() {
  test('media session commits and cancels prototype replacement', () async {
    final controller = MediaSessionController.prototype(initialHasMedia: false);
    addTearDown(controller.dispose);

    controller.showDropOverlay();
    expect(controller.dropOverlayVisible, isTrue);
    controller.hideDropOverlay();
    expect(controller.dropOverlayVisible, isFalse);
    expect(controller.hasMedia, isFalse);

    controller.showDropOverlay();
    expect(await controller.probeCandidateSource(), isTrue);
    expect(controller.hasMedia, isTrue);
    expect(controller.dropOverlayVisible, isFalse);
  });

  test('failed replacement preserves committed metadata', () async {
    final service = _ControlledProbeService();
    final controller = MediaSessionController(
      probeService: service,
      initialMedia: _media('/old.mov'),
    );
    addTearDown(controller.dispose);
    service.failures['/invalid.mov'] = const MediaProbeFailure(
      code: MediaProbeErrorCode.unsupportedInput,
      diagnostic: 'missing streams',
    );

    expect(await controller.replaceSource('/invalid.mov'), isFalse);
    expect(controller.media?.path, '/old.mov');
    expect(controller.failure?.code, MediaProbeErrorCode.unsupportedInput);
  });

  test('superseded probe cannot overwrite the newest source', () async {
    final service = _ControlledProbeService();
    final first = Completer<MediaMetadata>();
    final second = Completer<MediaMetadata>();
    service.pending['/first.mov'] = first;
    service.pending['/second.mov'] = second;
    final controller = MediaSessionController(probeService: service);
    addTearDown(controller.dispose);

    final firstResult = controller.replaceSource('/first.mov');
    final secondResult = controller.replaceSource('/second.mov');
    second.complete(_media('/second.mov'));
    expect(await secondResult, isTrue);
    first.complete(_media('/first.mov'));
    expect(await firstResult, isFalse);
    expect(controller.media?.path, '/second.mov');
  });

  test(
    'changing the provisional path invalidates an in-flight probe',
    () async {
      final service = _ControlledProbeService();
      final first = Completer<MediaMetadata>();
      service.pending['/first.mov'] = first;
      final controller = MediaSessionController(
        probeService: service,
        initialMedia: _media('/committed.mov'),
      );
      addTearDown(controller.dispose);

      final firstResult = controller.replaceSource('/first.mov');
      controller.setCandidatePath('/second.mov');
      first.complete(_media('/first.mov'));

      expect(await firstResult, isFalse);
      expect(controller.media?.path, '/committed.mov');
      expect(controller.candidatePath, '/second.mov');
      expect(controller.probing, isFalse);
    },
  );

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

    controller.selectMode(MediaOutputMode.audioOnly);
    expect(controller.mode, MediaOutputMode.audioOnly);
    controller.start();
    expect(controller.converting, isTrue);
    expect(controller.progress, 0.08);

    controller.selectMode(MediaOutputMode.videoOnly);
    expect(controller.mode, MediaOutputMode.audioOnly);
    controller.cancel();
    expect(controller.converting, isFalse);
    expect(controller.progress, 0);
  });

  test('conversion exposes only Rust-authoritative output modes', () {
    final controller = ConversionPrototypeController();
    addTearDown(controller.dispose);

    controller.setAvailableModes(const <MediaOutputMode>[
      MediaOutputMode.audioOnly,
    ]);
    expect(controller.mode, MediaOutputMode.audioOnly);
    expect(controller.availableModes, const <MediaOutputMode>[
      MediaOutputMode.audioOnly,
    ]);
    controller.selectMode(MediaOutputMode.videoOnly);
    expect(controller.mode, MediaOutputMode.audioOnly);
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

MediaMetadata _media(String path) {
  return MediaMetadata(
    path: path,
    fileName: path.split('/').last,
    fileSizeBytes: 1024,
    durationMs: 1000,
    format: 'mov',
    video: const VideoMetadata(
      codec: 'h264',
      width: 320,
      height: 180,
      frameRate: 24,
      bitrate: 1000000,
      pixelFormat: 'yuv420p',
    ),
    audio: null,
    availableOutputModes: const <MediaOutputMode>[MediaOutputMode.videoOnly],
  );
}

class _ControlledProbeService implements MediaProbeService {
  final Map<String, Completer<MediaMetadata>> pending =
      <String, Completer<MediaMetadata>>{};
  final Map<String, MediaProbeFailure> failures = <String, MediaProbeFailure>{};

  @override
  Future<String> defaultOutputPath(String path, MediaOutputMode mode) async =>
      path;

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
  Future<MediaMetadata> probe(String path) async {
    final failure = failures[path];
    if (failure != null) {
      throw failure;
    }
    final completer = pending[path];
    if (completer != null) {
      return completer.future;
    }
    return _media(path);
  }
}
