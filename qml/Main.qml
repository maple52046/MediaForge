import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import app.mediaforge.desktop
import "components"
import "controls"
import "lib/source.js" as Source
import "lib/strings.js" as Strings
import "theme"

ApplicationWindow {
    id: root

    width: 1180
    height: 820
    minimumWidth: 920
    minimumHeight: 680
    visible: true
    title: "MediaForge"

    property string language: Strings.resolveLanguage(settings.languagePreference, Qt.uiLanguage)
    property bool closeApproved: false
    readonly property bool jobActive: controller.jobState === "preparing" || controller.jobState === "running"
    readonly property bool sourceMutable: !jobActive && controller.applicationState !== "loadingMedia"

    function i18n(key) {
        return Strings.text(key, language);
    }

    function loadDroppedSource(urls) {
        const path = Source.firstDroppedPath(urls);
        if (path.length > 0)
            controller.loadMedia(path);
    }

    function clearSource() {
        if (!sourceMutable)
            return;
        controller.clearMedia();
        timeline.startMs = 0;
        timeline.endMs = 0;
        conversion.clearForMedia();
    }

    onClosing: close => {
        if (closeApproved)
            return;
        close.accepted = false;
        if (jobActive)
            closeDialog.open();
        else
            controller.requestClose();
    }

    Settings {
        id: settings
        category: "preferences"
        property string languagePreference: "system"
    }

    AppTheme {
        id: theme
    }
    MediaForgeController {
        id: controller
    }

    Connections {
        target: controller
        function onMediaLoadedSuccessfully() {
            timeline.startMs = 0;
            timeline.endMs = controller.durationMs;
            conversion.resetForMedia();
        }
        function onConversionFailed() {
            if (controller.errorCode === "outputExists")
                overwriteDialog.open();
        }
        function onSafeToClose() {
            root.closeApproved = true;
            Qt.quit();
        }
    }

    FileDialog {
        id: inputDialog
        title: root.i18n("chooseMedia")
        fileMode: FileDialog.OpenFile
        nameFilters: ["Media files (*.mov *.mp4 *.m4v *.mp3 *.m4a *.wav *.aac)", "All files (*)"]
        onAccepted: controller.loadMedia(Source.localPath(selectedFile))
    }

    Dialog {
        id: overwriteDialog
        anchors.centerIn: parent
        modal: true
        title: root.i18n("outputExists")
        standardButtons: Dialog.Yes | Dialog.No
        Label {
            width: 420
            text: root.i18n("overwrite")
            wrapMode: Text.WordWrap
        }
        onAccepted: conversion.retryOverwrite()
    }

    Dialog {
        id: closeDialog
        anchors.centerIn: parent
        modal: true
        title: root.i18n("cancel")
        standardButtons: Dialog.Yes | Dialog.No
        Label {
            width: 420
            text: root.i18n("closeActive")
            wrapMode: Text.WordWrap
        }
        onAccepted: controller.requestClose()
    }

    Dialog {
        id: settingsDialog
        anchors.centerIn: parent
        modal: true
        title: root.i18n("settings")
        standardButtons: Dialog.Close

        ColumnLayout {
            width: 420
            Label {
                text: root.i18n("language")
                font.bold: true
            }
            ComboBox {
                Layout.fillWidth: true
                model: ["system", "zh-TW", "en"]
                currentIndex: Math.max(0, model.indexOf(settings.languagePreference))
                textRole: ""
                displayText: root.i18n(currentValue === "zh-TW" ? "traditionalChinese" : currentValue === "en" ? "english" : "system")
                onActivated: index => settings.languagePreference = model[index]
            }
            Label {
                text: root.i18n("backend")
                font.bold: true
                Layout.topMargin: 12
            }
            Label {
                text: "FFmpeg " + controller.ffmpegVersion
            }
            Label {
                text: "VideoToolbox: " + (controller.h264Available ? "✓" : "—") + "  AAC: " + (controller.aacAvailable ? "✓" : "—") + "  MP3: " + (controller.mp3Available ? "✓" : "—")
            }
        }
    }

    header: ToolBar {
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 22
            anchors.rightMargin: 22
            Label {
                text: "MediaForge"
                font.bold: true
                font.pixelSize: 24
            }
            Label {
                text: root.i18n("subtitle")
                opacity: 0.65
            }
            Item {
                Layout.fillWidth: true
            }
            Button {
                visible: controller.mediaLoaded
                enabled: root.sourceMutable
                text: root.i18n("changeSource")
                onClicked: inputDialog.open()
            }
            Button {
                visible: controller.mediaLoaded
                enabled: root.sourceMutable
                text: root.i18n("clearSource")
                onClicked: root.clearSource()
            }
            Button {
                text: "⚙"
                Accessible.name: root.i18n("settings")
                onClicked: settingsDialog.open()
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: palette.window

        DropArea {
            id: sourceDropArea

            anchors.fill: parent
            enabled: root.sourceMutable
            z: 100
            onDropped: drop => {
                if (drop.hasUrls)
                    root.loadDroppedSource(drop.urls);
            }

            Rectangle {
                anchors.fill: parent
                visible: sourceDropArea.containsDrag
                color: root.palette.base
                opacity: 0.94
            }
            Label {
                anchors.centerIn: parent
                visible: sourceDropArea.containsDrag
                text: root.i18n(controller.mediaLoaded ? "dropReplaceTitle" : "dropTitle")
                color: theme.accent
                font.bold: true
                font.pixelSize: 26
            }
        }

        Rectangle {
            anchors.fill: parent
            visible: controller.mediaLoaded && controller.applicationState === "loadingMedia"
            color: root.palette.base
            opacity: 0.94
            z: 90

            Column {
                anchors.centerIn: parent
                spacing: 12
                BusyIndicator {
                    anchors.horizontalCenter: parent.horizontalCenter
                    running: parent.parent.visible
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.i18n("loading")
                    font.bold: true
                    font.pixelSize: 22
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 14

            Frame {
                Layout.fillWidth: true
                visible: controller.errorCode.length > 0
                background: Rectangle {
                    color: "#35dc2626"
                    border.color: theme.danger
                    radius: 8
                }
                RowLayout {
                    anchors.fill: parent
                    Label {
                        Layout.fillWidth: true
                        text: root.i18n(controller.errorCode) + "\n" + controller.errorMessage
                        wrapMode: Text.WordWrap
                    }
                    ToolButton {
                        text: "×"
                        onClicked: controller.clearError()
                    }
                }
            }

            Frame {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !controller.mediaLoaded
                enabled: root.sourceMutable
                Column {
                    anchors.centerIn: parent
                    spacing: 12
                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 58
                        height: 58
                        source: "qrc:/mediaforge/icons/cloud-upload-outlined.svg"
                        sourceSize: Qt.size(width, height)
                        visible: controller.applicationState !== "loadingMedia"
                        Accessible.name: root.i18n("chooseMedia")
                    }
                    BusyIndicator {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 52
                        height: 52
                        running: controller.applicationState === "loadingMedia"
                        visible: running
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: controller.applicationState === "loadingMedia" ? root.i18n("loading") : root.i18n("dropTitle")
                        font.bold: true
                        font.pixelSize: 22
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.i18n("dropDetail")
                        opacity: 0.65
                    }
                    Button {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.i18n("chooseMedia")
                        onClicked: inputDialog.open()
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: controller.mediaLoaded
                enabled: controller.applicationState !== "loadingMedia"
                columns: 2
                columnSpacing: 16
                rowSpacing: 16

                PreviewPane {
                    id: preview
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    controller: controller
                    i18n: root.i18n
                }
                ColumnLayout {
                    Layout.preferredWidth: 350
                    Layout.fillHeight: true
                    MediaDetails {
                        Layout.fillWidth: true
                        controller: controller
                        i18n: root.i18n
                    }
                    ConversionPanel {
                        id: conversion
                        Layout.fillWidth: true
                        controller: controller
                        i18n: root.i18n
                        startMs: timeline.startMs
                        endMs: timeline.endMs
                    }
                    Item {
                        Layout.fillHeight: true
                    }
                }
                TrimTimeline {
                    id: timeline
                    Layout.fillWidth: true
                    Layout.columnSpan: 2
                    i18n: root.i18n
                    durationMs: controller.durationMs
                    currentMs: preview.currentMs
                    controlsEnabled: root.sourceMutable
                    onSeekRequested: positionMs => preview.seek(positionMs)
                    onPlaySelectionRequested: (startMs, endMs) => preview.playSelection(startMs, endMs)
                }
            }
        }
    }
}
