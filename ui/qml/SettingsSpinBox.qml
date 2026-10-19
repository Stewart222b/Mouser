import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Theme.js" as Theme

SpinBox {
    id: control
    readonly property var theme: Theme.palette(uiState.darkMode)
    implicitHeight: Theme.controlHeight
    Layout.minimumHeight: Theme.controlHeight
    Layout.maximumHeight: Theme.controlHeight
    topPadding: 0
    bottomPadding: 0
    font { family: uiState.fontFamily; pixelSize: 13 }
    background: Rectangle {
        radius: 4
        color: control.hovered ? control.theme.bgSubtle : "transparent"
        border.width: control.activeFocus ? 2 : 1
        border.color: control.activeFocus ? control.theme.accent : control.theme.border
    }
}
