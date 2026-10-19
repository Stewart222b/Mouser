import QtQuick
import QtQuick.Controls
import "Theme.js" as Theme

Button {
    id: control
    property string iconName: ""
    property string labelObjectName: ""
    property bool selected: false
    readonly property var theme: Theme.palette(uiState.darkMode)
    implicitHeight: 42
    leftPadding: 12
    rightPadding: 12
    topPadding: 0
    bottomPadding: 0
    topInset: 6
    bottomInset: 6
    hoverEnabled: true
    font { family: uiState.fontFamily; pixelSize: 14; weight: selected ? Font.DemiBold : Font.Normal }
    Accessible.name: text
    Accessible.selected: selected

    contentItem: Item {
        opacity: control.enabled ? 1 : 0.45
        AppIcon {
            objectName: control.objectName + "_icon"
            name: control.iconName
            width: 18; height: 18
            anchors.verticalCenter: parent.verticalCenter
            iconColor: control.theme.textPrimary
        }
        FontMetrics { id: labelMetrics; font: label.font }
        Text {
            id: label
            objectName: control.labelObjectName
            // Keep Latin baselines stable when a label contains descenders.
            readonly property string alignmentSample: /[\u3400-\u9fff]/.test(text) ? "中" : "Hx"
            readonly property rect alignmentBounds: (labelMetrics.font, labelMetrics.tightBoundingRect(alignmentSample))
            x: 29
            width: Math.max(0, parent.width - x)
            y: parent.height / 2 - baselineOffset - alignmentBounds.y - alignmentBounds.height / 2
            text: control.text
            font: control.font
            color: control.theme.textPrimary
            elide: Text.ElideRight
        }
    }
    background: Rectangle {
        objectName: control.objectName + "_background"
        radius: 4
        color: control.selected ? control.theme.accentDim
             : control.hovered ? control.theme.bgCardHover : "transparent"
        border.width: control.activeFocus ? 1 : 0
        border.color: control.theme.accent
        Rectangle {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            width: 3; height: 17; radius: 2
            color: control.theme.accent
            visible: control.selected
        }
    }
}
