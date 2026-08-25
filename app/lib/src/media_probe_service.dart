import '../bridge/api/media.dart' as bridge;
import 'media_metadata.dart';

/// Presentation-owned source for backend capabilities and canonical metadata.
abstract interface class MediaProbeService {
  /// Initializes the native backend and reports its codec capabilities.
  Future<MediaBackendCapabilities> initializeBackend();

  /// Probes one local source without mutating media-session state.
  Future<MediaMetadata> probe(String path);

  /// Proposes a destination beside a canonical source.
  Future<String> defaultOutputPath(String path, MediaOutputMode mode);
}

/// Maps generated FRB values immediately into Flutter-owned presentation data.
class RustMediaProbeService implements MediaProbeService {
  /// Creates the process-wide native probe adapter.
  const RustMediaProbeService();

  @override
  Future<MediaBackendCapabilities> initializeBackend() async {
    try {
      final capabilities = await bridge.initializeBackend();
      return MediaBackendCapabilities(
        ffmpegVersion: capabilities.ffmpegVersion,
        h264Available: capabilities.h264Available,
        aacAvailable: capabilities.aacAvailable,
        mp3Available: capabilities.mp3Available,
      );
    } on bridge.MediaBridgeError catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<MediaMetadata> probe(String path) async {
    try {
      return _mapMedia(await bridge.probeMedia(path: path));
    } on bridge.MediaBridgeError catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<String> defaultOutputPath(String path, MediaOutputMode mode) async {
    try {
      return await bridge.defaultOutputPath(
        path: path,
        mode: _toBridgeMode(mode),
      );
    } on bridge.MediaBridgeError catch (error) {
      throw _mapError(error);
    }
  }
}

MediaMetadata _mapMedia(bridge.MediaInfoDto media) {
  return MediaMetadata(
    path: media.path,
    fileName: media.fileName,
    fileSizeBytes: media.fileSizeBytes,
    durationMs: media.durationMs,
    format: media.format,
    video: switch (media.video) {
      final video? => VideoMetadata(
        codec: video.codec,
        width: video.width,
        height: video.height,
        frameRate: video.frameRate,
        bitrate: video.bitrate,
        pixelFormat: video.pixelFormat,
      ),
      null => null,
    },
    audio: switch (media.audio) {
      final audio? => AudioMetadata(
        codec: audio.codec,
        sampleRate: audio.sampleRate,
        channels: audio.channels,
        bitrate: audio.bitrate,
      ),
      null => null,
    },
    availableOutputModes: media.availableOutputModes
        .map(_fromBridgeMode)
        .toList(growable: false),
  );
}

MediaOutputMode _fromBridgeMode(bridge.MediaOutputMode mode) => switch (mode) {
  bridge.MediaOutputMode.videoWithAudio => MediaOutputMode.videoWithAudio,
  bridge.MediaOutputMode.videoOnly => MediaOutputMode.videoOnly,
  bridge.MediaOutputMode.audioOnly => MediaOutputMode.audioOnly,
};

bridge.MediaOutputMode _toBridgeMode(MediaOutputMode mode) => switch (mode) {
  MediaOutputMode.videoWithAudio => bridge.MediaOutputMode.videoWithAudio,
  MediaOutputMode.videoOnly => bridge.MediaOutputMode.videoOnly,
  MediaOutputMode.audioOnly => bridge.MediaOutputMode.audioOnly,
};

MediaProbeFailure _mapError(bridge.MediaBridgeError error) {
  return MediaProbeFailure(
    code: switch (error.code) {
      bridge.MediaBridgeErrorCode.unsupportedInput =>
        MediaProbeErrorCode.unsupportedInput,
      bridge.MediaBridgeErrorCode.cannotOpenInput =>
        MediaProbeErrorCode.cannotOpenInput,
      bridge.MediaBridgeErrorCode.decodeFailed =>
        MediaProbeErrorCode.decodeFailed,
      bridge.MediaBridgeErrorCode.encoderUnavailable =>
        MediaProbeErrorCode.encoderUnavailable,
      bridge.MediaBridgeErrorCode.invalidTrimRange =>
        MediaProbeErrorCode.invalidTrimRange,
      bridge.MediaBridgeErrorCode.outputExists =>
        MediaProbeErrorCode.outputExists,
      bridge.MediaBridgeErrorCode.outputCreateFailed =>
        MediaProbeErrorCode.outputCreateFailed,
      bridge.MediaBridgeErrorCode.diskWriteFailed =>
        MediaProbeErrorCode.diskWriteFailed,
      bridge.MediaBridgeErrorCode.jobActive => MediaProbeErrorCode.jobActive,
      bridge.MediaBridgeErrorCode.jobNotFound =>
        MediaProbeErrorCode.jobNotFound,
      bridge.MediaBridgeErrorCode.cancelled => MediaProbeErrorCode.cancelled,
      bridge.MediaBridgeErrorCode.unexpected => MediaProbeErrorCode.unexpected,
    },
    diagnostic: error.diagnostic,
  );
}
