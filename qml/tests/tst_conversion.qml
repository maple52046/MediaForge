pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import "../components"

TestCase {
    id: testCase

    name: "ConversionPanel"
    when: windowShown

    property var latestArguments: []

    QtObject {
        id: fakeController

        property string jobState: "idle"
        property bool mediaLoaded: true
        property var availableModes: ["videoWithAudio", "videoOnly", "audioOnly"]
        property real progress: 0

        function defaultOutputPath(mode) {
            return mode === "audioOnly" ? "/tmp/output.mp3" : "/tmp/output.mp4";
        }

        function startConversion(outputPath, mode, quality, startMs, endMs, overwrite) {
            testCase.latestArguments = [outputPath, mode, quality, startMs, endMs, overwrite];
        }

        function cancelConversion() {
        }
    }

    Component {
        id: panelComponent

        ConversionPanel {
            width: 400
            height: 500
            controller: fakeController
            startMs: 1000
            endMs: 9000
            i18n: function (key) {
                return key;
            }
        }
    }

    function test_mode_initialization_and_active_state() {
        const panel = createTemporaryObject(panelComponent, testCase);
        verify(panel !== null);
        panel.resetForMedia();
        compare(panel.selectedMode, "videoWithAudio");
        compare(panel.outputPath, "/tmp/output.mp4");
        verify(!panel.active);

        fakeController.jobState = "running";
        verify(panel.active);
        fakeController.jobState = "idle";
    }

    function test_overwrite_retry_preserves_request() {
        const panel = createTemporaryObject(panelComponent, testCase);
        verify(panel !== null);
        panel.selectedMode = "audioOnly";
        panel.selectedQuality = "high";
        panel.outputPath = "/tmp/output.mp3";

        panel.retryOverwrite();

        compare(latestArguments, ["/tmp/output.mp3", "audioOnly", "high", 1000, 9000, true]);
    }

    function test_clear_for_media_removes_stale_selection() {
        const panel = createTemporaryObject(panelComponent, testCase);
        verify(panel !== null);
        panel.selectedMode = "audioOnly";
        panel.selectedQuality = "high";
        panel.outputPath = "/tmp/output.mp3";

        panel.clearForMedia();

        compare(panel.selectedMode, "videoWithAudio");
        compare(panel.selectedQuality, "medium");
        compare(panel.outputPath, "");
    }
}
