import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../lib/time.js" as Time

Frame {
    id: root

    required property var controller
    required property var i18n

    padding: 18

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        Label {
            text: root.i18n("source")
            font.bold: true
            font.pixelSize: 17
        }
        Label {
            Layout.fillWidth: true
            text: root.controller.mediaFileName
            elide: Text.ElideMiddle
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 14
            rowSpacing: 7

            Label {
                text: root.i18n("format")
                opacity: 0.65
            }
            Label {
                text: root.controller.mediaFormat
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            Label {
                text: root.i18n("duration")
                opacity: 0.65
            }
            Label {
                text: Time.formatTime(root.controller.durationMs, false)
            }
            Label {
                text: root.i18n("size")
                opacity: 0.65
            }
            Label {
                text: (root.controller.mediaFileSize / 1048576).toFixed(1) + " MB"
            }
            Label {
                text: root.i18n("video")
                opacity: 0.65
            }
            Label {
                text: root.controller.hasVideo ? root.controller.videoCodec + " · " + root.controller.videoWidth + "×" + root.controller.videoHeight : root.i18n("none")
            }
            Label {
                text: root.i18n("audio")
                opacity: 0.65
            }
            Label {
                text: root.controller.hasAudio ? root.controller.audioCodec + " · " + root.controller.audioSampleRate + " Hz" : root.i18n("none")
            }
        }
    }
}
