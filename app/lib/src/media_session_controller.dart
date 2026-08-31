import 'package:flutter/foundation.dart';

import 'file_selection.dart';
import 'media_metadata.dart';
import 'media_probe_service.dart';

/// Owns provisional source probing and committed media-session metadata.
class MediaSessionController extends ChangeNotifier {
  /// Creates a media session around an injected probe boundary.
  factory MediaSessionController({
    required MediaProbeService probeService,
    SourceFilePicker? sourcePicker,
    MediaMetadata? initialMedia,
    String? candidatePath,
    bool initialDropOverlayVisible = false,
  }) {
    return MediaSessionController._(
      probeService,
      sourcePicker,
      initialMedia,
      candidatePath,
      initialDropOverlayVisible,
    );
  }

  MediaSessionController._(
    this._probeService,
    this._sourcePicker,
    this._media,
    this._candidatePath,
    this._dropOverlayVisible,
  );

  /// Creates deterministic presentation-only state for visual and widget tests.
  factory MediaSessionController.prototype({
    required bool initialHasMedia,
    bool initialDropOverlayVisible = false,
    SourceFilePicker sourcePicker = const PrototypeFileSelection(
      sourcePath: 'prototype:///ScreenRecording_08-13-2026.mov',
    ),
  }) {
    return MediaSessionController(
      probeService: const _PrototypeMediaProbeService(),
      sourcePicker: sourcePicker,
      initialMedia: initialHasMedia ? MediaMetadata.prototype : null,
      candidatePath: MediaMetadata.prototype.path,
      initialDropOverlayVisible: initialDropOverlayVisible,
    );
  }

  final MediaProbeService _probeService;
  final SourceFilePicker? _sourcePicker;
  MediaMetadata? _media;
  String? _candidatePath;
  bool _dropOverlayVisible;
  bool _probing = false;
  MediaProbeFailure? _failure;
  int _probeGeneration = 0;
  bool _disposed = false;
  bool _sourceChangesAllowed = true;

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

  /// Whether picker, drop, clear, and replacement operations are accepted.
  bool get sourceChangesAllowed => _sourceChangesAllowed;

  /// Coordinates source mutation availability with the active conversion job.
  void setSourceChangesAllowed(bool allowed) {
    if (_sourceChangesAllowed == allowed) {
      return;
    }
    _sourceChangesAllowed = allowed;
    if (!allowed) {
      _probeGeneration += 1;
      _dropOverlayVisible = false;
      _probing = false;
    }
    notifyListeners();
  }

  /// Shows the full-window replacement overlay.
  void showDropOverlay() {
    if (!_sourceChangesAllowed || _dropOverlayVisible) {
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
    if (!_sourceChangesAllowed || _candidatePath == path) {
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
    if (!_sourceChangesAllowed) {
      return false;
    }
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
    if (!_sourceChangesAllowed) {
      return false;
    }
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
    _dropOverlayVisible = true;
    notifyListeners();
    return false;
  }

  /// Opens the native picker and commits its result only after a successful probe.
  Future<bool> chooseSource() async {
    if (!_sourceChangesAllowed) {
      return false;
    }
    final picker = _sourcePicker;
    if (picker == null) {
      showDropOverlay();
      return false;
    }
    try {
      final path = await picker.pickSourceFile();
      if (_disposed || !_sourceChangesAllowed || path == null) {
        return false;
      }
      return await replaceSource(path);
    } on Object catch (error) {
      if (_disposed || !_sourceChangesAllowed) {
        return false;
      }
      _failure = MediaProbeFailure(
        code: MediaProbeErrorCode.unexpected,
        diagnostic: error.toString(),
      );
      _dropOverlayVisible = true;
      notifyListeners();
      return false;
    }
  }

  /// Clears committed and provisional source state while no conversion is active.
  bool clearSource() {
    if (!_sourceChangesAllowed || (_media == null && _candidatePath == null)) {
      return false;
    }
    _probeGeneration += 1;
    _media = null;
    _candidatePath = null;
    _dropOverlayVisible = false;
    _probing = false;
    _failure = null;
    notifyListeners();
    return true;
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
