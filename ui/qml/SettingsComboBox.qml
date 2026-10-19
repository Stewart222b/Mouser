import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Theme.js" as Theme

ComboBox {
    id: control
    readonly property var theme: Theme.palette(uiState.darkMode)
    implicitHeight: Theme.controlHeight
    Layout.minimumHeight: Theme.controlHeight
    Layout.maximumHeight: Theme.controlHeight
    leftPadding: 12
    rightPadding: 32
    topPadding: 0
    bottomPadding: 0
    font { family: uiState.fontFamily; pixelSize: 13 }
    contentItem: Text {
        text: control.displayText
        font: control.font
        color: control.enabled ? control.theme.textPrimary : control.theme.textDim
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    background: Rectangle {
        radius: 4
        color: control.hovered ? control.theme.bgSubtle : "transparent"
        border.width: control.visualFocus ? 2 : 1
        border.color: control.visualFocus ? control.theme.accent : control.theme.border
    }
}
