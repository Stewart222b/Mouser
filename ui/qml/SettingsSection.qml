import QtQuick
import "Theme.js" as Theme

Item {
    id: section
    property string title: ""
    default property alias settingData: body.data
    readonly property var theme: Theme.palette(uiState.darkMode)
    implicitHeight: heading.implicitHeight + body.implicitHeight + 34
    Text {
        id: heading
        y: 24
        width: parent.width
        text: section.title
        font { family: uiState.fontFamily; pixelSize: 16; weight: Font.DemiBold }
        color: section.theme.textPrimary
        wrapMode: Text.WordWrap
    }
    Column {
        id: body
        width: parent.width
        y: heading.y + heading.implicitHeight + 10
    }
}
