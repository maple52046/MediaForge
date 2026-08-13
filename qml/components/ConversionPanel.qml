pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import "../lib/source.js" as Source

Frame {
    id: root

    required property var controller
    required property var i18n
    required property int startMs
    required property int endMs
    property string selectedMode: "videoWithAudio"
    property string selectedQuality: "medium"
    property string outputPath: ""
    readonly property bool active: controller.jobState === "preparing" || controller.jobState === "running"

    function resetForMedia() {
        if (controller.availableModes.length === 0)
            return;
        selectedMode = controller.availableModes[0];
        outputPath = controller.defaultOutputPath(selectedMode);
    }

    function clearForMedia() {
        selectedMode = "videoWithAudio";
        selectedQuality = "medium";
        outputPath = "";
    }

    function beginConversion(overwrite) {
        controller.startConversion(outputPath, selectedMode, selectedQuality, startMs, endMs, overwrite);
    }

    function retryOverwrite() {
        beginConversion(true);
    }

    padding: 18

    FileDialog {
        id: outputDialog
        fileMode: FileDialog.SaveFile
        nameFilters: root.selectedMode === "audioOnly" ? ["MP3 audio (*.mp3)"] : ["MP4 video (*.mp4)"]
        onAccepted: root.outputPath = Source.localPath(selectedFile)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        Label {
            text: root.i18n("output")
            font.bold: true
            font.pixelSize: 17
        }
        ComboBox {
            Layout.fillWidth: true
            model: root.controller.availableModes
            enabled: !root.active
            textRole: ""
            displayText: root.i18n(root.selectedMode)
            delegate: ItemDelegate {
                required property string modelData
                width: ListView.view.width
                text: root.i18n(modelData)
            }
            onActivated: index => {
                root.selectedMode = root.controller.availableModes[index];
                root.outputPath = root.controller.defaultOutputPath(root.selectedMode);
            }
        }
        ComboBox {
            Layout.fillWidth: true
            visible: root.selectedMode === "audioOnly"
            enabled: !root.active
            model: ["high", "medium", "low"]
            displayText: root.i18n(root.selectedQuality)
            delegate: ItemDelegate {
                required property string modelData
                width: ListView.view.width
                text: root.i18n(modelData)
            }
            onActivated: index => root.selectedQuality = model[index]
        }
        Label {
            text: root.i18n("destination")
            opacity: 0.65
        }
        RowLayout {
            Layout.fillWidth: true
            TextField {
                Layout.fillWidth: true
                text: root.outputPath
                enabled: !root.active
                onTextEdited: root.outputPath = text
                Accessible.name: root.i18n("destination")
            }
            Button {
                text: root.i18n("browse")
                enabled: !root.active
                onClicked: outputDialog.open()
            }
        }
        ProgressBar {
            Layout.fillWidth: true
            visible: root.controller.jobState !== "idle"
            from: 0
            to: 100
            value: root.controller.progress
        }
        Label {
            Layout.fillWidth: true
            visible: root.controller.jobState !== "idle"
            text: root.statusText()
            opacity: 0.7
        }
        Button {
            Layout.fillWidth: true
            highlighted: !root.active
            text: root.active ? root.i18n("cancel") : root.i18n("convert")
            enabled: root.active || (root.controller.mediaLoaded && root.outputPath.length > 0 && root.endMs > root.startMs)
            onClicked: root.active ? root.controller.cancelConversion() : root.beginConversion(false)
        }
    }

    function statusText() {
        if (controller.jobState === "running")
            return i18n("running") + " " + Math.round(controller.progress) + "%";
        return i18n(controller.jobState);
    }
}
