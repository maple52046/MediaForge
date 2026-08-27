import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'conversion_controller.dart';
import 'conversion_service.dart';
import 'media_metadata.dart';
import 'media_session_controller.dart';
import 'media_time.dart';
import 'mf_icon.dart';
import 'mf_timeline.dart';
import 'mf_tokens.dart';
import 'preview_controller.dart';
import 'prototype_controllers.dart';
import 'timeline_controller.dart';

/// Interactive MediaForge workspace with optional native preview output.
class MediaForgePrototypeScreen extends StatelessWidget {
  /// Creates the presentation from focused controllers and native video edge.
  const MediaForgePrototypeScreen({
    required this.mediaSession,
    required this.preview,
    required this.timeline,
    required this.conversion,
    required this.settings,
    required this.nativePreviewSurface,
    super.key,
  });

  /// Fake source and drop-overlay state.
  final MediaSessionController mediaSession;

  /// Framework-free preview playback state.
  final PreviewController preview;

  /// Integer-millisecond trim and preview position state.
  final TimelineController timeline;

  /// Fake mode, progress, and cancellation state.
  final ConversionController conversion;

  /// Fake settings popover state.
  final SettingsPrototypeController settings;

  /// media_kit video widget composed outside the framework-free controller.
  final Widget? nativePreviewSurface;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: MfPalette.background,
      child: Stack(
        children: [
          Column(
            children: [
              _Header(settings: settings),
              Expanded(
                child: mediaSession.hasMedia
                    ? _LoadedWorkspace(
                        mediaSession: mediaSession,
                        preview: preview,
                        nativePreviewSurface: nativePreviewSurface,
                        timeline: timeline,
                        conversion: conversion,
                      )
                    : _EmptyWorkspace(mediaSession: mediaSession),
              ),
            ],
          ),
          if (settings.popoverOpen)
            Positioned(
              top: 46,
              right: MfSpacing.md,
              child: _SettingsPopover(settings: settings),
            ),
          if (mediaSession.dropOverlayVisible)
            Positioned.fill(child: _DropOverlay(mediaSession: mediaSession)),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.settings});

  final SettingsPrototypeController settings;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('app-header'),
      height: 52,
      padding: const EdgeInsets.only(left: 84, right: MfSpacing.md),
      decoration: const BoxDecoration(
        color: MfPalette.surface,
        border: Border(bottom: BorderSide(color: MfPalette.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: MfPalette.accent,
              borderRadius: BorderRadius.circular(MfRadius.md),
            ),
            child: const Center(child: MfIcon(MfIconData.play, size: 15)),
          ),
          const SizedBox(width: MfSpacing.sm),
          const Text(
            'MediaForge',
            style: TextStyle(
              color: MfPalette.foreground,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
          const _HeaderStatus(),
          const SizedBox(width: MfSpacing.md),
          ShadButton.ghost(
            key: const Key('settings-button'),
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: MfSpacing.sm),
            onPressed: settings.togglePopover,
            child: const Text('Settings'),
          ),
        ],
      ),
    );
  }
}

class _HeaderStatus extends StatelessWidget {
  const _HeaderStatus();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: MfPalette.accent,
            shape: BoxShape.circle,
          ),
          child: SizedBox(width: 6, height: 6),
        ),
        SizedBox(width: MfSpacing.xs),
        Text(
          'UI prototype',
          style: TextStyle(color: MfPalette.muted, fontSize: 12),
        ),
      ],
    );
  }
}

class _SettingsPopover extends StatelessWidget {
  const _SettingsPopover({required this.settings});

  final SettingsPrototypeController settings;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('settings-popover'),
      width: 280,
      padding: const EdgeInsets.all(MfSpacing.md),
      decoration: BoxDecoration(
        color: MfPalette.elevated,
        borderRadius: BorderRadius.circular(MfRadius.lg),
        border: Border.all(color: MfPalette.accent),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 28,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Interface settings',
                  style: TextStyle(
                    color: MfPalette.foreground,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ShadButton.ghost(
                key: const Key('close-settings'),
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: MfSpacing.xs),
                onPressed: settings.closePopover,
                child: const Text('Close'),
              ),
            ],
          ),
          const SizedBox(height: MfSpacing.sm),
          const _SectionLabel('APPEARANCE'),
          const SizedBox(height: MfSpacing.xs),
          _PopoverChoices<PrototypeThemePreference>(
            values: PrototypeThemePreference.values,
            selected: settings.theme,
            labelFor: _themeLabel,
            keyFor: (PrototypeThemePreference value) =>
                Key('theme-${value.name}'),
            onSelected: settings.selectTheme,
          ),
          const SizedBox(height: MfSpacing.md),
          const _SectionLabel('LANGUAGE'),
          const SizedBox(height: MfSpacing.xs),
          _PopoverChoices<PrototypeLanguagePreference>(
            values: PrototypeLanguagePreference.values,
            selected: settings.language,
            labelFor: _languageLabel,
            keyFor: (PrototypeLanguagePreference value) =>
                Key('language-${value.name}'),
            onSelected: settings.selectLanguage,
          ),
          const SizedBox(height: MfSpacing.sm),
          const Text(
            'Prototype choices are not persisted yet.',
            style: TextStyle(color: MfPalette.faint, fontSize: 10),
          ),
        ],
      ),
    );
  }

  static String _themeLabel(PrototypeThemePreference value) => switch (value) {
    PrototypeThemePreference.system => 'System',
    PrototypeThemePreference.light => 'Light',
    PrototypeThemePreference.dark => 'Dark',
  };

  static String _languageLabel(PrototypeLanguagePreference value) =>
      switch (value) {
        PrototypeLanguagePreference.system => 'System',
        PrototypeLanguagePreference.traditionalChinese => '繁中',
        PrototypeLanguagePreference.english => 'English',
      };
}

