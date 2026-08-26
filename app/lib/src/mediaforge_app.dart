import 'dart:async';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'conversion_controller.dart';
import 'conversion_service.dart';
import 'media_kit_preview.dart';
import 'media_probe_service.dart';
import 'media_session_controller.dart';
import 'mf_tokens.dart';
import 'preview_controller.dart';
import 'prototype_controllers.dart';
import 'prototype_screen.dart';
import 'prototype_state.dart';
import 'timeline_controller.dart';

/// Flutter composition root for native preview and backend-probed media state.
class MediaForgePrototypeApp extends StatefulWidget {
  /// Creates controllers and an optional native preview for [previewSource].
  const MediaForgePrototypeApp({
    required this.state,
    this.autoAdvanceProgress = false,
    this.showDropOverlay = false,
    this.showSettingsPopover = false,
    this.previewSource,
    this.mediaProbeService,
    this.conversionService,
    this.previewController,
    this.previewSurface,
    super.key,
  }) : assert(
         previewSurface == null || previewController != null,
         'A native preview surface requires its matching controller.',
       ),
       assert(
         conversionService == null || mediaProbeService != null,
         'Native conversion requires the matching media probe service.',
       );

  /// Prototype state shown for the current process.
  final PrototypeState state;

  /// Whether fake conversion progress advances on a timer.
  final bool autoAdvanceProgress;

  /// Whether the fake full-window drop overlay starts visible.
  final bool showDropOverlay;

  /// Whether the settings popover starts visible.
  final bool showSettingsPopover;

  /// File path or media_kit URI opened by the native preview adapter.
  final String? previewSource;

  /// Optional native probe boundary; omission retains deterministic visual data.
  final MediaProbeService? mediaProbeService;

  /// Optional native conversion boundary; omission retains fake progress.
  final ConversionService? conversionService;

  /// Optional preview state whose ownership transfers to this app root.
  final PreviewController? previewController;

  /// Optional native video surface paired with [previewController].
  final Widget? previewSurface;

  @override
  State<MediaForgePrototypeApp> createState() => _MediaForgePrototypeAppState();
}

class _MediaForgePrototypeAppState extends State<MediaForgePrototypeApp> {
  late final MediaSessionController _mediaSession;
  late PreviewController _preview;
  Widget? _nativePreviewSurface;
  String? _previewSourcePath;
  String? _timelineSourcePath;
  String? _conversionSourcePath;
  late final TimelineController _timeline;
  late final ConversionController _conversion;
  late final SettingsPrototypeController _settings;

  @override
  void initState() {
    super.initState();
    final probeService = widget.mediaProbeService;
    _mediaSession = probeService == null
        ? MediaSessionController.prototype(
            initialHasMedia: widget.state != PrototypeState.empty,
            initialDropOverlayVisible: widget.showDropOverlay,
          )
        : MediaSessionController(
            probeService: probeService,
            candidatePath: widget.previewSource,
            initialDropOverlayVisible: widget.showDropOverlay,
          );
    final suppliedPreview = widget.previewController;
    final previewSource = widget.previewSource;
    if (suppliedPreview != null) {
      _preview = suppliedPreview;
      _nativePreviewSurface = widget.previewSurface;
    } else if (probeService == null &&
        widget.state != PrototypeState.empty &&
        previewSource != null &&
        previewSource.isNotEmpty) {
      final nativePreview = MediaKitPreviewSession(source: previewSource);
      _preview = nativePreview.preview;
      _nativePreviewSurface = MediaKitVideoSurface(
        controller: nativePreview.video,
      );
      _previewSourcePath = previewSource;
    } else {
      _preview = PreviewPrototypeController();
      _nativePreviewSurface = null;
    }
    _timeline = TimelineController();
    final conversionService = widget.conversionService;
    _conversion = conversionService == null
        ? ConversionController.prototype(
            initiallyConverting: widget.state == PrototypeState.converting,
            autoAdvanceProgress: widget.autoAdvanceProgress,
          )
        : ConversionController(
            service: conversionService,
            outputPathService: probeService!,
          );
    _settings = SettingsPrototypeController(
      initiallyOpen: widget.showSettingsPopover,
    );
    _mediaSession.addListener(_handleMediaSessionChange);
    _preview.addListener(_handlePreviewChange);
    final initialMedia = _mediaSession.media;
    if (initialMedia != null) {
      _conversion.setMedia(initialMedia);
      _conversionSourcePath = initialMedia.path;
      _timelineSourcePath = initialMedia.path;
    }
    if (probeService != null &&
        previewSource != null &&
        previewSource.isNotEmpty) {
      unawaited(_mediaSession.replaceSource(previewSource));
    }
  }

  void _handleMediaSessionChange() {
    final media = _mediaSession.media;
    if (media == null) {
      return;
    }
    if (media.path != _conversionSourcePath) {
      _conversion.setMedia(media);
      _conversionSourcePath = media.path;
    }
    if (media.path != _timelineSourcePath) {
      _timeline.replaceSourceDuration(media.durationMs);
      _timelineSourcePath = media.path;
    }
    if (widget.mediaProbeService == null || media.path == _previewSourcePath) {
      return;
    }

    final previousPreview = _preview;
    final nativePreview = MediaKitPreviewSession(source: media.path);
    previousPreview.removeListener(_handlePreviewChange);
    setState(() {
      _preview = nativePreview.preview;
      _nativePreviewSurface = media.video == null
          ? null
          : MediaKitVideoSurface(controller: nativePreview.video);
      _previewSourcePath = media.path;
    });
    _preview.addListener(_handlePreviewChange);
    previousPreview.dispose();
  }

  void _handlePreviewChange() {
    _timeline.setPlayhead(_preview.positionMs);
  }

  @override
  void dispose() {
    _mediaSession.removeListener(_handleMediaSessionChange);
    _preview.removeListener(_handlePreviewChange);
    _settings.dispose();
    _conversion.dispose();
    _timeline.dispose();
    _preview.dispose();
    _mediaSession.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final presentationState = Listenable.merge(<Listenable>[
      _mediaSession,
      _preview,
      _timeline,
      _conversion,
      _settings,
    ]);
    return ShadApp(
      title: 'MediaForge',
      theme: MfTheme.dark,
      darkTheme: MfTheme.dark,
      themeMode: ThemeMode.dark,
      home: ListenableBuilder(
        listenable: presentationState,
        builder: (BuildContext context, Widget? child) {
          return MediaForgePrototypeScreen(
            mediaSession: _mediaSession,
            preview: _preview,
            timeline: _timeline,
            conversion: _conversion,
            settings: _settings,
            nativePreviewSurface: _nativePreviewSurface,
          );
        },
      ),
    );
  }
}
