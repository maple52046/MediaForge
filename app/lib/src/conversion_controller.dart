import 'dart:async';

import 'package:flutter/foundation.dart';

import 'conversion_service.dart';
import 'media_metadata.dart';
import 'media_probe_service.dart';

/// Owns output selection and one conversion lifecycle at the Flutter edge.
class ConversionController extends ChangeNotifier {
  /// Creates a backend-connected controller limited to the primary recipe.
  ConversionController({
    required ConversionService service,
    required MediaProbeService outputPathService,
  }) : this._(
         service: service,
         outputPathService: outputPathService,
         supportedModes: const <MediaOutputMode>[
           MediaOutputMode.videoWithAudio,
         ],
       );

  /// Creates deterministic presentation-only state for visual and widget tests.
  ConversionController.prototype({
    bool initiallyConverting = false,
    bool autoAdvanceProgress = false,
  }) : this._(
         initiallyConverting: initiallyConverting,
         autoAdvanceProgress: autoAdvanceProgress,
         supportedModes: MediaOutputMode.values,
       );

  ConversionController._({
    this._service,
    this._outputPathService,
    required List<MediaOutputMode> supportedModes,
    bool initiallyConverting = false,
    this.autoAdvanceProgress = false,
  }) : _supportedModes = List<MediaOutputMode>.unmodifiable(supportedModes),
       _availableModes = List<MediaOutputMode>.unmodifiable(supportedModes),
       _converting = initiallyConverting,
       _progress = initiallyConverting ? 0.62 : 0,
       _jobState = initiallyConverting
           ? ConversionJobState.running
           : ConversionJobState.idle {
    if (_service != null) {
      _eventSubscription = _service.jobEvents.listen(
        _handleEvent,
        onError: _handleEventStreamError,
      );
    }
    if (_converting) {
      _startProgressTimer();
    }
  }

  final ConversionService? _service;
  final MediaProbeService? _outputPathService;
  final List<MediaOutputMode> _supportedModes;

  /// Whether prototype progress advances on a deterministic timer.
  final bool autoAdvanceProgress;

  StreamSubscription<ConversionJobEvent>? _eventSubscription;
  Timer? _progressTimer;
  MediaMetadata? _media;
  List<MediaOutputMode> _availableModes;
  MediaOutputMode _mode = MediaOutputMode.videoWithAudio;
  bool _converting;
  double _progress;
  ConversionJobState _jobState;
  bool _cancelling = false;
  int _processedMs = 0;
  int _totalMs = 0;
  double? _framesPerSecond;
  double? _speed;
  String? _outputPath;
  String? _completedOutputPath;
  ConversionFailure? _failure;
  int? _activeJobId;
  int _destinationGeneration = 0;
  final List<ConversionJobEvent> _earlyEvents = <ConversionJobEvent>[];
  Completer<void>? _terminalCompleter;
  bool _closed = false;
  bool _disposed = false;
  Future<void>? _closeFuture;

  /// Selected output recipe.
  MediaOutputMode get mode => _mode;

  /// Ordered recipes enabled for the current shell and source.
  List<MediaOutputMode> get availableModes => _availableModes;

  /// Whether a conversion currently owns the active presentation state.
  bool get converting => _converting;

  /// Presentation progress from zero through one.
  double get progress => _progress;

  /// Current application-owned job lifecycle state.
  ConversionJobState get jobState => _jobState;

  /// Whether a native cancellation request is awaiting a terminal event.
  bool get cancelling => _cancelling;

  /// Trim-relative processed time from the latest progress sample.
  int get processedMs => _processedMs;

  /// Selected duration from the latest progress sample or start request.
  int get totalMs => _totalMs;

  /// Current processing frame rate when the backend reports it.
  double? get framesPerSecond => _framesPerSecond;

  /// Current processing speed relative to realtime when reported.
  double? get speed => _speed;

  /// Backend-proposed destination for the current source and mode.
  String? get outputPath => _outputPath;

  /// Most recent destination committed by a completed job.
  String? get completedOutputPath => _completedOutputPath;

  /// Latest structured start or terminal failure.
  ConversionFailure? get failure => _failure;

  /// Whether the current source and destination can start a conversion.
  bool get canStart =>
      !_converting &&
      _availableModes.contains(_mode) &&
      (_service == null || (_media != null && _outputPath != null));

  /// Whether the current implementation exposes cancellation.
  bool get canCancel => _converting && !_cancelling;

