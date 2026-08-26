import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediaforge/src/media_time.dart';
import 'package:mediaforge/src/mf_timeline.dart';
import 'package:mediaforge/src/timeline_controller.dart';

void main() {
  test('media time formatting separates labels from precise editing', () {
    expect(formatMediaTime(0), '00:00:00');
    expect(formatMediaTime(3723405), '01:02:03');
    expect(formatMediaTime(3723405, includeMilliseconds: true), '01:02:03.405');
    expect(formatMediaTime(-1), '00:00:00');
  });

  test('media time parsing accepts only the supported precise contract', () {
    expect(parseMediaTime('00:00:00'), 0);
    expect(parseMediaTime('01:02:03.405'), 3723405);
    expect(parseMediaTime('100:00:00'), 360000000);
    expect(parseMediaTime('1:02:03'), isNull);
    expect(parseMediaTime('00:60:00'), isNull);
    expect(parseMediaTime('00:00:00.4'), isNull);
    expect(parseMediaTime('999999999999999:00:00'), isNull);
    expect(parseMediaTime('not a time'), isNull);
  });

  testWidgets('timeline exposes semantic labels and actions', (
    WidgetTester tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final controller = TimelineController();
    addTearDown(controller.dispose);
    await _pumpTimeline(tester, controller);

    final finder = find.bySemanticsLabel('Trim timeline');
    expect(finder, findsOneWidget);
    final node = tester.getSemantics(finder);
    expect(node.getSemanticsData().hasAction(SemanticsAction.increase), isTrue);
    expect(node.getSemanticsData().hasAction(SemanticsAction.decrease), isTrue);
    expect(node.value, contains('Selection 00:00:00.250'));
    semantics.dispose();
  });

  testWidgets('timeline hover and drag update tooltip and marker', (
    WidgetTester tester,
  ) async {
    final controller = TimelineController();
    addTearDown(controller.dispose);
    await _pumpTimeline(tester, controller);

    final finder = find.byKey(const Key('mf-timeline'));
    final rect = tester.getRect(finder);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: rect.center);
    await mouse.moveTo(rect.center);
    await tester.pump();
    expect(find.byKey(const Key('timeline-tooltip')), findsOneWidget);

    final initialStart = controller.startMs;
    final startX = _xForValue(rect, initialStart, controller.durationMs);
    final drag = await tester.startGesture(Offset(startX, rect.center.dy));
    await drag.moveBy(const Offset(42, 0));
    await tester.pump();
    await drag.up();
    await tester.pump();
    expect(controller.startMs, greaterThan(initialStart));
  });

  testWidgets('timeline keyboard uses 100 ms and shifted 1 second steps', (
    WidgetTester tester,
  ) async {
    final controller = TimelineController();
    addTearDown(controller.dispose);
    await _pumpTimeline(tester, controller);

    final finder = find.byKey(const Key('mf-timeline'));
    final rect = tester.getRect(finder);
    final startX = _xForValue(rect, controller.startMs, controller.durationMs);
    final drag = await tester.startGesture(Offset(startX, rect.center.dy));
    await drag.moveBy(const Offset(24, 0));
    await drag.up();
    await tester.pump();

    final afterDrag = controller.startMs;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(controller.startMs, afterDrag + 100);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(controller.startMs, afterDrag + 1100);

    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(controller.startMs, 0);
  });

  testWidgets('timeline Home and End honor active marker boundaries', (
    WidgetTester tester,
  ) async {
    final controller = TimelineController();
    addTearDown(controller.dispose);
    await _pumpTimeline(tester, controller);

    final finder = find.byKey(const Key('mf-timeline'));
    final rect = tester.getRect(finder);
    final endX = _xForValue(rect, controller.endMs, controller.durationMs);
    final drag = await tester.startGesture(Offset(endX, rect.center.dy));
    await drag.moveBy(const Offset(-24, 0));
    await drag.up();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(controller.endMs, controller.durationMs);

    await tester.tapAt(rect.center);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(controller.playheadMs, 0);
  });
}

Future<void> _pumpTimeline(
  WidgetTester tester,
  TimelineController controller,
) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: 600,
          height: 70,
          child: ListenableBuilder(
            listenable: controller,
            builder: (BuildContext context, Widget? child) {
              return MfTimeline(
                durationMs: controller.durationMs,
                startMs: controller.startMs,
                endMs: controller.endMs,
                playheadMs: controller.playheadMs,
                onStartChanged: controller.setStart,
                onEndChanged: controller.setEnd,
                onPlayheadChanged: controller.setPlayhead,
              );
            },
          ),
        ),
      ),
    ),
  );
}

double _xForValue(Rect rect, int valueMs, int durationMs) {
  return rect.left + 12 + (rect.width - 24) * valueMs / durationMs;
}
