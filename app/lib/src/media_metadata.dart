/// Output recipes whose availability is supplied by Rust media metadata.
enum MediaOutputMode {
  /// MP4 with H.264 video and AAC audio.
  videoWithAudio,

  /// MP4 with H.264 video and no audio stream.
  videoOnly,

  /// MP3 audio extracted from the source.
  audioOnly,
}

/// Primary video metadata consumed by Flutter presentation state.
class VideoMetadata {
  /// Creates immutable video stream metadata.
  const VideoMetadata({
    required this.codec,
    required this.width,
    required this.height,
    required this.frameRate,
    required this.bitrate,
    required this.pixelFormat,
  });

  /// Codec display name reported by the backend.
  final String codec;

  /// Display width in pixels.
  final int width;

  /// Display height in pixels.
  final int height;

  /// Frames per second when known.
  final double? frameRate;

  /// Average stream bitrate when known.
  final int? bitrate;

  /// Pixel format when known.
  final String? pixelFormat;
}

/// Primary audio metadata consumed by Flutter presentation state.
class AudioMetadata {
  /// Creates immutable audio stream metadata.
  const AudioMetadata({
    required this.codec,
    required this.sampleRate,
    required this.channels,
    required this.bitrate,
  });

  /// Codec display name reported by the backend.
  final String codec;

  /// Sample rate in hertz when known.
  final int? sampleRate;

  /// Channel count when known.
  final int? channels;

  /// Average stream bitrate when known.
  final int? bitrate;
}

/// Canonical source metadata committed after a successful Rust probe.
class MediaMetadata {
  /// Creates one immutable media-session source.
  const MediaMetadata({
    required this.path,
    required this.fileName,
    required this.fileSizeBytes,
    required this.durationMs,
    required this.format,
    required this.video,
    required this.audio,
    required this.availableOutputModes,
  });

  /// Deterministic source retained by presentation-only visual tests.
  static const prototype = MediaMetadata(
    path: 'prototype:///ScreenRecording_08-13-2026.mov',
    fileName: 'ScreenRecording_08-13-2026.mov',
    fileSizeBytes: 9646899,
    durationMs: 3856,
    format: 'mov',
    video: VideoMetadata(
      codec: 'hevc',
      width: 1920,
      height: 1080,
      frameRate: 60,
      bitrate: 8000000,
      pixelFormat: 'yuv420p',
    ),
    audio: AudioMetadata(
      codec: 'aac',
      sampleRate: 48000,
      channels: 2,
      bitrate: 160000,
    ),
    availableOutputModes: <MediaOutputMode>[
      MediaOutputMode.videoWithAudio,
      MediaOutputMode.videoOnly,
      MediaOutputMode.audioOnly,
    ],
  );

  /// Canonical local path used by preview and later conversion requests.
  final String path;

  /// Last path component for display.
  final String fileName;

  /// File size in bytes.
  final int fileSizeBytes;

  /// Container duration in integer milliseconds.
  final int durationMs;

  /// Container format reported by the backend.
  final String format;

  /// Selected primary video stream when present.
  final VideoMetadata? video;

  /// Selected primary audio stream when present.
  final AudioMetadata? audio;

  /// Rust-authoritative output recipes supported by the primary streams.
  final List<MediaOutputMode> availableOutputModes;
}

/// Codec capabilities returned while initializing the native backend.
class MediaBackendCapabilities {
  /// Creates immutable backend capability state.
  const MediaBackendCapabilities({
    required this.ffmpegVersion,
    required this.h264Available,
    required this.aacAvailable,
    required this.mp3Available,
  });

  /// Human-readable FFmpeg library version.
  final String ffmpegVersion;

  /// Whether H.264 output is available on the active adapter.
  final bool h264Available;

  /// Whether AAC output is available.
  final bool aacAvailable;

  /// Whether libmp3lame output is available.
  final bool mp3Available;
}

/// Stable media failure categories mapped immediately from the Rust boundary.
enum MediaProbeErrorCode {
  /// The source lacks a supported primary stream.
  unsupportedInput,

  /// The source path or container could not be opened.
  cannotOpenInput,

  /// A selected stream could not be decoded for metadata.
  decodeFailed,

  /// A required encoder is unavailable.
  encoderUnavailable,

  /// A trim range violates source bounds.
  invalidTrimRange,

  /// The destination exists without overwrite approval.
  outputExists,

  /// A protected temporary output could not be created.
  outputCreateFailed,

  /// Output data could not be written or committed.
  diskWriteFailed,

  /// Another conversion owns the exclusive slot.
  jobActive,

  /// No matching active job exists.
  jobNotFound,

  /// Cooperative cancellation ended the operation.
  cancelled,

  /// The failure does not fit a stable category.
  unexpected,
}

/// Structured source-probe failure retained by presentation state.
class MediaProbeFailure implements Exception {
  /// Creates a stable code with its diagnostic cause.
  const MediaProbeFailure({required this.code, required this.diagnostic});

  /// Stable category used by presentation control flow and localization.
  final MediaProbeErrorCode code;

  /// Diagnostic cause retained for structured development logs.
  final String diagnostic;

  @override
  String toString() => 'MediaProbeFailure(${code.name}): $diagnostic';
}