  /// Applies Rust-authoritative source modes and resolves its default output.
  void setMedia(MediaMetadata media) {
    if (_converting || _closed) {
      return;
    }
    _media = media;
    _jobState = ConversionJobState.idle;
    _cancelling = false;
    _progress = 0;
    _processedMs = 0;
    _totalMs = 0;
    _framesPerSecond = null;
    _speed = null;
    _completedOutputPath = null;
    _failure = null;
    _applyAvailableModes(media.availableOutputModes);
    final generation = ++_destinationGeneration;
    if (_service != null && _availableModes.isEmpty) {
      _outputPath = null;
      _failure = const ConversionFailure(
        code: ConversionErrorCode.unsupportedInput,
        diagnostic:
            'The primary workflow requires both video and audio streams.',
      );
      _notifyListeners();
      return;
    }
    if (_service == null) {
      _outputPath = _prototypeOutputPath(media, _mode);
      _notifyListeners();
      return;
    }
    _outputPath = null;
    _notifyListeners();
    if (_availableModes.isNotEmpty) {
      unawaited(_resolveOutputPath(media, _mode, generation));
    }
  }

  /// Selects an enabled output recipe while no conversion is active.
  void selectMode(MediaOutputMode mode) {
    if (_converting || _mode == mode || !_availableModes.contains(mode)) {
      return;
    }
    _mode = mode;
    _completedOutputPath = null;
    _failure = null;
    final media = _media;
    final generation = ++_destinationGeneration;
    if (_service == null || media == null) {
      if (media != null) {
        _outputPath = _prototypeOutputPath(media, mode);
      }
      _notifyListeners();
      return;
    }
    _outputPath = null;
    _notifyListeners();
    unawaited(_resolveOutputPath(media, mode, generation));
  }

  /// Replaces mode availability in deterministic presentation-only tests.
  void setAvailableModes(List<MediaOutputMode> modes) {
    if (_service != null) {
      throw StateError('Backend-connected modes must come from setMedia.');
    }
    _applyAvailableModes(modes);
    _notifyListeners();
  }

  /// Starts the selected trim through the configured service or fake timer.
  Future<void> start({int? startMs, int? endMs}) async {
    if (!canStart) {
      return;
    }
    final service = _service;
    if (service == null) {
      _converting = true;
      _jobState = ConversionJobState.running;
      _cancelling = false;
      _progress = 0.08;
      _startProgressTimer();
      _notifyListeners();
      return;
    }
    final media = _media;
    final outputPath = _outputPath;
    if (media == null ||
        outputPath == null ||
        startMs == null ||
        endMs == null) {
      _failure = const ConversionFailure(
        code: ConversionErrorCode.invalidTrimRange,
        diagnostic: 'A probed source and trim range are required.',
      );
      _notifyListeners();
      return;
    }

    _converting = true;
    _jobState = ConversionJobState.preparing;
    _cancelling = false;
    _progress = 0;
    _processedMs = 0;
    _totalMs = endMs - startMs;
    _framesPerSecond = null;
    _speed = null;
    _failure = null;
    _completedOutputPath = null;
    _activeJobId = null;
    _earlyEvents.clear();
    _terminalCompleter = Completer<void>();
    _notifyListeners();
    try {
      final snapshot = await service.start(
        ConversionRequest(
          inputPath: media.path,
          outputPath: outputPath,
          mode: _mode,
          audioQuality: ConversionAudioQuality.medium,
          startMs: startMs,
          endMs: endMs,
          overwrite: false,
        ),
      );
      if (_closed) {
        return;
      }
      _activeJobId = snapshot.jobId;
      final earlyEvents = List<ConversionJobEvent>.of(_earlyEvents);
      _earlyEvents.clear();
      for (final event in earlyEvents) {
        _handleEvent(event);
      }
      if (_cancelling && _converting) {
        await _requestNativeCancellation(snapshot.jobId);
      }
    } on ConversionFailure catch (failure) {
      _finishWithFailure(failure);
    } on Object catch (error) {
      _finishWithFailure(
        ConversionFailure(
          code: ConversionErrorCode.unexpected,
          diagnostic: error.toString(),
        ),
      );
    }
  }

