import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mediaforge/src/media_kit_preview.dart';
import 'package:mediaforge/src/preview_controller.dart';

void main() {
  test('native preview maps playback state and bounded commands', () async {
    final driver = _FakePreviewPlaybackDriver();
    final preview = MediaKitPreviewController(
      driver: driver,
      source: 'asset:///test/fixtures/preview-hevc.mp4',
    );
    await preview.initialized;

    expect(preview.availability, PreviewAvailability.ready);
    expect(driver.openedSource, 'asset:///test/fixtures/preview-hevc.mp4');
    expect(driver.volumeCommands, <int>[78]);
    expect(driver.playbackRateCommands, <double>[1]);

    driver.durationController.add(2000);
    driver.positionController.add(625);
    driver.playingController.add(true);
    await _drainEvents();
    expect(preview.durationMs, 2000);
    expect(preview.positionMs, 625);
    expect(preview.playing, isTrue);
    expect(preview.volumePercent, 78);

    preview.togglePlayback();
    preview.seek(2500);
    preview.setVolume(150);
    preview.setPlaybackRate(1.25);
    await _drainEvents();
    expect(driver.pauseCount, 1);
    expect(driver.seekCommands, <int>[2000]);
    expect(driver.volumeCommands, <int>[78, 100]);
    expect(preview.playbackRate, 1.25);
    expect(driver.playbackRateCommands, <double>[1, 1.25]);
    expect(() => preview.setPlaybackRate(4.05), throwsArgumentError);

    driver.playingController.add(false);
    await _drainEvents();
    preview.playSelection(-30, 1000);
    await _drainEvents();
    expect(driver.seekCommands, <int>[2000, 0]);
    expect(driver.playCount, 1);

    await preview.close();
    await preview.close();
    expect(driver.closeCount, 1);
    preview.dispose();
  });

  test('native preview keeps open failures as degradable state', () async {
    final driver = _FakePreviewPlaybackDriver(
      openError: StateError('unsupported preview codec'),
    );
    final preview = MediaKitPreviewController(
      driver: driver,
      source: '/tmp/unsupported.mov',
    );
    await preview.initialized;

    expect(preview.availability, PreviewAvailability.unavailable);
    expect(preview.diagnostic, contains('unsupported preview codec'));
    expect(driver.openedSource, 'file:///tmp/unsupported.mov');

    preview.togglePlayback();
    preview.seek(100);
    preview.playSelection(100, 200);
    await _drainEvents();
    expect(driver.playCount, 0);
    expect(driver.seekCommands, isEmpty);

    await preview.close();
    preview.dispose();
  });

  test('audio fade preview composes with base volume inside trim', () async {
    final driver = _FakePreviewPlaybackDriver();
    final preview = MediaKitPreviewController(
      driver: driver,
      source: 'asset:///test/fixtures/preview-h264.mp4',
    );
    await preview.initialized;
    preview.setAudioFadeEnvelope(
      const PreviewAudioFadeEnvelope(
        startMs: 100,
        endMs: 1100,
        fadeInSourceMs: 200,
        fadeOutSourceMs: 200,
      ),
    );

    driver.positionController.add(100);
    await _drainEvents();
    expect(driver.volumeCommands.last, 0);
    driver.positionController.add(200);
    await _drainEvents();
    expect(driver.volumeCommands.last, 39);
    driver.positionController.add(500);
    await _drainEvents();
    expect(driver.volumeCommands.last, 78);
    driver.positionController.add(1000);
    await _drainEvents();
    expect(driver.volumeCommands.last, 39);

    preview.setVolume(50);
    await _drainEvents();
    expect(preview.volumePercent, 50);
    expect(driver.volumeCommands.last, 25);
    driver.positionController.add(1100);
    await _drainEvents();
    expect(driver.volumeCommands.last, 50);

    preview.setAudioFadeEnvelope(null);
    await _drainEvents();
    expect(preview.positionMs, 1100);
    expect(driver.volumeCommands.last, 50);

    await preview.close();
    preview.dispose();
  });

  test('native error stream moves a ready preview to fallback', () async {
    final driver = _FakePreviewPlaybackDriver();
    final preview = MediaKitPreviewController(
      driver: driver,
      source: 'asset:///test/fixtures/preview-h264.mp4',
    );
    await preview.initialized;

    driver.errorController.add('decoder initialization failed');
    await _drainEvents();
    expect(preview.availability, PreviewAvailability.unavailable);
    expect(preview.diagnostic, 'decoder initialization failed');

    await preview.close();
    preview.dispose();
  });

  test(
    'native selection playback pauses and pins position at its end',
    () async {
      final driver = _FakePreviewPlaybackDriver();
      final preview = MediaKitPreviewController(
        driver: driver,
        source: 'asset:///test/fixtures/preview-h264.mp4',
      );
      await preview.initialized;
      driver.durationController.add(2000);
      driver.playingController.add(true);
      await _drainEvents();

      preview.playSelection(400, 800);
      await _drainEvents();
      expect(driver.seekCommands, <int>[400]);
      expect(driver.playCount, 1);

      driver.positionController.add(800);
      await _drainEvents();
      await _drainEvents();
      expect(preview.positionMs, 800);
      expect(preview.playing, isFalse);
      expect(driver.pauseCount, 1);
      expect(driver.seekCommands, <int>[400, 800]);

      await preview.close();
      preview.dispose();
    },
  );

  test('explicit seek cancels the pending selection boundary', () async {
    final driver = _FakePreviewPlaybackDriver();
    final preview = MediaKitPreviewController(
      driver: driver,
      source: 'asset:///test/fixtures/preview-h264.mp4',
    );
    await preview.initialized;
    driver.durationController.add(2000);
    driver.playingController.add(true);
    await _drainEvents();

    preview.playSelection(400, 800);
    await _drainEvents();
    preview.seek(1200);
    await _drainEvents();
    driver.positionController.add(1200);
    await _drainEvents();

    expect(preview.playing, isTrue);
    expect(preview.positionMs, 1200);
    expect(driver.pauseCount, 0);

    await preview.close();
    preview.dispose();
  });
}

