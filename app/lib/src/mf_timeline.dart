import 'dart:math' as math;

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'media_time.dart';
import 'mf_localizations.dart';
import 'mf_tokens.dart';

/// Marker controlled by keyboard or pointer input on [MfTimeline].
enum MfTimelineMarker {
  /// Selection start handle.
  start,

  /// Selection end handle.
  end,

  /// Current preview position.
  playhead,
}

/// Accessible custom trim timeline with independent integer-ms markers.
class MfTimeline extends StatefulWidget {
  /// Creates a timeline whose callbacks receive constrained marker positions.
  const MfTimeline({
    required this.durationMs,
    required this.startMs,
    required this.endMs,
    required this.playheadMs,
    required this.onStartChanged,
    required this.onEndChanged,
    required this.onPlayheadChanged,
    super.key,
  });

  /// Source duration in milliseconds.
  final int durationMs;

  /// Current selection start in milliseconds.
  final int startMs;

  /// Current selection end in milliseconds.
  final int endMs;

  /// Current playhead in milliseconds.
  final int playheadMs;

  /// Receives pointer and keyboard changes to the start handle.
  final ValueChanged<int> onStartChanged;

  /// Receives pointer and keyboard changes to the end handle.
  final ValueChanged<int> onEndChanged;

  /// Receives pointer and keyboard changes to the playhead.
  final ValueChanged<int> onPlayheadChanged;

  @override
  State<MfTimeline> createState() => _MfTimelineState();
}

class _MfTimelineState extends State<MfTimeline> {
  static const double _trackInset = 12;
  static const double _markerHitRadius = 18;