  /// Requests cancellation without unlocking until a terminal event arrives.
  Future<void> cancel() async {
    if (!canCancel) {
      return;
    }
    final service = _service;
    if (service == null) {
      _progressTimer?.cancel();
      _progressTimer = null;
      _converting = false;
      _jobState = ConversionJobState.cancelled;
      _progress = 0;
      _notifyListeners();
      return;
    }
    _cancelling = true;
    _notifyListeners();
    final activeJobId = _activeJobId;
    if (activeJobId != null) {
      await _requestNativeCancellation(activeJobId);
    }
  }

  /// Requests cancellation and waits until backend cleanup reaches a terminal event.
  Future<void> cancelAndWaitForTerminal() async {
    if (!_converting) {
      return;
    }
    final terminal = _terminalCompleter?.future;
    await cancel();
    if (terminal != null) {
      await terminal;
    }
  }

  /// Cancels the event subscription once and awaits stream cleanup.
  Future<void> close() => _closeFuture ??= _close();

  void _applyAvailableModes(List<MediaOutputMode> modes) {
    final next = List<MediaOutputMode>.unmodifiable(
      modes.where(_supportedModes.contains),
    );
    _availableModes = next;
    if (!next.contains(_mode) && next.isNotEmpty) {
      _mode = next.first;
    }
  }

  Future<void> _resolveOutputPath(
    MediaMetadata media,
    MediaOutputMode mode,
    int generation,
  ) async {
    try {
      final outputPath = await _outputPathService!.defaultOutputPath(
        media.path,
        mode,
      );
      if (_closed || generation != _destinationGeneration) {
        return;
      }
      _outputPath = outputPath;
      _notifyListeners();
    } on MediaProbeFailure catch (failure) {
      if (_closed || generation != _destinationGeneration) {
        return;
      }
      _failure = _fromProbeFailure(failure);
      _notifyListeners();
    } on Object catch (error) {
      if (_closed || generation != _destinationGeneration) {
        return;
      }
      _failure = ConversionFailure(
        code: ConversionErrorCode.unexpected,
        diagnostic: error.toString(),
      );
      _notifyListeners();
    }
  }

  void _handleEvent(ConversionJobEvent event) {
    if (_closed || !_converting) {
      return;
    }
    final activeJobId = _activeJobId;
    if (activeJobId == null) {
      _earlyEvents.add(event);
      return;
    }
    if (event.jobId != activeJobId) {
      return;
    }
    switch (event.kind) {
      case ConversionJobEventKind.preparing:
        _jobState = ConversionJobState.preparing;
        return;
      case ConversionJobEventKind.progress:
        _handleProgress(event);
        return;
      case ConversionJobEventKind.completed:
        final outputPath = event.outputPath;
        if (outputPath == null) {
          _finishWithFailure(
            const ConversionFailure(
              code: ConversionErrorCode.unexpected,
              diagnostic: 'Completed conversion did not include its output.',
            ),
          );
          return;
        }
        _converting = false;
        _jobState = ConversionJobState.completed;
        _cancelling = false;
        _progress = 1;
        _processedMs = _totalMs;
        _completedOutputPath = outputPath;
        _activeJobId = null;
        _completeTerminal();
        _notifyListeners();
      case ConversionJobEventKind.cancelled:
        _converting = false;
        _jobState = ConversionJobState.cancelled;
        _cancelling = false;
        _progress = 0;
        _failure = null;
        _activeJobId = null;
        _completeTerminal();
        _notifyListeners();
      case ConversionJobEventKind.failed:
        _finishWithFailure(
          event.failure ??
              const ConversionFailure(
                code: ConversionErrorCode.unexpected,
                diagnostic: 'Failed conversion did not include a cause.',
              ),
        );
    }
  }

  void _handleProgress(ConversionJobEvent event) {
    final percent = event.percent;
    final processedMs = event.processedMs;
    final totalMs = event.totalMs;
    if (percent == null ||
        processedMs == null ||
        totalMs == null ||
        totalMs <= 0) {
      _finishWithFailure(
        const ConversionFailure(
          code: ConversionErrorCode.unexpected,
          diagnostic: 'Progress event did not include a valid sample.',
        ),
      );
      return;
    }
    final normalized = (percent / 100).clamp(0.0, 1.0).toDouble();
    if (normalized > _progress) {
      _progress = normalized;
    }
    if (processedMs > _processedMs) {
      _processedMs = processedMs.clamp(0, totalMs).toInt();
    }
    _totalMs = totalMs;
    _framesPerSecond = event.framesPerSecond;
    _speed = event.speed;
    _jobState = ConversionJobState.running;
    _notifyListeners();
  }

