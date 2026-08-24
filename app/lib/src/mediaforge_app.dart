import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'media_kit_preview.dart';
import 'mf_tokens.dart';
import 'preview_controller.dart';
import 'prototype_controllers.dart';
import 'prototype_screen.dart';
import 'prototype_state.dart';

/// Flutter composition root for the M3 preview prototype.
class MediaForgePrototypeApp extends StatefulWidget {
  /// Creates controllers and an optional native preview for [previewSource].
  const MediaForgePrototypeApp({
    required this.state,
    this.autoAdvanceProgress = false,
    this.showDropOverlay = false,
    this.showSettingsPopover = false,
    this.previewSource,
    this.previewController,
    this.previewSurface,
    super.key,
  }) : assert(
         previewSurface == null || previewController != null,
         'A native preview surface requires its matching controller.',
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

  /// Optional preview state whose ownership transfers to this app root.
  final PreviewController? previewController;

  /// Optional native video surface paired with [previewController].
  final Widget? previewSurface;

  @override
  State<MediaForgePrototypeApp> createState() => _MediaForgePrototypeAppState();
}

class _MediaForgePrototypeAppState extends State<MediaForgePrototypeApp> {
  late final MediaSessionPrototypeController _mediaSession;
  late final PreviewController _preview;
  late final Widget? _nativePreviewSurface;
  late final TimelinePrototypeController _timeline;
  late final ConversionPrototypeController _conversion;
  late final SettingsPrototypeController _settings;
  late final Listenable _prototypeState;

  @override
  void initState() {
    super.initState();
    _mediaSession = MediaSessionPrototypeController(
      initialHasMedia: widget.state != PrototypeState.empty,
      initialDropOverlayVisible: widget.showDropOverlay,
    );
    final suppliedPreview = widget.previewController;
    final previewSource = widget.previewSource;
    if (suppliedPreview != null) {
      _preview = suppliedPreview;
      _nativePreviewSurface = widget.previewSurface;
    } else if (widget.state != PrototypeState.empty &&
        previewSource != null &&
        previewSource.isNotEmpty) {
      final nativePreview = MediaKitPreviewSession(source: previewSource);
      _preview = nativePreview.preview;
      _nativePreviewSurface = MediaKitVideoSurface(
        controller: nativePreview.video,
      );
    } else {
      _preview = PreviewPrototypeController();
      _nativePreviewSurface = null;
    }
    _timeline = TimelinePrototypeController();
    _conversion = ConversionPrototypeController(
      initiallyConverting: widget.state == PrototypeState.converting,
      autoAdvanceProgress: widget.autoAdvanceProgress,
    );
    _settings = SettingsPrototypeController(
      initiallyOpen: widget.showSettingsPopover,
    );
    _prototypeState = Listenable.merge(<Listenable>[
      _mediaSession,
      _preview,
      _timeline,
      _conversion,
      _settings,
    ]);
  }

  @override
  void dispose() {
    _settings.dispose();
    _conversion.dispose();
    _timeline.dispose();
    _preview.dispose();
    _mediaSession.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShadApp(
      title: 'MediaForge',
      theme: MfTheme.dark,
      darkTheme: MfTheme.dark,
      themeMode: ThemeMode.dark,
      home: ListenableBuilder(
        listenable: _prototypeState,
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
