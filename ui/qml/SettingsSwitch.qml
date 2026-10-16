import QtQuick
import QtQuick.Controls
import "Theme.js" as Theme

Switch {
    id: control
    readonly property var theme: Theme.palette(uiState.darkMode)
    implicitWidth: text.length ? switchLabel.implicitWidth : 40
    implicitHeight: 30
    padding: 0
    font { family: uiState.fontFamily; pixelSize: 13 }
    indicator: Rectangle {
        x: 1
        y: (control.height - height) / 2
        width: 38; height: 20; radius: 10
        color: control.checked ? control.theme.accent : "transparent"
        border.width: control.checked ? 0 : 1
        border.color: control.theme.textSecondary
        Rectangle {
            x: control.checked ? 22 : 4
            y: 4
            width: 12; height: 12; radius: 6
            color: control.checked ? control.theme.bg : control.theme.textSecondary
        }
    }
    contentItem: Text {
        id: switchLabel
        leftPadding: control.text.length ? 48 : 0
        text: control.text
        font: control.font
        color: control.theme.textPrimary
        verticalAlignment: Text.AlignVCenter
    }
    background: Rectangle {
        color: "transparent"
        radius: 4
        border.width: control.activeFocus ? 2 : 0
        border.color: control.theme.accent
    }
}