  final FocusNode _focusNode = FocusNode(debugLabel: 'MediaForge timeline');
  MfTimelineMarker _activeMarker = MfTimelineMarker.playhead;
  int? _hoverMs;
  bool _dragging = false;
  double _width = 1;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = MfStrings.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        _width = constraints.maxWidth;
        final tooltipMs = _dragging ? _activeValue : _hoverMs;
        final tooltipX = _xForValue(tooltipMs ?? _activeValue);
        return Semantics(
          label: strings.trimTimeline,
          value:
              '${_markerLabel(_activeMarker, strings)} '
              '${_preciseTime(_activeValue)}. '
              '${strings.selectionSemantics(_preciseTime(widget.startMs), _preciseTime(widget.endMs))}',
          increasedValue: _preciseTime(_nextKeyboardValue(100)),
          decreasedValue: _preciseTime(_nextKeyboardValue(-100)),
          onIncrease: () => _moveActiveMarker(100),
          onDecrease: () => _moveActiveMarker(-100),
          onTap: _focusNode.requestFocus,
          customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
            CustomSemanticsAction(label: strings.selectStartHandle): () {
              _selectMarker(MfTimelineMarker.start);
            },
            CustomSemanticsAction(label: strings.selectEndHandle): () {
              _selectMarker(MfTimelineMarker.end);
            },
            CustomSemanticsAction(label: strings.selectPlayhead): () {
              _selectMarker(MfTimelineMarker.playhead);
            },
          },
          child: Focus(
            focusNode: _focusNode,
            onFocusChange: (_) => setState(() {}),
            onKeyEvent: _handleKeyEvent,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onHover: (PointerHoverEvent event) {
                setState(() => _hoverMs = _valueForX(event.localPosition.dx));
              },
              onExit: (_) => setState(() => _hoverMs = null),
              child: GestureDetector(
                key: const Key('mf-timeline'),
                behavior: HitTestBehavior.opaque,
                onTapUp: (TapUpDetails details) {
                  _focusNode.requestFocus();
                  _activeMarker = MfTimelineMarker.playhead;
                  _updateActiveMarker(_valueForX(details.localPosition.dx));
                },
                onPanDown: (DragDownDetails details) {
                  _focusNode.requestFocus();
                  setState(() {
                    _activeMarker = _nearestMarker(details.localPosition.dx);
                  });
                },
                onPanStart: (DragStartDetails details) {
                  _focusNode.requestFocus();
                  setState(() => _dragging = true);
                  _updateActiveMarker(_valueForX(details.localPosition.dx));
                },
                onPanUpdate: (DragUpdateDetails details) {
                  _updateActiveMarker(_valueForX(details.localPosition.dx));
                },
                onPanEnd: (_) => setState(() => _dragging = false),
                onPanCancel: () => setState(() => _dragging = false),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _MfTimelinePainter(
                          durationMs: widget.durationMs,
                          startMs: widget.startMs,
                          endMs: widget.endMs,
                          playheadMs: widget.playheadMs,
                          activeMarker: _activeMarker,
                          focused: _focusNode.hasFocus,
                          hoverMs: _hoverMs,
                          lightPalette:
                              MfPalette.background == MfLightPalette.background,
                        ),
                      ),
                    ),
                    if (tooltipMs != null)
                      Positioned(
                        key: const Key('timeline-tooltip'),
                        left: (tooltipX - 47).clamp(
                          0,
                          constraints.maxWidth - 94,
                        ),
                        top: 0,
                        child: _TimelineTooltip(label: _preciseTime(tooltipMs)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  int get _activeValue => switch (_activeMarker) {
    MfTimelineMarker.start => widget.startMs,
    MfTimelineMarker.end => widget.endMs,
    MfTimelineMarker.playhead => widget.playheadMs,
  };

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final step = HardwareKeyboard.instance.isShiftPressed ? 1000 : 100;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _moveActiveMarker(-step);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _moveActiveMarker(step);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.home) {
      _moveActiveToBoundary(end: false);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.end) {
      _moveActiveToBoundary(end: true);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _selectMarker(MfTimelineMarker marker) {
    _focusNode.requestFocus();
    setState(() => _activeMarker = marker);
  }

  void _moveActiveMarker(int deltaMs) {
    _updateActiveMarker(_activeValue + deltaMs);
  }

  int _nextKeyboardValue(int deltaMs) {
    return _constrainValue(_activeMarker, _activeValue + deltaMs);
  }

  void _moveActiveToBoundary({required bool end}) {
    final value = switch (_activeMarker) {
      MfTimelineMarker.start => end ? widget.endMs - 1 : 0,
      MfTimelineMarker.end => end ? widget.durationMs : widget.startMs + 1,
      MfTimelineMarker.playhead => end ? widget.durationMs : 0,
    };
    _updateActiveMarker(value);
  }

  void _updateActiveMarker(int valueMs) {
    final constrained = _constrainValue(_activeMarker, valueMs);
    switch (_activeMarker) {
      case MfTimelineMarker.start:
        widget.onStartChanged(constrained);
      case MfTimelineMarker.end:
        widget.onEndChanged(constrained);
      case MfTimelineMarker.playhead:
        widget.onPlayheadChanged(constrained);
    }
    setState(() {});
  }

  int _constrainValue(MfTimelineMarker marker, int valueMs) {
    return switch (marker) {
      MfTimelineMarker.start => valueMs.clamp(0, widget.endMs - 1),
      MfTimelineMarker.end => valueMs.clamp(
        widget.startMs + 1,
        widget.durationMs,
      ),
      MfTimelineMarker.playhead => valueMs.clamp(0, widget.durationMs),
    };
  }

  MfTimelineMarker _nearestMarker(double x) {
    final positions = <MfTimelineMarker, double>{
      MfTimelineMarker.start: _xForValue(widget.startMs),
      MfTimelineMarker.end: _xForValue(widget.endMs),
      MfTimelineMarker.playhead: _xForValue(widget.playheadMs),
    };
    final sorted = positions.entries.toList()
      ..sort(
        (
          MapEntry<MfTimelineMarker, double> a,
          MapEntry<MfTimelineMarker, double> b,
        ) => (a.value - x).abs().compareTo((b.value - x).abs()),
      );
    return (sorted.first.value - x).abs() <= _markerHitRadius
        ? sorted.first.key
        : MfTimelineMarker.playhead;
  }

  int _valueForX(double x) {
    final usableWidth = math.max(1, _width - _trackInset * 2);
    final ratio = ((x - _trackInset) / usableWidth).clamp(0, 1);
    return (ratio * widget.durationMs).round();
  }

  double _xForValue(int valueMs) {
    final usableWidth = math.max(1, _width - _trackInset * 2);
    return _trackInset + usableWidth * valueMs / widget.durationMs;
  }

  String _markerLabel(MfTimelineMarker marker, MfStrings strings) =>
      switch (marker) {
        MfTimelineMarker.start => strings.startHandle,
        MfTimelineMarker.end => strings.endHandle,
        MfTimelineMarker.playhead => strings.playhead,
      };

  String _preciseTime(int valueMs) =>
      formatMediaTime(valueMs, includeMilliseconds: true);
}

class _TimelineTooltip extends StatelessWidget {
  const _TimelineTooltip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 94,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: MfPalette.elevated,
        borderRadius: BorderRadius.circular(MfRadius.sm),
        border: Border.all(color: MfPalette.accent),
      ),
      child: Text(
        label,
        style: TextStyle(color: MfPalette.foreground, fontSize: 9),
      ),
    );
  }
}