class _PopoverChoices<T> extends StatelessWidget {
  const _PopoverChoices({
    required this.values,
    required this.selected,
    required this.labelFor,
    required this.keyFor,
    required this.onSelected,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelFor;
  final Key Function(T value) keyFor;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < values.length; index++) ...[
          if (index > 0) const SizedBox(width: MfSpacing.xxs),
          Expanded(
            child: _ModeOption(
              key: keyFor(values[index]),
              label: labelFor(values[index]),
              selected: values[index] == selected,
              onPressed: () => onSelected(values[index]),
            ),
          ),
        ],
      ],
    );
  }
}

class _EmptyWorkspace extends StatelessWidget {
  const _EmptyWorkspace({required this.mediaSession});

  final MediaSessionController mediaSession;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(MfSpacing.lg),
      child: _InteractiveDropSurface(mediaSession: mediaSession),
    );
  }
}

class _InteractiveDropSurface extends StatefulWidget {
  const _InteractiveDropSurface({required this.mediaSession});

  final MediaSessionController mediaSession;

  @override
  State<_InteractiveDropSurface> createState() =>
      _InteractiveDropSurfaceState();
}

class _InteractiveDropSurfaceState extends State<_InteractiveDropSurface> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'Open media drop zone');
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final highlighted = _hovered || _pressed || _focused;
    return Semantics(
      button: true,
      label: 'Open or drop a video or audio file',
      onTap: widget.mediaSession.showDropOverlay,
      child: Focus(
        focusNode: _focusNode,
        onFocusChange: (bool focused) => setState(() => _focused = focused),
        onKeyEvent: (FocusNode node, KeyEvent event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.space)) {
            widget.mediaSession.showDropOverlay();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: Listener(
            onPointerDown: (_) => setState(() => _pressed = true),
            onPointerUp: (_) => setState(() => _pressed = false),
            onPointerCancel: (_) => setState(() => _pressed = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _focusNode.requestFocus();
                widget.mediaSession.showDropOverlay();
              },
              child: AnimatedContainer(
                key: const Key('empty-drop-zone'),
                duration: MfMotion.fast,
                decoration: BoxDecoration(
                  color: highlighted ? MfPalette.elevated : MfPalette.surface,
                  borderRadius: BorderRadius.circular(MfRadius.xl),
                  border: Border.all(
                    color: highlighted ? MfPalette.accent : MfPalette.border,
                  ),
                ),
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: CustomPaint(painter: _DotPainter()),
                    ),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: MfPalette.surface,
                                borderRadius: BorderRadius.circular(
                                  MfRadius.xl,
                                ),
                                border: Border.all(color: MfPalette.border),
                              ),
                              child: const Center(
                                child: MfIcon(
                                  MfIconData.upload,
                                  size: 30,
                                  color: MfPalette.accentBright,
                                ),
                              ),
                            ),
                            const SizedBox(height: MfSpacing.xl),
                            const Text(
                              'Drop a video or audio file',
                              style: TextStyle(
                                color: MfPalette.foreground,
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: MfSpacing.xs),
                            const Text(
                              'MOV, MP4, M4A, WAV, and MP3 · one source at a time',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: MfPalette.muted,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: MfSpacing.xl),
                            ShadButton(
                              key: const Key('open-media'),
                              width: 212,
                              height: 38,
                              onPressed: widget.mediaSession.showDropOverlay,
                              leading: const MfIcon(
                                MfIconData.upload,
                                size: 17,
                              ),
                              child: const Text('Open media'),
                            ),
                            const SizedBox(height: MfSpacing.md),
                            const Text(
                              'or choose File → Open',
                              style: TextStyle(
                                color: MfPalette.faint,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Positioned(
                      left: MfSpacing.lg,
                      bottom: MfSpacing.md,
                      child: Text(
                        'Local processing · your media never leaves this Mac',
                        style: TextStyle(color: MfPalette.faint, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DropOverlay extends StatelessWidget {
  const _DropOverlay({required this.mediaSession});

  final MediaSessionController mediaSession;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const Key('drop-overlay'),
      color: const Color(0xD90B0D10),
      child: Center(
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(MfSpacing.xxl),
          decoration: BoxDecoration(
            color: MfPalette.elevated,
            borderRadius: BorderRadius.circular(MfRadius.xl),
            border: Border.all(color: MfPalette.accentBright, width: 2),
            boxShadow: const [
              BoxShadow(color: Color(0x667C5CFC), blurRadius: 40),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MfIcon(
                MfIconData.upload,
                size: 42,
                color: MfPalette.accentBright,
              ),
              const SizedBox(height: MfSpacing.lg),
              Text(
                mediaSession.hasMedia
                    ? 'Drop to replace the current source'
                    : 'Drop media anywhere in this window',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: MfPalette.foreground,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: MfSpacing.xs),
              const Text(
                'The current source remains unchanged until metadata validation succeeds.',
                textAlign: TextAlign.center,
                style: TextStyle(color: MfPalette.muted, fontSize: 12),
              ),
              if (mediaSession.failure case final failure?) ...[
                const SizedBox(height: MfSpacing.sm),
                Text(
                  '${failure.code.name}: ${failure.diagnostic}',
                  key: const Key('source-probe-error'),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: MfPalette.muted, fontSize: 11),
                ),
              ],
              const SizedBox(height: MfSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ShadButton.outline(
                    key: const Key('cancel-drop'),
                    height: 36,
                    onPressed: mediaSession.hideDropOverlay,
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: MfSpacing.sm),
                  ShadButton(
                    key: const Key('accept-drop'),
                    height: 36,
                    onPressed: mediaSession.probing
                        ? null
                        : () => unawaited(mediaSession.probeCandidateSource()),
                    leading: const MfIcon(MfIconData.upload, size: 16),
                    child: Text(
                      mediaSession.probing
                          ? 'Inspecting media…'
                          : 'Validate source',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadedWorkspace extends StatelessWidget {
  const _LoadedWorkspace({
    required this.mediaSession,
    required this.preview,
    required this.nativePreviewSurface,
    required this.timeline,
    required this.conversion,
  });

  final MediaSessionController mediaSession;
  final PreviewController preview;
  final Widget? nativePreviewSurface;
  final TimelineController timeline;
  final ConversionController conversion;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PreviewColumn(
            preview: preview,
            nativePreviewSurface: nativePreviewSurface,
            timeline: timeline,
          ),
        ),
        SizedBox(
          key: const Key('conversion-pane'),
          width: 360,
          child: _ConversionPane(
            mediaSession: mediaSession,
            timeline: timeline,
            conversion: conversion,
          ),
        ),
      ],
    );
  }
}

class _PreviewColumn extends StatelessWidget {
  const _PreviewColumn({
    required this.preview,
    required this.nativePreviewSurface,
    required this.timeline,
  });

  final PreviewController preview;
  final Widget? nativePreviewSurface;
  final TimelineController timeline;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MfSpacing.lg,
        MfSpacing.md,
        MfSpacing.lg,
        MfSpacing.lg,
      ),
      child: Column(
        children: [
          Expanded(
            child: _PreviewSurface(
              preview: preview,
              nativePreviewSurface: nativePreviewSurface,
              timeline: timeline,
            ),
          ),
          const SizedBox(height: MfSpacing.md),
          SizedBox(
            key: const Key('timeline-panel'),
            height: 142,
            child: _TimelinePanel(preview: preview, timeline: timeline),
          ),
        ],
      ),
    );
  }
}

class _PreviewSurface extends StatelessWidget {
  const _PreviewSurface({
    required this.preview,
    required this.nativePreviewSurface,
    required this.timeline,
  });

  final PreviewController preview;
  final Widget? nativePreviewSurface;
  final TimelineController timeline;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: MfPalette.surface,
        borderRadius: BorderRadius.circular(MfRadius.lg),
        border: Border.all(color: MfPalette.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MfRadius.lg),
        child: Stack(
          children: [
            const Positioned.fill(child: ColoredBox(color: Color(0xFF07080A))),
            Positioned.fill(
              child: _PreviewBody(
                preview: preview,
                nativePreviewSurface: nativePreviewSurface,
              ),
            ),
            if (_previewCanInteract(preview))
              Center(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Color(0xCC111419),
                    shape: BoxShape.circle,
                  ),
                  child: ShadButton.ghost(
                    key: const Key('preview-center-play'),
                    width: 48,
                    height: 48,
                    padding: EdgeInsets.zero,
                    onPressed: preview.togglePlayback,
                    child: MfIcon(
                      preview.playing ? MfIconData.pause : MfIconData.play,
                      size: 24,
                    ),
                  ),
                ),
              ),
            Positioned(
              top: MfSpacing.sm,
              left: MfSpacing.sm,
              child: _Pill(label: _previewPillLabel(preview)),
            ),
            Positioned(
              right: MfSpacing.sm,
              bottom: MfSpacing.sm,
              left: MfSpacing.sm,
              child: _PreviewControls(preview: preview, timeline: timeline),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewControls extends StatelessWidget {
  const _PreviewControls({required this.preview, required this.timeline});

  final PreviewController preview;
  final TimelineController timeline;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: MfSpacing.xs),
      decoration: BoxDecoration(
        color: const Color(0xE6111419),
        borderRadius: BorderRadius.circular(MfRadius.md),
        border: Border.all(color: MfPalette.border),
      ),
      child: Row(
        children: [
          ShadButton.ghost(
            key: const Key('preview-play'),
            width: 28,
            height: 28,
            padding: EdgeInsets.zero,
            onPressed: _previewCanInteract(preview)
                ? preview.togglePlayback
                : null,
            child: MfIcon(
              preview.playing ? MfIconData.pause : MfIconData.play,
              size: 17,
            ),
          ),
          const SizedBox(width: MfSpacing.xs),
          Text(
            formatMediaTime(preview.positionMs),
            key: const Key('preview-position'),
            style: const TextStyle(color: MfPalette.foreground, fontSize: 12),
          ),
          const SizedBox(width: MfSpacing.xs),
          Text(
            '/  ${formatMediaTime(preview.durationMs > 0 ? preview.durationMs : timeline.durationMs)}',
            style: const TextStyle(color: MfPalette.faint, fontSize: 12),
          ),
          const Spacer(),
          ShadButton.ghost(
            key: const Key('preview-volume'),
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: MfSpacing.xs),
            onPressed: preview.availability == PreviewAvailability.unavailable
                ? null
                : () => preview.setVolume(
                    preview.volumePercent >= 100
                        ? 0
                        : preview.volumePercent + 11,
                  ),
            child: Text('Volume  ${preview.volumePercent}%'),
          ),
        ],
      ),
    );
  }
}

class _PreviewBody extends StatelessWidget {
  const _PreviewBody({
    required this.preview,
    required this.nativePreviewSurface,
  });

  final PreviewController preview;
  final Widget? nativePreviewSurface;

  @override
  Widget build(BuildContext context) {
    return switch (preview.availability) {
      PreviewAvailability.placeholder => const _PrototypePortraitPreview(),
      PreviewAvailability.opening => const _PreviewMessage(
        key: Key('preview-opening'),
        title: 'Opening preview…',
        detail: 'Preparing native H.264 / HEVC playback',
      ),
      PreviewAvailability.ready =>
        nativePreviewSurface ??
            const _PreviewMessage(
              title: 'Preview output unavailable',
              detail: 'Conversion remains available for this source.',
            ),
      PreviewAvailability.unavailable => const _PreviewMessage(
        key: Key('preview-fallback'),
        title: 'Preview unavailable',
        detail: 'Conversion remains available for this source.',
      ),
    };
  }
}

class _PrototypePortraitPreview extends StatelessWidget {
  const _PrototypePortraitPreview();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: 1242 / 2778,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: MfSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MfRadius.md),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                MfPalette.elevated,
                MfPalette.accent,
                MfPalette.background,
              ],
              stops: [0, 0.58, 1],
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x337C5CFC), blurRadius: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewMessage extends StatelessWidget {
  const _PreviewMessage({required this.title, required this.detail, super.key});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        liveRegion: true,
        label: '$title. $detail',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: MfPalette.foreground,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: MfSpacing.xs),
            Text(
              detail,
              style: const TextStyle(color: MfPalette.muted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

bool _previewCanInteract(PreviewController preview) =>
    preview.availability == PreviewAvailability.placeholder ||
    preview.availability == PreviewAvailability.ready;

String _previewPillLabel(PreviewController preview) =>
    switch (preview.availability) {
      PreviewAvailability.placeholder => 'HEVC  ·  1242 × 2778',
      PreviewAvailability.opening => 'Opening native preview',
      PreviewAvailability.ready => 'Native preview  ·  Fit',
      PreviewAvailability.unavailable => 'Preview unavailable',
    };

class _TimelinePanel extends StatelessWidget {
  const _TimelinePanel({required this.preview, required this.timeline});

  final PreviewController preview;
  final TimelineController timeline;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: MfPalette.surface,
        borderRadius: BorderRadius.circular(MfRadius.lg),
        border: Border.all(color: MfPalette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          MfSpacing.md,
          MfSpacing.sm,
          MfSpacing.md,
          MfSpacing.sm,
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Text(
                  'Trim range',
                  style: TextStyle(
                    color: MfPalette.foreground,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${formatMediaTime(timeline.selectedDurationMs)} selected',
                  style: const TextStyle(color: MfPalette.muted, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: MfSpacing.xxs),
            Expanded(
              child: MfTimeline(
                durationMs: timeline.durationMs,
                startMs: timeline.startMs,
                endMs: timeline.endMs,
                playheadMs: timeline.playheadMs,
                onStartChanged: (int valueMs) {
                  timeline.setStart(valueMs);
                  preview.seek(timeline.startMs);
                },
                onEndChanged: (int valueMs) {
                  timeline.setEnd(valueMs);
                  preview.seek(timeline.endMs);
                },
                onPlayheadChanged: (int valueMs) {
                  timeline.setPlayhead(valueMs);
                  preview.seek(valueMs);
                },
              ),
            ),
            const SizedBox(height: MfSpacing.xxs),
            Row(
              children: [
                _TimeField(
                  inputKey: const Key('start-time-input'),
                  label: 'START',
                  valueMs: timeline.startMs,
                  onSubmitted: (String value) {
                    final committed = timeline.commitStartText(value);
                    if (committed != null) {
                      preview.seek(committed);
                    }
                    return committed;
                  },
                ),
                const SizedBox(width: MfSpacing.xs),
                _TimeField(
                  inputKey: const Key('end-time-input'),
                  label: 'END',
                  valueMs: timeline.endMs,
                  onSubmitted: (String value) {
                    final committed = timeline.commitEndText(value);
                    if (committed != null) {
                      preview.seek(committed);
                    }
                    return committed;
                  },
                ),
                const Spacer(),
                _CompactAction(
                  key: const Key('set-start'),
                  label: 'Set Start',
                  onPressed: timeline.setStartFromPlayhead,
                ),
                const SizedBox(width: MfSpacing.xxs),
                _CompactAction(
                  key: const Key('set-end'),
                  label: 'Set End',
                  onPressed: timeline.setEndFromPlayhead,
                ),
                const SizedBox(width: MfSpacing.xxs),
                _CompactAction(
                  key: const Key('reset-trim'),
                  label: 'Reset',
                  onPressed: () {
                    timeline.reset();
                    preview.seek(0);
                  },
                ),
                const SizedBox(width: MfSpacing.xxs),
                _CompactAction(
                  key: const Key('play-selection'),
                  label: 'Play Selection',
                  emphasized: true,
                  onPressed: () =>
                      preview.playSelection(timeline.startMs, timeline.endMs),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeField extends StatefulWidget {
  const _TimeField({
    required this.inputKey,
    required this.label,
    required this.valueMs,
    required this.onSubmitted,
  });

  final Key inputKey;
  final String label;
  final int valueMs;
  final int? Function(String value) onSubmitted;

  @override
  State<_TimeField> createState() => _TimeFieldState();
}

class _TimeFieldState extends State<_TimeField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _valid = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formattedValue);
    _focusNode = FocusNode(debugLabel: 'Trim ${widget.label} time');
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant _TimeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.valueMs != widget.valueMs && !_focusNode.hasFocus) {
      _replaceText(_formattedValue);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  String get _formattedValue =>
      formatMediaTime(widget.valueMs, includeMilliseconds: true);

  void _handleFocusChange() {
    if (!_focusNode.hasFocus && !_valid) {
      setState(() {
        _valid = true;
        _replaceText(_formattedValue);
      });
    }
  }

  void _submit(String value) {
    final committed = widget.onSubmitted(value);
    setState(() {
      _valid = committed != null;
      if (committed != null) {
        _replaceText(formatMediaTime(committed, includeMilliseconds: true));
      }
    });
  }

  void _replaceText(String value) {
    _controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Trim ${widget.label.toLowerCase()} time',
      textField: true,
      child: ShadInput(
        key: widget.inputKey,
        controller: _controller,
        focusNode: _focusNode,
        constraints: const BoxConstraints.tightFor(width: 118, height: 32),
        padding: EdgeInsets.zero,
        inputPadding: const EdgeInsets.symmetric(horizontal: MfSpacing.xxs),
        gap: MfSpacing.xxs,
        leading: Text(
          widget.label,
          style: const TextStyle(
            color: MfPalette.faint,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: TextStyle(
          color: _valid ? MfPalette.foreground : MfPalette.accentBright,
          fontSize: 10,
        ),
        cursorColor: MfPalette.accentBright,
        textInputAction: TextInputAction.done,
        autocorrect: false,
        enableSuggestions: false,
        onEditingComplete: () {},
        onPressedOutside: (_) => _focusNode.unfocus(),
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.allow(RegExp(r'[0-9:.]')),
          LengthLimitingTextInputFormatter(24),
        ],
        onChanged: (_) {
          if (!_valid) {
            setState(() => _valid = true);
          }
        },
        onSubmitted: _submit,
      ),
    );
  }
}

class _CompactAction extends StatefulWidget {
  const _CompactAction({
    required this.label,
    required this.onPressed,
    this.emphasized = false,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final bool emphasized;

  @override
  State<_CompactAction> createState() => _CompactActionState();
}

class _CompactActionState extends State<_CompactAction> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'Timeline action');
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final highlighted = widget.emphasized || _hovered || _pressed || _focused;
    return Semantics(
      button: true,
      label: widget.label,
      onTap: widget.onPressed,
      child: Focus(
        focusNode: _focusNode,
        onFocusChange: (bool focused) => setState(() => _focused = focused),
        onKeyEvent: (FocusNode node, KeyEvent event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.space)) {
            widget.onPressed();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: Listener(
            onPointerDown: (_) => setState(() => _pressed = true),
            onPointerUp: (_) => setState(() => _pressed = false),
            onPointerCancel: (_) => setState(() => _pressed = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _focusNode.requestFocus();
                widget.onPressed();
              },
              child: AnimatedContainer(
                duration: MfMotion.fast,
                width: widget.emphasized ? 88 : 58,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: highlighted ? MfPalette.elevated : MfPalette.surface,
                  borderRadius: BorderRadius.circular(MfRadius.sm),
                  border: Border.all(
                    color: _focused || widget.emphasized
                        ? MfPalette.accent
                        : MfPalette.border,
                  ),
                ),
                child: Text(
                  widget.label,
                  maxLines: 1,
                  style: TextStyle(
                    color: highlighted ? MfPalette.foreground : MfPalette.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConversionPane extends StatelessWidget {
  const _ConversionPane({
    required this.mediaSession,
    required this.timeline,
    required this.conversion,
  });

  final MediaSessionController mediaSession;
  final TimelineController timeline;
  final ConversionController conversion;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: MfPalette.surface,
        border: Border(left: BorderSide(color: MfPalette.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(MfSpacing.lg),
        child: conversion.converting
            ? _ConvertingContent(
                mediaSession: mediaSession,
                timeline: timeline,
                conversion: conversion,
              )
            : _ReadyContent(
                mediaSession: mediaSession,
                timeline: timeline,
                conversion: conversion,
              ),
      ),
    );
  }
}

class _ReadyContent extends StatelessWidget {
  const _ReadyContent({
    required this.mediaSession,
    required this.timeline,
    required this.conversion,
  });

  final MediaSessionController mediaSession;
  final TimelineController timeline;
  final ConversionController conversion;

  @override
  Widget build(BuildContext context) {
    final values = _ModePresentation.fromMode(conversion.mode);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PaneTitle(
          title: 'Export',
          caption: 'Choose a format and destination',
        ),
        const SizedBox(height: MfSpacing.lg),
        const _SectionLabel('SOURCE'),
        const SizedBox(height: MfSpacing.xs),
        _SourceSummary(
          media: mediaSession.media!,
          replaceEnabled: true,
          onReplace: mediaSession.showDropOverlay,
        ),
        const SizedBox(height: MfSpacing.lg),
        const _SectionLabel('OUTPUT MODE'),
        const SizedBox(height: MfSpacing.xs),
        _SegmentedModes(conversion: conversion),
        const SizedBox(height: MfSpacing.md),
        _OptionRow(label: 'Container', value: values.container),
        _OptionRow(label: 'Video', value: values.video),
        _OptionRow(label: 'Audio', value: values.audio),
        const SizedBox(height: MfSpacing.md),
        const _SectionLabel('DESTINATION'),
        const SizedBox(height: MfSpacing.xs),
        _DestinationField(outputPath: conversion.outputPath),
        if (conversion.failure case final failure?) ...[
          const SizedBox(height: MfSpacing.xs),
          Text(
            failure.code.name,
            key: const Key('conversion-error'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: MfPalette.accentBright, fontSize: 10),
          ),
        ] else if (conversion.completedOutputPath != null) ...[
          const SizedBox(height: MfSpacing.xs),
          const Text(
            'Conversion completed',
            key: Key('conversion-completed'),
            style: TextStyle(color: MfPalette.accentBright, fontSize: 10),
          ),
        ] else if (conversion.jobState == ConversionJobState.cancelled) ...[
          const SizedBox(height: MfSpacing.xs),
          const Text(
            'Conversion cancelled',
            key: Key('conversion-cancelled'),
            style: TextStyle(color: MfPalette.muted, fontSize: 10),
          ),
        ],
        const Spacer(),
        Row(
          children: [
            const Text(
              'Estimated size',
              style: TextStyle(color: MfPalette.faint, fontSize: 11),
            ),
            const Spacer(),
            Text(
              values.estimatedSize,
              style: const TextStyle(color: MfPalette.muted, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: MfSpacing.sm),
        ShadButton(
          key: const Key('start-conversion'),
          width: double.infinity,
          height: 40,
          onPressed: conversion.canStart
              ? () async {
                  await conversion.start(
                    startMs: timeline.startMs,
                    endMs: timeline.endMs,
                  );
                }
              : null,
          child: Text(values.actionLabel),
        ),
      ],
    );
  }
}

class _ConvertingContent extends StatelessWidget {
  const _ConvertingContent({
    required this.mediaSession,
    required this.timeline,
    required this.conversion,
  });

  final MediaSessionController mediaSession;
  final TimelineController timeline;
  final ConversionController conversion;

  @override
  Widget build(BuildContext context) {
    final percent = (conversion.progress * 100).round();
    final hasBackendSample = conversion.totalMs > 0;
    final totalMs = hasBackendSample
        ? conversion.totalMs
        : timeline.selectedDurationMs;
    final processedMs = hasBackendSample
        ? conversion.processedMs
        : (totalMs * conversion.progress).round();
    final telemetry = <String>[
      if (conversion.framesPerSecond case final framesPerSecond?)
        '${framesPerSecond.toStringAsFixed(1)} fps',
      if (conversion.speed case final speed?) '${speed.toStringAsFixed(1)}×',
    ].join('  ·  ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PaneTitle(
          title: 'Converting',
          caption: 'Hardware-accelerated H.264',
        ),
        const SizedBox(height: MfSpacing.xl),
        _SourceSummary(
          media: mediaSession.media!,
          replaceEnabled: false,
          onReplace: mediaSession.showDropOverlay,
        ),
        const SizedBox(height: MfSpacing.xl),
        Row(
          children: [
            Text(
              conversion.cancelling ? 'Cancelling' : 'Encoding video',
              key: const Key('conversion-stage'),
              style: const TextStyle(
                color: MfPalette.foreground,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '$percent%',
              key: const Key('progress-percent'),
              style: const TextStyle(
                color: MfPalette.accentBright,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: MfSpacing.sm),
        _ProgressTrack(progress: conversion.progress),
        const SizedBox(height: MfSpacing.sm),
        Row(
          children: [
            Expanded(
              child: Text(
                '${(processedMs / 1000).toStringAsFixed(3)} / '
                '${(totalMs / 1000).toStringAsFixed(3)} sec',
                key: const Key('progress-time'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: MfPalette.muted, fontSize: 10),
              ),
            ),
            const SizedBox(width: MfSpacing.sm),
            Expanded(
              child: Text(
                telemetry.isEmpty ? '—' : telemetry,
                key: const Key('progress-telemetry'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: const TextStyle(color: MfPalette.muted, fontSize: 10),
              ),
            ),
          ],
        ),
        const SizedBox(height: MfSpacing.xxl),
        const _ConversionStep(active: false, label: 'Preparing media'),
        const SizedBox(height: MfSpacing.md),
        const _ConversionStep(active: true, label: 'Encoding H.264 + AAC'),
        const SizedBox(height: MfSpacing.md),
        const _ConversionStep(active: false, label: 'Finalizing MP4'),
        const Spacer(),
        const Text(
          'Writing to a protected temporary file. Your existing destination remains unchanged until conversion succeeds.',
          style: TextStyle(color: MfPalette.faint, fontSize: 11, height: 1.45),
        ),
        const SizedBox(height: MfSpacing.md),
        ShadButton.outline(
          key: const Key('cancel-conversion'),
          width: double.infinity,
          height: 40,
          onPressed: conversion.canCancel
              ? () async {
                  await conversion.cancel();
                }
              : null,
          child: Text(
            conversion.cancelling ? 'Cancelling…' : 'Cancel conversion',
          ),
        ),
      ],
    );
  }
}

class _PaneTitle extends StatelessWidget {
  const _PaneTitle({required this.title, required this.caption});

  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: MfPalette.foreground,
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.35,
          ),
        ),
        const SizedBox(height: MfSpacing.xxs),
        Text(
          caption,
          style: const TextStyle(color: MfPalette.muted, fontSize: 12),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: MfPalette.faint,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _SourceSummary extends StatelessWidget {
  const _SourceSummary({
    required this.media,
    required this.replaceEnabled,
    required this.onReplace,
  });

  final MediaMetadata media;
  final bool replaceEnabled;
  final VoidCallback onReplace;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(MfSpacing.sm),
      decoration: BoxDecoration(
        color: MfPalette.elevated,
        borderRadius: BorderRadius.circular(MfRadius.md),
        border: Border.all(color: MfPalette.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  media.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: MfPalette.foreground,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: MfSpacing.xxs),
                Text(
                  _sourceDescription(media),
                  style: const TextStyle(color: MfPalette.muted, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(width: MfSpacing.xs),
          if (replaceEnabled)
            ShadButton.ghost(
              key: const Key('replace-source'),
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: MfSpacing.xs),
              onPressed: onReplace,
              child: const Text('Replace'),
            )
          else
            const Text(
              'Source locked',
              style: TextStyle(color: MfPalette.faint, fontSize: 10),
            ),
        ],
      ),
    );
  }
}

String _sourceDescription(MediaMetadata media) {
  final codecs = <String>[
    if (media.video case final video?) video.codec.toUpperCase(),
    if (media.audio case final audio?) audio.codec.toUpperCase(),
  ];
  final sizeMegabytes = media.fileSizeBytes / (1024 * 1024);
  return '${codecs.join(' · ')} · ${sizeMegabytes.toStringAsFixed(1)} MB · '
      '${formatMediaTime(media.durationMs)}';
}

class _SegmentedModes extends StatelessWidget {
  const _SegmentedModes({required this.conversion});

  final ConversionController conversion;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(MfSpacing.xxs),
      decoration: BoxDecoration(
        color: MfPalette.background,
        borderRadius: BorderRadius.circular(MfRadius.md),
        border: Border.all(color: MfPalette.border),
      ),
      child: Row(
        children: [
          for (final mode in conversion.availableModes)
            Expanded(
              child: _ModeOption(
                key: Key('mode-${mode.name}'),
                label: _modeLabel(mode),
                selected: mode == conversion.mode,
                onPressed: () => conversion.selectMode(mode),
              ),
            ),
        ],
      ),
    );
  }

  static String _modeLabel(MediaOutputMode mode) => switch (mode) {
    MediaOutputMode.videoWithAudio => 'Video + Audio',
    MediaOutputMode.videoOnly => 'Video Only',
    MediaOutputMode.audioOnly => 'Audio',
  };
}

class _ModeOption extends StatefulWidget {
  const _ModeOption({
    required this.label,
    required this.selected,
    required this.onPressed,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  State<_ModeOption> createState() => _ModeOptionState();
}

class _ModeOptionState extends State<_ModeOption> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'Output mode');
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final highlighted = widget.selected || _hovered || _pressed || _focused;
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      onTap: widget.onPressed,
      child: Focus(
        focusNode: _focusNode,
        onFocusChange: (bool focused) => setState(() => _focused = focused),
        onKeyEvent: (FocusNode node, KeyEvent event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.space)) {
            widget.onPressed();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: Listener(
            onPointerDown: (_) => setState(() => _pressed = true),
            onPointerUp: (_) => setState(() => _pressed = false),
            onPointerCancel: (_) => setState(() => _pressed = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _focusNode.requestFocus();
                widget.onPressed();
              },
              child: AnimatedContainer(
                duration: MfMotion.fast,
                height: 30,
                decoration: BoxDecoration(
                  color: highlighted
                      ? MfPalette.elevated
                      : const Color(0x00000000),
                  borderRadius: BorderRadius.circular(MfRadius.sm),
                  border: _focused
                      ? Border.all(color: MfPalette.accent)
                      : widget.selected
                      ? Border.all(color: MfPalette.border)
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  widget.label,
                  maxLines: 1,
                  style: TextStyle(
                    color: highlighted ? MfPalette.foreground : MfPalette.faint,
                    fontSize: 10,
                    fontWeight: widget.selected
                        ? FontWeight.w600
                        : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(color: MfPalette.muted, fontSize: 11),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(color: MfPalette.foreground, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _DestinationField extends StatelessWidget {
  const _DestinationField({required this.outputPath});

  final String? outputPath;

  @override
  Widget build(BuildContext context) {
    final path = outputPath;
    final separator = path?.lastIndexOf('/') ?? -1;
    final fileName = path == null
        ? 'Preparing destination…'
        : path.substring(separator + 1);
    final parent = path == null
        ? 'Waiting for backend proposal'
        : separator <= 0
        ? '.'
        : path.substring(0, separator);
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(
        horizontal: MfSpacing.sm,
        vertical: MfSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: MfPalette.elevated,
        borderRadius: BorderRadius.circular(MfRadius.md),
        border: Border.all(color: MfPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: MfPalette.foreground, fontSize: 11),
          ),
          const SizedBox(height: MfSpacing.xxs),
          Text(
            parent,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: MfPalette.faint, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Container(
          height: 7,
          decoration: BoxDecoration(
            color: MfPalette.border,
            borderRadius: BorderRadius.circular(MfRadius.sm),
          ),
          alignment: Alignment.centerLeft,
          child: AnimatedContainer(
            key: const Key('progress-track'),
            duration: MfMotion.standard,
            width: constraints.maxWidth * progress,
            decoration: BoxDecoration(
              color: MfPalette.accent,
              borderRadius: BorderRadius.circular(MfRadius.sm),
            ),
          ),
        );
      },
    );
  }
}

class _ConversionStep extends StatelessWidget {
  const _ConversionStep({required this.active, required this.label});

  final bool active;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: active ? MfPalette.accent : MfPalette.border,
            shape: BoxShape.circle,
            border: active ? Border.all(color: MfPalette.accentBright) : null,
          ),
        ),
        const SizedBox(width: MfSpacing.sm),
        Text(
          label,
          style: TextStyle(
            color: active ? MfPalette.foreground : MfPalette.faint,
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xE6111419),
        borderRadius: BorderRadius.circular(MfRadius.sm),
        border: Border.all(color: MfPalette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MfSpacing.xs,
          vertical: MfSpacing.xxs,
        ),
        child: Text(
          label,
          style: const TextStyle(color: MfPalette.muted, fontSize: 10),
        ),
      ),
    );
  }
}

class _DotPainter extends CustomPainter {
  const _DotPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = MfPalette.border;
    for (double y = 18; y < size.height; y += 24) {
      for (double x = 18; x < size.width; x += 24) {
        final distance = math.sqrt(
          math.pow(x - size.width / 2, 2) + math.pow(y - size.height / 2, 2),
        );
        if (distance > 180) {
          canvas.drawCircle(Offset(x, y), 0.7, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotPainter oldDelegate) => false;
}

class _ModePresentation {
  const _ModePresentation({
    required this.container,
    required this.video,
    required this.audio,
    required this.estimatedSize,
    required this.actionLabel,
  });

  factory _ModePresentation.fromMode(MediaOutputMode mode) {
    return switch (mode) {
      MediaOutputMode.videoWithAudio => const _ModePresentation(
        container: 'MP4',
        video: 'H.264 · Hardware',
        audio: 'AAC · 160 kbps',
        estimatedSize: '8–10 MB',
        actionLabel: 'Convert video',
      ),
      MediaOutputMode.videoOnly => const _ModePresentation(
        container: 'MP4',
        video: 'H.264 · Hardware',
        audio: 'None',
        estimatedSize: '7–9 MB',
        actionLabel: 'Convert video',
      ),
      MediaOutputMode.audioOnly => const _ModePresentation(
        container: 'MP3',
        video: 'None',
        audio: 'MP3 · 192 kbps',
        estimatedSize: '1–2 MB',
        actionLabel: 'Convert audio',
      ),
    };
  }

  final String container;
  final String video;
  final String audio;
  final String estimatedSize;
  final String actionLabel;
}
