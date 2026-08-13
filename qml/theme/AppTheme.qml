import QtQuick

QtObject {
    readonly property color accent: "#7c3aed"
    readonly property color danger: "#dc2626"
    readonly property color panel: palette.window
    readonly property color panelRaised: palette.base
    readonly property color border: palette.mid
    readonly property color mutedText: palette.placeholderText
    readonly property color text: palette.windowText

    property SystemPalette palette: SystemPalette {
        colorGroup: SystemPalette.Active
    }
}
