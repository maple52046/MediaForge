import QtQuick
import QtTest
import "../controls"

TestCase {
    id: testCase

    name: "TrimTimeline"
    when: windowShown

    Component {
        id: timelineComponent

        TrimTimeline {
            width: 800
            durationMs: 10000
            currentMs: 2500
            playIconSource: ""
            i18n: function (key) {
                return key;
            }
        }
    }

    function test_text_commits_enforce_bounds() {
        const timeline = createTemporaryObject(timelineComponent, testCase);
        verify(timeline !== null);

        verify(timeline.commitStart("00:00:02.000"));
        compare(timeline.startMs, 2000);
        verify(timeline.commitEnd("00:00:08.000"));
        compare(timeline.endMs, 8000);
        verify(!timeline.commitStart("00:00:08.000"));
        verify(!timeline.commitEnd("00:00:01.000"));
        compare(timeline.startMs, 2000);
        compare(timeline.endMs, 8000);
    }

    function test_play_selection_emits_current_range() {
        const timeline = createTemporaryObject(timelineComponent, testCase);
        verify(timeline !== null);
        timeline.startMs = 1000;
        timeline.endMs = 9000;
        let receivedStart = -1;
        let receivedEnd = -1;
        timeline.playSelectionRequested.connect(function (startMs, endMs) {
            receivedStart = startMs;
            receivedEnd = endMs;
        });

        timeline.playSelectionRequested(timeline.startMs, timeline.endMs);

        compare(receivedStart, 1000);
        compare(receivedEnd, 9000);
    }
}
