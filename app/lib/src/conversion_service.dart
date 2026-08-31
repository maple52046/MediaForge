import '../bridge/api/media.dart' as bridge;
import 'media_metadata.dart';

/// MP3 quality selected for audio-only conversion.
enum ConversionAudioQuality {
  /// 256 kbps MP3.
  high,

  /// 192 kbps MP3.
  medium,

  /// 128 kbps MP3.
  low,
}

/// Stable lifecycle values returned with a started conversion.
enum ConversionJobState {
  /// No conversion has started.
  idle,

  /// The application reserved a worker and is opening media resources.
  preparing,

  /// The backend is producing output.
  running,

  /// The destination was committed successfully.
  completed,

  /// Cooperative cancellation ended the operation.
  cancelled,

  /// A non-cancellation failure ended the operation.
  failed,
}

/// Discriminator controlling the meaningful fields in [ConversionJobEvent].
enum ConversionJobEventKind {
  /// The application reserved the exclusive worker slot.
  preparing,

  /// The backend emitted a progress sample.
  progress,

  /// The final destination was committed successfully.
  completed,

  /// Cooperative cancellation and cleanup completed.
  cancelled,

  /// A non-cancellation failure and cleanup completed.
  failed,
}

/// Stable failure categories owned by Flutter conversion presentation state.
enum ConversionErrorCode {
  /// The source lacks streams required by the selected recipe.
  unsupportedInput,

  /// The source could not be opened.
  cannotOpenInput,

  /// A selected stream could not be decoded.
  decodeFailed,

  /// A required encoder is unavailable.
  encoderUnavailable,

  /// The selected trim violates source bounds.
  invalidTrimRange,

  /// The destination exists without overwrite approval.
  outputExists,

  /// A protected temporary output could not be created.
  outputCreateFailed,

  /// Output could not be written or committed.
  diskWriteFailed,

  /// Another conversion owns the exclusive worker slot.
  jobActive,

  /// The requested job does not exist.
  jobNotFound,

  /// Cooperative cancellation ended the operation.
  cancelled,

  /// The failure does not fit another stable category.
  unexpected,
}

/// Plain request sent through an injected conversion boundary.
class ConversionRequest {
  /// Creates one immutable conversion request.
  const ConversionRequest({
    required this.inputPath,
    required this.outputPath,
    required this.mode,
    required this.audioQuality,
    required this.startMs,
    required this.endMs,
    required this.overwrite,
  });

  /// Canonical source path returned by Rust probe.
  final String inputPath;

  /// Destination path proposed by the backend.
  final String outputPath;

  /// Selected Rust-authoritative output recipe.
  final MediaOutputMode mode;

  /// MP3 quality used when [mode] is [MediaOutputMode.audioOnly].
  final ConversionAudioQuality audioQuality;

  /// Inclusive trim start in integer milliseconds.
  final int startMs;

  /// Exclusive trim end in integer milliseconds.
  final int endMs;

  /// Whether a pre-existing destination may be replaced after success.
  final bool overwrite;
}

/// Snapshot returned after Rust reserves the application job.
class ConversionJobSnapshot {
  /// Creates one immutable job snapshot.
  const ConversionJobSnapshot({
    required this.jobId,
    required this.state,
    required this.inputPath,
    required this.outputPath,
  });

  /// Process-local identifier used to correlate events.
  final int jobId;

  /// Current lifecycle state.
  final ConversionJobState state;

  /// Canonical source reserved by the job.
  final String inputPath;

  /// Canonical destination reserved by the job.
  final String outputPath;
}

/// Tagged conversion event mapped immediately from generated FRB values.
class ConversionJobEvent {
  /// Creates one event whose optional values follow [kind].
  const ConversionJobEvent({
    required this.kind,
    required this.jobId,
    this.percent,
    this.processedMs,
    this.totalMs,
    this.framesPerSecond,
    this.speed,
    this.outputPath,
    this.failure,
  });

  /// Discriminator controlling the meaningful optional values.
  final ConversionJobEventKind kind;

  /// Job that produced this event.
  final int jobId;

  /// Completion percentage for progress events.
  final double? percent;

  /// Processed trim-relative time for progress events.
  final int? processedMs;

  /// Selected duration for progress events.
  final int? totalMs;

  /// Current frame rate when reported with progress.
  final double? framesPerSecond;

  /// Current realtime multiplier when reported with progress.
  final double? speed;

  /// Final destination for completed events.
  final String? outputPath;

  /// Structured cause for failed events.
  final ConversionFailure? failure;
}

/// Structured conversion failure retained for localization and diagnostics.
class ConversionFailure implements Exception {
  /// Creates a stable category with its diagnostic cause.
  const ConversionFailure({required this.code, required this.diagnostic});

  /// Stable category used by presentation control flow.
  final ConversionErrorCode code;

  /// Diagnostic cause retained for structured development logs.
  final String diagnostic;

  @override
  String toString() => 'ConversionFailure(${code.name}): $diagnostic';
}

/// Conversion operations consumed by presentation-owned controller state.
abstract interface class ConversionService {
  /// Ordered application events for the process's current Flutter subscriber.
  Stream<ConversionJobEvent> get jobEvents;

  /// Validates and starts one conversion on the Rust application worker.
  Future<ConversionJobSnapshot> start(ConversionRequest request);

  /// Requests cancellation while terminal completion remains event-driven.
  Future<void> cancel(int jobId);
}

