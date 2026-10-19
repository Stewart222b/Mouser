import QtQuick
import QtQuick.Layouts
import "Theme.js" as Theme

RowLayout {
    id: header
    objectName: "settingsPageHeader"
    property string title: ""
    readonly property var theme: Theme.palette(uiState.darkMode)
    width: parent.width
    height: Theme.pageHeaderHeight
    implicitHeight: Theme.pageHeaderHeight
    Layout.fillWidth: true
    Layout.minimumHeight: Theme.pageHeaderHeight
    Layout.maximumHeight: Theme.pageHeaderHeight
    spacing: 16

    Text {
        objectName: "settingsPageTitle"
        text: header.title
        Layout.fillWidth: true
        Layout.minimumHeight: Theme.pageHeaderHeight
        Layout.maximumHeight: Theme.pageHeaderHeight
        verticalAlignment: Text.AlignVCenter
        font { family: uiState.fontFamily; pixelSize: 24; weight: Font.DemiBold }
        color: header.theme.textPrimary
    }
}
