import QtQuick
import QtMultimedia
import QtTest

TestCase {
    id: testCase

    name: "QtMultimediaPreview"
    when: windowShown

    Component {
        id: previewComponent

        Item {
            width: 640
            height: 360

            property alias player: player
            property alias videoOutput: videoOutput

            MediaPlayer {
                id: player
                audioOutput: AudioOutput {}
                videoOutput: videoOutput
            }

            VideoOutput {
                id: videoOutput
                anchors.fill: parent
                fillMode: VideoOutput.PreserveAspectFit
            }
        }
    }

    function test_h264_and_hevc_media_load_seek_and_resize() {
        const preview = createTemporaryObject(previewComponent, testCase);
        verify(preview !== null);

        for (const codec of ["h264", "hevc"]) {
            preview.player.source = Qt.resolvedUrl("../../target/test-fixtures/preview-" + codec + ".mp4");
            tryCompare(preview.player, "mediaStatus", MediaPlayer.LoadedMedia, 10000);
            verify(preview.player.hasVideo);
            verify(preview.player.hasAudio);
            preview.player.position = 500;
            tryVerify(function () {
                return preview.player.position >= 450;
            }, 3000);
        }

        compare(preview.videoOutput.fillMode, VideoOutput.PreserveAspectFit);
        preview.width = 800;
        preview.height = 500;
        compare(preview.videoOutput.width, 800);
        compare(preview.videoOutput.height, 500);
    }
}