Future<void> _drainEvents() => Future<void>.delayed(Duration.zero);

class _FakePreviewPlaybackDriver implements PreviewPlaybackDriver {
  _FakePreviewPlaybackDriver({this.openError});

  final Object? openError;
  final StreamController<bool> playingController =
      StreamController<bool>.broadcast();
  final StreamController<int> positionController =
      StreamController<int>.broadcast();
  final StreamController<int> durationController =
      StreamController<int>.broadcast();
  final StreamController<bool> completedController =
      StreamController<bool>.broadcast();
  final StreamController<String> errorController =
      StreamController<String>.broadcast();
  final List<int> seekCommands = <int>[];
  final List<int> volumeCommands = <int>[];
  String? openedSource;
  int playCount = 0;
  int pauseCount = 0;
  int closeCount = 0;
  final List<double> playbackRateCommands = <double>[];

  @override
  Stream<bool> get completed => completedController.stream;

  @override
  Stream<int> get durationMs => durationController.stream;

  @override
  Stream<String> get errors => errorController.stream;

  @override
  Stream<bool> get playing => playingController.stream;

  @override
  Stream<int> get positionMs => positionController.stream;

  @override
  Future<void> close() async {
    closeCount += 1;
    await Future.wait<void>([
      playingController.close(),
      positionController.close(),
      durationController.close(),
      completedController.close(),
      errorController.close(),
    ]);
  }

  @override
  Future<void> open(String source) async {
    openedSource = source;
    final error = openError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> pause() async {
    pauseCount += 1;
  }

  @override
  Future<void> play() async {
    playCount += 1;
  }

  @override
  Future<void> seek(int positionMs) async {
    seekCommands.add(positionMs);
  }

  @override
  Future<void> setVolume(int volumePercent) async {
    volumeCommands.add(volumePercent);
  }

  @override
  Future<void> setPlaybackRate(double rate) async {
    playbackRateCommands.add(rate);
  }
}
