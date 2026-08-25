import 'package:flutter/foundation.dart';

import 'media_metadata.dart';
import 'media_probe_service.dart';

/// Owns provisional source probing and committed media-session metadata.
class MediaSessionController extends ChangeNotifier {
  /// Creates a media session around an injected probe boundary.
  factory MediaSessionController({
    required MediaProbeService probeService,
    MediaMetadata? initialMedia,
    String? candidatePath,
    bool initialDropOverlayVisible = false,
  }) {
    return MediaSessionController._(
      probeService,
      initialMedia,
      candidatePath,
      initialDropOverlayVisible,
    );
  }

  MediaSessionController._(
    this._probeService,
    this._media,
    this._candidatePath,
    this._dropOverlayVisible,
  );

  /// Creates deterministic presentation-only state for visual and widget tests.
  factory MediaSessionController.prototype({
    required bool initialHasMedia,
    bool initialDropOverlayVisible = false,
  }) {
    return MediaSessionController(
      probeService: const _PrototypeMediaProbeService(),
      initialMedia: initialHasMedia ? MediaMetadata.prototype : null,
      candidatePath: MediaMetadata.prototype.path,
      initialDropOverlayVisible: initialDropOverlayVisible,
    );
  }

  final MediaProbeService _probeService;
  MediaMetadata? _media;
  String? _candidatePath;
  bool _dropOverlayVisible;
  bool _probing = false;
  MediaProbeFailure? _failure;
  int _probeGeneration = 0;
  bool _disposed = false;

  /// Successfully probed source currently committed to the session.
  MediaMetadata? get media => _media;

  /// Whether a successfully probed source is committed.
  bool get hasMedia => _media != null;

  /// Whether the full-window replacement overlay is visible.
  bool get dropOverlayVisible => _dropOverlayVisible;

  /// Whether the newest replacement candidate is being probed.
  bool get probing => _probing;

  /// Latest structured probe failure, if any.
  MediaProbeFailure? get failure => _failure;

  /// Candidate path collected by a development fixture or future picker/drop.
  String? get candidatePath => _candidatePath;

  /// Shows the full-window replacement overlay.
  void showDropOverlay() {
    if (_dropOverlayVisible) {
      return;
    }
    _dropOverlayVisible = true;
    notifyListeners();
  }

  /// Dismisses replacement UI and invalidates any result still in flight.
  void hideDropOverlay() {
    if (!_dropOverlayVisible && !_probing) {
      return;
    }
    _probeGeneration += 1;
    _dropOverlayVisible = false;
    _probing = false;
    notifyListeners();
  }

  /// Sets the provisional path supplied by a future picker or desktop drop.
  void setCandidatePath(String path) {
    if (_candidatePath == path) {
      return;
    }
    _probeGeneration += 1;
    _candidatePath = path;
    _probing = false;
    _failure = null;
    notifyListeners();
  }

  /// Probes the current candidate and commits it only after success.
  Future<bool> probeCandidateSource() async {
    final path = _candidatePath;
    if (path == null || path.isEmpty) {
      _failure = const MediaProbeFailure(
        code: MediaProbeErrorCode.cannotOpenInput,
        diagnostic: 'No local media path is available for probing.',
      );
      notifyListeners();
      return false;
    }
    return replaceSource(path);
  }

  /// Probes [path] provisionally and atomically replaces committed metadata.
  Future<bool> replaceSource(String path) async {
    final generation = ++_probeGeneration;
    _candidatePath = path;
    _probing = true;
    _failure = null;
    notifyListeners();

    try {
      final media = await _probeService.probe(path);
      if (_disposed || generation != _probeGeneration) {
        return false;
      }
      _media = media;
      _candidatePath = media.path;
      _probing = false;
      _dropOverlayVisible = false;
      notifyListeners();
      return true;
    } on MediaProbeFailure catch (failure) {
      if (_disposed || generation != _probeGeneration) {
        return false;
      }
      _failure = failure;
    } on Object catch (error) {
      if (_disposed || generation != _probeGeneration) {
        return false;
      }
      _failure = MediaProbeFailure(
        code: MediaProbeErrorCode.unexpected,
        diagnostic: error.toString(),
      );
    }
    _probing = false;
    notifyListeners();
    return false;
  }

  @override
  void dispose() {
    _disposed = true;
    _probeGeneration += 1;
    super.dispose();
  }
}

class _PrototypeMediaProbeService implements MediaProbeService {
  const _PrototypeMediaProbeService();

  @override
  Future<String> defaultOutputPath(String path, MediaOutputMode mode) async =>
      switch (mode) {
        MediaOutputMode.videoWithAudio ||
        MediaOutputMode.videoOnly => '$path.mp4',
        MediaOutputMode.audioOnly => '$path.mp3',
      };

  @override
  Future<MediaBackendCapabilities> initializeBackend() async {
    return const MediaBackendCapabilities(
      ffmpegVersion: 'prototype',
      h264Available: true,
      aacAvailable: true,
      mp3Available: true,
    );
  }

  @override
  Future<MediaMetadata> probe(String path) async => MediaMetadata.prototype;
}