  Future<void> _requestNativeCancellation(int jobId) async {
    try {
      await _service!.cancel(jobId);
    } on ConversionFailure catch (failure) {
      if (_cancelling && failure.code == ConversionErrorCode.jobNotFound) {
        // Rationale: backend cleanup may become terminal immediately before cancellation locks it.
        return;
      }
      if (_converting && _activeJobId == jobId) {
        _finishWithFailure(failure);
      }
    } on Object catch (error) {
      if (_converting && _activeJobId == jobId) {
        _finishWithFailure(
          ConversionFailure(
            code: ConversionErrorCode.unexpected,
            diagnostic: error.toString(),
          ),
        );
      }
    }
  }

  void _handleEventStreamError(Object error, StackTrace stackTrace) {
    if (!_converting || _closed) {
      return;
    }
    _finishWithFailure(
      ConversionFailure(
        code: ConversionErrorCode.unexpected,
        diagnostic: error.toString(),
      ),
    );
  }

  void _finishWithFailure(ConversionFailure failure) {
    if (_closed) {
      return;
    }
    _converting = false;
    _jobState = ConversionJobState.failed;
    _cancelling = false;
    _progress = 0;
    _failure = failure;
    _activeJobId = null;
    _earlyEvents.clear();
    _completeTerminal();
    _notifyListeners();
  }

  void _completeTerminal() {
    final terminal = _terminalCompleter;
    if (terminal != null && !terminal.isCompleted) {
      terminal.complete();
    }
  }

  void _startProgressTimer() {
    if (!autoAdvanceProgress || _progressTimer != null) {
      return;
    }
    _progressTimer = Timer.periodic(const Duration(milliseconds: 180), (
      Timer timer,
    ) {
      if (!_converting) {
        timer.cancel();
        _progressTimer = null;
        return;
      }
      _progress = (_progress + 0.012).clamp(0, 0.96);
      if (_progress >= 0.96) {
        timer.cancel();
        _progressTimer = null;
      }
      _notifyListeners();
    });
  }

  String _prototypeOutputPath(MediaMetadata media, MediaOutputMode mode) {
    final extension = switch (mode) {
      MediaOutputMode.videoWithAudio || MediaOutputMode.videoOnly => 'mp4',
      MediaOutputMode.audioOnly => 'mp3',
    };
    final dot = media.fileName.lastIndexOf('.');
    final stem = dot > 0 ? media.fileName.substring(0, dot) : media.fileName;
    return '~/Movies/MediaForge/$stem.$extension';
  }

  ConversionFailure _fromProbeFailure(MediaProbeFailure failure) {
    return ConversionFailure(
      code: switch (failure.code) {
        MediaProbeErrorCode.unsupportedInput =>
          ConversionErrorCode.unsupportedInput,
        MediaProbeErrorCode.cannotOpenInput =>
          ConversionErrorCode.cannotOpenInput,
        MediaProbeErrorCode.decodeFailed => ConversionErrorCode.decodeFailed,
        MediaProbeErrorCode.encoderUnavailable =>
          ConversionErrorCode.encoderUnavailable,
        MediaProbeErrorCode.invalidTrimRange =>
          ConversionErrorCode.invalidTrimRange,
        MediaProbeErrorCode.outputExists => ConversionErrorCode.outputExists,
        MediaProbeErrorCode.outputCreateFailed =>
          ConversionErrorCode.outputCreateFailed,
        MediaProbeErrorCode.diskWriteFailed =>
          ConversionErrorCode.diskWriteFailed,
        MediaProbeErrorCode.jobActive => ConversionErrorCode.jobActive,
        MediaProbeErrorCode.jobNotFound => ConversionErrorCode.jobNotFound,
        MediaProbeErrorCode.cancelled => ConversionErrorCode.cancelled,
        MediaProbeErrorCode.unexpected => ConversionErrorCode.unexpected,
      },
      diagnostic: failure.diagnostic,
    );
  }

  Future<void> _close() async {
    await cancelAndWaitForTerminal();
    _closed = true;
    _destinationGeneration += 1;
    _progressTimer?.cancel();
    await _eventSubscription?.cancel();
  }

  void _notifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    // Constraint: synchronous disposal cannot await backend terminal cleanup.
    _disposed = true;
    unawaited(close());
    super.dispose();
  }
}
