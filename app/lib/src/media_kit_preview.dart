import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'preview_controller.dart';

/// Player operations and integer-millisecond streams consumed by preview UI.
abstract interface class PreviewPlaybackDriver {
  /// Whether playback is active.
  Stream<bool> get playing;

  /// Current position in integer milliseconds.
  Stream<int> get positionMs;

  /// Current duration in integer milliseconds.
  Stream<int> get durationMs;

  /// Current volume rounded to an integer percentage.
  Stream<int> get volumePercent;

  /// Whether the current source reached its end.
  Stream<bool> get completed;

  /// Native diagnostic messages that make preview unavailable.
  Stream<String> get errors;

  /// Opens one source without automatically starting playback.
  Future<void> open(String source);

  /// Starts playback.
  Future<void> play();

  /// Pauses playback.
  Future<void> pause();

  /// Seeks to an integer-millisecond position.
  Future<void> seek(int positionMs);

  /// Sets volume from zero through one hundred.
  Future<void> setVolume(int volumePercent);

  /// Releases native player resources.
  Future<void> close();
}

/// Owns a media_kit controller and its matching framework-free preview state.
class MediaKitPreviewSession {
  /// Creates one native player session for a local file or Flutter asset URI.
  factory MediaKitPreviewSession({required String source}) {
    final player = Player();
    final driver = _MediaKitPlaybackDriver(player);
    return MediaKitPreviewSession._(
      preview: MediaKitPreviewController(driver: driver, source: source),
      video: VideoController(player),
    );
  }

  const MediaKitPreviewSession._({required this.preview, required this.video});

  /// Framework-free state and commands observed by the MediaForge UI.
  final MediaKitPreviewController preview;

  /// media_kit video output handle retained at the presentation edge.
  final VideoController video;
}

/// Maps media_kit playback into stable integer-millisecond presentation state.
class MediaKitPreviewController extends PreviewController {
  /// Opens [source] through [driver] and retains failures as fallback state.
  factory MediaKitPreviewController({
    required PreviewPlaybackDriver driver,
    required String source,
  }) => MediaKitPreviewController._(driver, source);

  MediaKitPreviewController._(this._driver, String source) {
    _playingSubscription = _driver.playing.listen(_setPlaying);
    _positionSubscription = _driver.positionMs.listen(_setPosition);
    _durationSubscription = _driver.durationMs.listen(_setDuration);
    _volumeSubscription = _driver.volumePercent.listen(_setVolume);
    _completedSubscription = _driver.completed.listen(_setCompleted);
    _errorSubscription = _driver.errors.listen(_setUnavailable);
    initialized = _initialize(source);
  }

  final PreviewPlaybackDriver _driver;
  late final StreamSubscription<bool> _playingSubscription;
  late final StreamSubscription<int> _positionSubscription;
  late final StreamSubscription<int> _durationSubscription;
  late final StreamSubscription<int> _volumeSubscription;
  late final StreamSubscription<bool> _completedSubscription;
  late final StreamSubscription<String> _errorSubscription;
  Future<void>? _closeFuture;
  bool _closed = false;
  PreviewAvailability _availability = PreviewAvailability.opening;
  bool _playing = false;
  int _positionMs = 0;
  int _durationMs = 0;
  int _volumePercent = 78;
  String? _diagnostic;
  int? _selectionEndMs;
  bool _selectionStopRequested = false;
  int _playbackIntent = 0;

  /// Completes after the first source either opens or enters fallback state.
  late final Future<void> initialized;

  @override
  PreviewAvailability get availability => _availability;

  @override
  String? get diagnostic => _diagnostic;

  @override
  int get durationMs => _durationMs;

  @override
  bool get playing => _playing;

  @override
  int get positionMs => _positionMs;

  @override
  int get volumePercent => _volumePercent;

  @override
  void togglePlayback() {
    if (_availability != PreviewAvailability.ready) {
      return;
    }
    final shouldPause = _playing;
    final intent = ++_playbackIntent;
    _selectionEndMs = null;
    _selectionStopRequested = false;
    _schedule(() async {
      if (_closed || intent != _playbackIntent) {
        return;
      }
      await (shouldPause ? _driver.pause() : _driver.play());
    });
  }

  @override
  void playSelection(int startMs, int endMs) {
    if (_availability != PreviewAvailability.ready) {
      return;
    }
    final start = _boundedPosition(startMs);
    final end = _boundedPosition(endMs);
    if (start >= end) {
      return;
    }
    final intent = ++_playbackIntent;
    _selectionEndMs = end;
    _selectionStopRequested = false;
    _schedule(() async {
      await _driver.seek(start);
      if (_closed || intent != _playbackIntent) {
        return;
      }
      await _driver.play();
    });
  }

  @override
  void seek(int positionMs) {
    if (_availability != PreviewAvailability.ready) {
      return;
    }
    final position = _boundedPosition(positionMs);
    final intent = ++_playbackIntent;
    _selectionEndMs = null;
    _selectionStopRequested = false;
    _schedule(() async {
      if (_closed || intent != _playbackIntent) {
        return;
      }
      await _driver.seek(position);
    });
  }

  @override
  void setVolume(int volumePercent) {
    if (_availability == PreviewAvailability.unavailable) {
      return;
    }
    _schedule(() => _driver.setVolume(volumePercent.clamp(0, 100)));
  }

  /// Cancels stream subscriptions and awaits native player disposal once.
  Future<void> close() => _closeFuture ??= _close();

