import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Theme.js" as Theme

Button {
    id: control
    readonly property var theme: Theme.palette(uiState.darkMode)
    implicitHeight: Theme.controlHeight
    Layout.minimumHeight: Theme.controlHeight
    Layout.maximumHeight: Theme.controlHeight
    topInset: 0
    bottomInset: 0
    leftPadding: 12
    rightPadding: 12
    topPadding: 0
    bottomPadding: 0
    font { family: uiState.fontFamily; pixelSize: 13 }
    background: Rectangle {
        radius: 4
        color: control.down || control.checked ? control.theme.accentDim
             : control.hovered ? control.theme.bgCardHover
             : control.flat ? "transparent" : control.theme.bgSubtle
        border.width: control.visualFocus ? 2 : control.flat ? 0 : 1
        border.color: control.visualFocus ? control.theme.accent : control.theme.border
    }
}
