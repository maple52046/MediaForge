import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../lib/time.js" as Time

Frame {
    id: root

    required property var i18n
    required property int durationMs
    required property int currentMs
    property int startMs: 0
    property int endMs: durationMs
    property bool controlsEnabled: true
    property url playIconSource: "qrc:/mediaforge/icons/play-outlined.svg"
    signal seekRequested(int positionMs)
    signal playSelectionRequested(int startMs, int endMs)

    function positionFor(value) {
        return track.width * value / Math.max(1, durationMs);
    }

    function valueFor(position) {
        return Math.round(Math.max(0, Math.min(track.width, position)) * durationMs / Math.max(1, track.width));
    }

    function commitStart(text) {
        const value = Time.parseTime(text);
        if (value === null || value >= endMs)
            return false;
        startMs = Math.max(0, Math.min(value, durationMs - 1));
        return true;
    }

    function commitEnd(text) {
        const value = Time.parseTime(text);
        if (value === null || value <= startMs || value > durationMs)
            return false;
        endMs = value;
        return true;
    }

    padding: 18

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        Label {
            text: root.i18n("selection")
            font.bold: true
            font.pixelSize: 17
        }

        Item {
            id: trackContainer
            Layout.fillWidth: true
            Layout.preferredHeight: 42

            Rectangle {
                id: track
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                height: 6
                radius: 3
                color: palette.mid

                TapHandler {
                    enabled: root.controlsEnabled
                    onTapped: eventPoint => root.seekRequested(root.valueFor(eventPoint.position.x))
                }

                Rectangle {
                    x: root.positionFor(root.startMs)
                    width: Math.max(0, root.positionFor(root.endMs) - x)
                    height: parent.height
                    radius: parent.radius
                    color: "#7c3aed"
                }
                Rectangle {
                    x: root.positionFor(root.currentMs) - 1
                    y: -7
                    width: 2
                    height: 20
                    color: palette.text
                }
            }

            RoundButton {
                id: startHandle
                x: track.x + root.positionFor(root.startMs) - width / 2
                anchors.verticalCenter: track.verticalCenter
                width: 24
                height: 24
                enabled: root.controlsEnabled
                Accessible.name: root.i18n("start")
                Keys.onLeftPressed: root.startMs = Math.max(0, root.startMs - 1000)
                Keys.onRightPressed: root.startMs = Math.min(root.endMs - 1, root.startMs + 1000)
                DragHandler {
                    xAxis.minimum: track.x - startHandle.x
                    xAxis.maximum: track.x + root.positionFor(root.endMs - 1) - startHandle.x
                    onActiveTranslationChanged: root.startMs = Math.min(root.endMs - 1, root.valueFor(startHandle.x + startHandle.width / 2 - track.x))
                }
            }
            RoundButton {
                id: endHandle
                x: track.x + root.positionFor(root.endMs) - width / 2
                anchors.verticalCenter: track.verticalCenter
                width: 24
                height: 24
                enabled: root.controlsEnabled
                Accessible.name: root.i18n("end")
                Keys.onLeftPressed: root.endMs = Math.max(root.startMs + 1, root.endMs - 1000)
                Keys.onRightPressed: root.endMs = Math.min(root.durationMs, root.endMs + 1000)
                DragHandler {
                    xAxis.minimum: track.x + root.positionFor(root.startMs + 1) - endHandle.x
                    xAxis.maximum: track.x + track.width - endHandle.x
                    onActiveTranslationChanged: root.endMs = Math.max(root.startMs + 1, root.valueFor(endHandle.x + endHandle.width / 2 - track.x))
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 3
            columnSpacing: 12

            Label {
                text: root.i18n("start")
            }
            Label {
                text: root.i18n("end")
            }
            Label {
                text: root.i18n("current")
            }
            TextField {
                id: startField
                text: Time.formatTime(root.startMs, true)
                enabled: root.controlsEnabled
                Accessible.name: root.i18n("start")
                onEditingFinished: {
                    if (!root.commitStart(text))
                        text = Time.formatTime(root.startMs, true);
                }
            }
            TextField {
                id: endField
                text: Time.formatTime(root.endMs, true)
                enabled: root.controlsEnabled
                Accessible.name: root.i18n("end")
                onEditingFinished: {
                    if (!root.commitEnd(text))
                        text = Time.formatTime(root.endMs, true);
                }
            }
            Label {
                text: Time.formatTime(root.currentMs, false)
            }
        }

        RowLayout {
            Button {
                text: root.i18n("setStart")
                enabled: root.controlsEnabled && root.currentMs < root.endMs
                onClicked: root.startMs = Math.max(0, root.currentMs)
            }
            Button {
                text: root.i18n("setEnd")
                enabled: root.controlsEnabled && root.currentMs > root.startMs
                onClicked: root.endMs = Math.min(root.durationMs, root.currentMs)
            }
            Button {
                text: root.i18n("reset")
                enabled: root.controlsEnabled
                onClicked: {
                    root.startMs = 0;
                    root.endMs = root.durationMs;
                }
            }
            Item {
                Layout.fillWidth: true
            }
            Button {
                text: root.i18n("playSelection")
                icon.source: root.playIconSource
                enabled: root.controlsEnabled
                onClicked: root.playSelectionRequested(root.startMs, root.endMs)
            }
        }
    }
}