  Future<void> _initialize(String source) async {
    try {
      await _driver.setVolume(_volumePercent);
      await _driver.open(_normalizePreviewSource(source));
      if (!_closed && _availability != PreviewAvailability.unavailable) {
        _availability = PreviewAvailability.ready;
        notifyListeners();
      }
    } on Object catch (error) {
      _setUnavailable(error.toString());
    }
  }

  void _schedule(Future<void> Function() operation) {
    unawaited(_perform(operation));
  }

  Future<void> _perform(Future<void> Function() operation) async {
    try {
      await operation();
    } on Object catch (error) {
      _setUnavailable(error.toString());
    }
  }

  int _boundedPosition(int positionMs) {
    final upperBound = _durationMs > 0
        ? _durationMs
        : positionMs.clamp(0, 1 << 31);
    return positionMs.clamp(0, upperBound);
  }

  void _setPlaying(bool playing) {
    if (_selectionStopRequested && playing) {
      return;
    }
    if (_closed || _playing == playing) {
      return;
    }
    _playing = playing;
    notifyListeners();
  }

  void _setPosition(int positionMs) {
    if (_closed) {
      return;
    }
    final bounded = _boundedPosition(positionMs);
    final selectionEnd = _selectionEndMs;
    final reachedSelectionEnd = selectionEnd != null && bounded >= selectionEnd;
    final position = reachedSelectionEnd ? selectionEnd : bounded;
    var changed = _positionMs != position;
    _positionMs = position;
    if (reachedSelectionEnd && !_selectionStopRequested) {
      _selectionStopRequested = true;
      changed = changed || _playing;
      _playing = false;
      final intent = ++_playbackIntent;
      _schedule(() async {
        if (_closed || intent != _playbackIntent) {
          return;
        }
        await _driver.pause();
        if (_closed || intent != _playbackIntent) {
          return;
        }
        await _driver.seek(selectionEnd);
        if (intent == _playbackIntent) {
          _selectionEndMs = null;
          _selectionStopRequested = false;
        }
      });
    }
    if (changed) {
      notifyListeners();
    }
  }

  void _setDuration(int durationMs) {
    final duration = durationMs.clamp(0, 1 << 31);
    if (_closed || _durationMs == duration) {
      return;
    }
    _durationMs = duration;
    if (_positionMs > duration && duration > 0) {
      _positionMs = duration;
    }
    notifyListeners();
  }

  void _setVolume(int volumePercent) {
    final volume = volumePercent.clamp(0, 100);
    if (_closed || _volumePercent == volume) {
      return;
    }
    _volumePercent = volume;
    notifyListeners();
  }

  void _setCompleted(bool completed) {
    if (!completed || _closed || !_playing) {
      return;
    }
    _selectionEndMs = null;
    _selectionStopRequested = false;
    _playing = false;
    notifyListeners();
  }

  void _setUnavailable(String diagnostic) {
    if (_closed || diagnostic.isEmpty) {
      return;
    }
    _availability = PreviewAvailability.unavailable;
    _playing = false;
    _selectionEndMs = null;
    _selectionStopRequested = false;
    _diagnostic = diagnostic;
    notifyListeners();
  }

  Future<void> _close() async {
    _closed = true;
    _playbackIntent += 1;
    try {
      await Future.wait<void>([
        _playingSubscription.cancel(),
        _positionSubscription.cancel(),
        _durationSubscription.cancel(),
        _volumeSubscription.cancel(),
        _completedSubscription.cancel(),
        _errorSubscription.cancel(),
      ]);
    } finally {
      await _driver.close();
    }
  }

  @override
  void dispose() {
    // Constraint: ChangeNotifier disposal cannot await the tracked native cleanup.
    unawaited(close());
    super.dispose();
  }
}

/// Renders native video without package controls or aspect-ratio cropping.
class MediaKitVideoSurface extends StatelessWidget {
  /// Creates a letterboxed output for one media_kit [controller].
  const MediaKitVideoSurface({required this.controller, super.key});

  /// Native texture controller owned by the matching preview session.
  final VideoController controller;

  @override
  Widget build(BuildContext context) {
    return Video(
      key: const Key('native-preview-video'),
      controller: controller,
      fit: BoxFit.contain,
      fill: const Color(0xFF07080A),
      controls: null,
    );
  }
}

class _MediaKitPlaybackDriver implements PreviewPlaybackDriver {
  _MediaKitPlaybackDriver(this._player);

  final Player _player;

  @override
  Stream<bool> get completed => _player.stream.completed;

  @override
  Stream<int> get durationMs =>
      _player.stream.duration.map((Duration value) => value.inMilliseconds);

  @override
  Stream<String> get errors => _player.stream.error;

  @override
  Stream<bool> get playing => _player.stream.playing;

  @override
  Stream<int> get positionMs =>
      _player.stream.position.map((Duration value) => value.inMilliseconds);

  @override
  Stream<int> get volumePercent =>
      _player.stream.volume.map((double value) => value.round());

  @override
  Future<void> close() => _player.dispose();

  @override
  Future<void> open(String source) => _player.open(Media(source), play: false);

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> seek(int positionMs) =>
      _player.seek(Duration(milliseconds: positionMs));

  @override
  Future<void> setVolume(int volumePercent) =>
      _player.setVolume(volumePercent.toDouble());
}

String _normalizePreviewSource(String source) {
  final uri = Uri.tryParse(source);
  if (uri != null && uri.hasScheme) {
    return source;
  }
  return Uri.file(source).toString();
}
