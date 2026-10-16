import QtQuick
import QtQuick.Layouts
import "Theme.js" as Theme

Item {
    id: row
    property string label: ""
    property string description: ""
    readonly property var theme: Theme.palette(uiState.darkMode)
    readonly property bool stacked: width < 570 && controls.implicitWidth > width * 0.45
    default property alias controlData: controls.data
    implicitHeight: (stacked ? labels.implicitHeight + controls.implicitHeight + 12
                            : Math.max(labels.implicitHeight, controls.implicitHeight)) + 28
    opacity: enabled ? 1 : 0.45

    Column {
        id: labels
        y: row.stacked ? 14 : (row.height - implicitHeight) / 2
        width: row.stacked ? row.width : Math.max(80, row.width - controls.implicitWidth - 24)
        spacing: 4
        Text {
            width: parent.width
            text: row.label
            font { family: uiState.fontFamily; pixelSize: 14 }
            color: row.theme.textPrimary
            wrapMode: Text.WordWrap
        }
        Text {
            width: parent.width
            visible: text.length > 0
            text: row.description
            font { family: uiState.fontFamily; pixelSize: 12 }
            color: row.theme.textSecondary
            wrapMode: Text.WordWrap
        }
    }
    RowLayout {
        id: controls
        x: row.stacked ? 0 : row.width - implicitWidth
        y: row.stacked ? labels.y + labels.implicitHeight + 12 : (row.height - implicitHeight) / 2
        spacing: 8
    }
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color: row.theme.border
    }
}
