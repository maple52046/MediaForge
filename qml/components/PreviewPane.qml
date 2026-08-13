import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import "../lib/time.js" as Time

Frame {
    id: root

    required property var controller
    required property var i18n
    property int currentMs: player.position
    property bool playingSelection: false
    property int selectionEndMs: 0
    signal seekRequested(int positionMs)

    function playSelection(startMs, endMs) {
        player.position = startMs;
        selectionEndMs = endMs;
        playingSelection = true;
        player.play();
    }

    function seek(positionMs) {
        player.position = Math.max(0, Math.min(positionMs, root.controller.durationMs));
    }

    padding: 0

    MediaPlayer {
        id: player
        source: root.controller.mediaLoaded ? root.fileUrl(root.controller.mediaPath) : ""
        audioOutput: AudioOutput {
            id: audioOutput
            volume: volumeSlider.value
        }
        videoOutput: root.controller.hasVideo ? videoOutput : null
        onPositionChanged: {
            if (root.playingSelection && position >= root.selectionEndMs) {
                pause();
                root.playingSelection = false;
            }
        }
        onErrorOccurred: previewFallback.visible = true
    }

    function fileUrl(path) {
        return "file://" + encodeURI(path);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 390
            color: "#111318"

            VideoOutput {
                id: videoOutput
                anchors.fill: parent
                fillMode: VideoOutput.PreserveAspectFit
                visible: root.controller.hasVideo
            }
            Label {
                anchors.centerIn: parent
                visible: root.controller.hasAudio && !root.controller.hasVideo
                text: "♫\n" + root.controller.mediaFileName
                color: "white"
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 20
            }
            Label {
                id: previewFallback
                anchors.centerIn: parent
                width: Math.min(parent.width - 48, 500)
                visible: false
                text: root.i18n("previewUnavailable")
                color: "white"
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 10
            spacing: 10

            Button {
                icon.source: player.playbackState === MediaPlayer.PlayingState ? "qrc:/mediaforge/icons/pause-outlined.svg" : "qrc:/mediaforge/icons/play-outlined.svg"
                Accessible.name: player.playbackState === MediaPlayer.PlayingState ? "Pause" : "Play"
                onClicked: player.playbackState === MediaPlayer.PlayingState ? player.pause() : player.play()
            }
            Slider {
                Layout.fillWidth: true
                from: 0
                to: Math.max(1, root.controller.durationMs)
                value: player.position
                onMoved: player.position = value
                Accessible.name: root.i18n("current")
            }
            Label {
                text: Time.formatTime(player.position, false) + " / " + Time.formatTime(root.controller.durationMs, false)
            }
            Slider {
                id: volumeSlider
                Layout.preferredWidth: 90
                from: 0
                to: 1
                value: 0.8
                Accessible.name: "Volume"
            }
        }
    }
}
