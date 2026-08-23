import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'mf_tokens.dart';
import 'prototype_controllers.dart';
import 'prototype_screen.dart';
import 'prototype_state.dart';

/// Root widget for the fake-data M2 interaction prototype.
class MediaForgePrototypeApp extends StatefulWidget {
  /// Creates deterministic controllers for screenshots and interaction tests.
  const MediaForgePrototypeApp({
    required this.state,
    this.autoAdvanceProgress = false,
    this.showDropOverlay = false,
    this.showSettingsPopover = false,
    super.key,
  });

  /// Prototype state shown for the current process.
  final PrototypeState state;

  /// Whether fake conversion progress advances on a timer.
  final bool autoAdvanceProgress;

  /// Whether the fake full-window drop overlay starts visible.
  final bool showDropOverlay;

  /// Whether the settings popover starts visible.
  final bool showSettingsPopover;

  @override
  State<MediaForgePrototypeApp> createState() => _MediaForgePrototypeAppState();
}

class _MediaForgePrototypeAppState extends State<MediaForgePrototypeApp> {
  late final MediaSessionPrototypeController _mediaSession;
  late final PreviewPrototypeController _preview;
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
    _preview = PreviewPrototypeController();
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
          );
        },
      ),
    );
  }
}