/// Maps generated FRB conversion values into Flutter-owned plain values.
class RustConversionService implements ConversionService {
  /// Creates the process-wide native conversion adapter.
  const RustConversionService();

  // Invariant: FRB owns one native event sink for the process; Flutter
  // controllers may attach and detach without replacing that sink.
  static final Stream<ConversionJobEvent> _processJobEvents = bridge
      .jobEvents()
      .map(_fromBridgeJobEvent)
      .asBroadcastStream(onCancel: (_) {});

  @override
  Stream<ConversionJobEvent> get jobEvents => _processJobEvents;

  @override
  Future<ConversionJobSnapshot> start(ConversionRequest request) async {
    try {
      final snapshot = await bridge.startTranscode(
        request: bridge.StartTranscodeRequestDto(
          inputPath: request.inputPath,
          outputPath: request.outputPath,
          mode: _toBridgeMode(request.mode),
          audioQuality: _toBridgeQuality(request.audioQuality),
          startMs: request.startMs,
          endMs: request.endMs,
          overwrite: request.overwrite,
        ),
      );
      return ConversionJobSnapshot(
        jobId: snapshot.jobId,
        state: _fromBridgeState(snapshot.state),
        inputPath: snapshot.inputPath,
        outputPath: snapshot.outputPath,
      );
    } on bridge.MediaBridgeError catch (error) {
      throw _mapBridgeFailure(error);
    }
  }

  @override
  Future<void> cancel(int jobId) async {
    try {
      await bridge.cancelTranscode(jobId: jobId);
    } on bridge.MediaBridgeError catch (error) {
      throw _mapBridgeFailure(error);
    }
  }
}

ConversionJobEvent _fromBridgeJobEvent(bridge.JobEventDto event) =>
    ConversionJobEvent(
      kind: _fromBridgeEventKind(event.kind),
      jobId: event.jobId,
      percent: event.percent,
      processedMs: event.processedMs,
      totalMs: event.totalMs,
      framesPerSecond: event.framesPerSecond,
      speed: event.speed,
      outputPath: event.outputPath,
      failure: event.error == null ? null : _mapBridgeFailure(event.error!),
    );

bridge.MediaOutputMode _toBridgeMode(MediaOutputMode mode) => switch (mode) {
  MediaOutputMode.videoWithAudio => bridge.MediaOutputMode.videoWithAudio,
  MediaOutputMode.videoOnly => bridge.MediaOutputMode.videoOnly,
  MediaOutputMode.audioOnly => bridge.MediaOutputMode.audioOnly,
};

bridge.MediaAudioQuality _toBridgeQuality(ConversionAudioQuality quality) =>
    switch (quality) {
      ConversionAudioQuality.high => bridge.MediaAudioQuality.high,
      ConversionAudioQuality.medium => bridge.MediaAudioQuality.medium,
      ConversionAudioQuality.low => bridge.MediaAudioQuality.low,
    };

ConversionJobState _fromBridgeState(bridge.JobStateDto state) =>
    switch (state) {
      bridge.JobStateDto.idle => ConversionJobState.idle,
      bridge.JobStateDto.preparing => ConversionJobState.preparing,
      bridge.JobStateDto.running => ConversionJobState.running,
      bridge.JobStateDto.completed => ConversionJobState.completed,
      bridge.JobStateDto.cancelled => ConversionJobState.cancelled,
      bridge.JobStateDto.failed => ConversionJobState.failed,
    };

ConversionJobEventKind _fromBridgeEventKind(bridge.JobEventKindDto kind) =>
    switch (kind) {
      bridge.JobEventKindDto.preparing => ConversionJobEventKind.preparing,
      bridge.JobEventKindDto.progress => ConversionJobEventKind.progress,
      bridge.JobEventKindDto.completed => ConversionJobEventKind.completed,
      bridge.JobEventKindDto.cancelled => ConversionJobEventKind.cancelled,
      bridge.JobEventKindDto.failed => ConversionJobEventKind.failed,
    };

ConversionFailure _mapBridgeFailure(bridge.MediaBridgeError error) {
  return ConversionFailure(
    code: switch (error.code) {
      bridge.MediaBridgeErrorCode.unsupportedInput =>
        ConversionErrorCode.unsupportedInput,
      bridge.MediaBridgeErrorCode.cannotOpenInput =>
        ConversionErrorCode.cannotOpenInput,
      bridge.MediaBridgeErrorCode.decodeFailed =>
        ConversionErrorCode.decodeFailed,
      bridge.MediaBridgeErrorCode.encoderUnavailable =>
        ConversionErrorCode.encoderUnavailable,
      bridge.MediaBridgeErrorCode.invalidTrimRange =>
        ConversionErrorCode.invalidTrimRange,
      bridge.MediaBridgeErrorCode.outputExists =>
        ConversionErrorCode.outputExists,
      bridge.MediaBridgeErrorCode.outputCreateFailed =>
        ConversionErrorCode.outputCreateFailed,
      bridge.MediaBridgeErrorCode.diskWriteFailed =>
        ConversionErrorCode.diskWriteFailed,
      bridge.MediaBridgeErrorCode.jobActive => ConversionErrorCode.jobActive,
      bridge.MediaBridgeErrorCode.jobNotFound =>
        ConversionErrorCode.jobNotFound,
      bridge.MediaBridgeErrorCode.cancelled => ConversionErrorCode.cancelled,
      bridge.MediaBridgeErrorCode.unexpected => ConversionErrorCode.unexpected,
    },
    diagnostic: error.diagnostic,
  );
}