class _MfTimelinePainter extends CustomPainter {
  const _MfTimelinePainter({
    required this.durationMs,
    required this.startMs,
    required this.endMs,
    required this.playheadMs,
    required this.activeMarker,
    required this.focused,
    required this.hoverMs,
    required this.lightPalette,
  });

  final int durationMs;
  final int startMs;
  final int endMs;
  final int playheadMs;
  final MfTimelineMarker activeMarker;
  final bool focused;
  final int? hoverMs;
  final bool lightPalette;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = _MfTimelineState._trackInset;
    const trackHeight = 6.0;
    final centerY = size.height - 16;
    final trackWidth = math.max(1, size.width - inset * 2).toDouble();
    double xFor(int valueMs) => inset + trackWidth * valueMs / durationMs;

    if (focused) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, centerY - 20, size.width, 40),
          const Radius.circular(MfRadius.md),
        ),
        Paint()
          ..color = MfPalette.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(inset, centerY - trackHeight / 2, trackWidth, trackHeight),
      const Radius.circular(MfRadius.sm),
    );
    canvas.drawRRect(track, Paint()..color = MfPalette.border);

    final startX = xFor(startMs);
    final endX = xFor(endMs);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(startX, centerY - 3, endX, centerY + 3),
        const Radius.circular(MfRadius.sm),
      ),
      Paint()..color = MfPalette.accent,
    );

    if (hoverMs != null) {
      final hoverX = xFor(hoverMs!);
      canvas.drawLine(
        Offset(hoverX, centerY - 9),
        Offset(hoverX, centerY + 9),
        Paint()
          ..color = MfPalette.muted
          ..strokeWidth = 1,
      );
    }

    final playheadX = xFor(playheadMs);
    canvas.drawRect(
      Rect.fromLTWH(playheadX - 1, centerY - 17, 2, 34),
      Paint()
        ..color = activeMarker == MfTimelineMarker.playhead
            ? MfPalette.foreground
            : MfPalette.muted,
    );

    for (final entry in <MfTimelineMarker, double>{
      MfTimelineMarker.start: startX,
      MfTimelineMarker.end: endX,
    }.entries) {
      final active = entry.key == activeMarker;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(entry.value, centerY),
            width: active ? 14 : 12,
            height: active ? 30 : 28,
          ),
          const Radius.circular(MfRadius.sm),
        ),
        Paint()..color = active ? MfPalette.accentBright : MfPalette.accent,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MfTimelinePainter oldDelegate) {
    return durationMs != oldDelegate.durationMs ||
        startMs != oldDelegate.startMs ||
        endMs != oldDelegate.endMs ||
        playheadMs != oldDelegate.playheadMs ||
        activeMarker != oldDelegate.activeMarker ||
        focused != oldDelegate.focused ||
        hoverMs != oldDelegate.hoverMs ||
        lightPalette != oldDelegate.lightPalette;
  }
}
