import QtQuick
import QtQuick.Controls
import "Theme.js" as Theme

Item {
    id: preview
    property int selectedSector: 0
    property var labels: []
    property var fullLabels: []
    readonly property var theme: Theme.palette(uiState.darkMode)
    readonly property real outerRadius: Math.max(0, Math.min(220, width / 2 - 24, height / 2 - 24))
    readonly property real labelRadius: outerRadius * 0.74
    readonly property var directions: [lm.strings["ui.ring_north"], lm.strings["ui.ring_east"],
                                       lm.strings["ui.ring_south"], lm.strings["ui.ring_west"]]
    signal sectorSelected(int index)
    implicitWidth: 380
    implicitHeight: 360

    Keys.onUpPressed: sectorSelected(0)
    Keys.onRightPressed: sectorSelected(1)
    Keys.onDownPressed: sectorSelected(2)
    Keys.onLeftPressed: sectorSelected(3)
    Canvas {
        id: ringCanvas
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var cx = width / 2, cy = height / 2
            var outer = preview.outerRadius
            var inner = outer * 0.52
            for (var i = 0; i < 4; ++i) {
                var start = (-135 + 90 * i + 2) * Math.PI / 180
                var end = (-45 + 90 * i - 2) * Math.PI / 180
                ctx.beginPath()
                ctx.arc(cx, cy, outer, start, end, false)
                ctx.arc(cx, cy, inner, end, start, true)
                ctx.closePath()
                ctx.fillStyle = i === preview.selectedSector ? preview.theme.accentDim : preview.theme.bgCard
                ctx.fill()
                ctx.strokeStyle = i === preview.selectedSector ? preview.theme.accent : preview.theme.border
                ctx.lineWidth = 1
                ctx.stroke()
            }
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }
    onSelectedSectorChanged: ringCanvas.requestPaint()
    onThemeChanged: ringCanvas.requestPaint()
    Text {
        anchors.centerIn: parent
        text: "Actions\nRing"
        horizontalAlignment: Text.AlignHCenter
        font { family: uiState.fontFamily; pixelSize: 13 }
        color: preview.theme.textSecondary
    }
    Repeater {
        model: 4
        Button {
            id: sectorButton
            required property int index
            objectName: "ringSector_" + index
            x: preview.width / 2 + Math.sin(index * Math.PI / 2) * preview.labelRadius - width / 2
            y: preview.height / 2 - Math.cos(index * Math.PI / 2) * preview.labelRadius - height / 2
            width: 138; height: 66
            checkable: true
            checked: preview.selectedSector === index
            Accessible.name: preview.directions[index] + ": " + (preview.fullLabels[index] || preview.labels[index] || "")
            ToolTip.visible: hovered
            ToolTip.delay: 500
            ToolTip.text: preview.fullLabels[index] || preview.labels[index] || ""
            onClicked: preview.sectorSelected(index)
            background: Rectangle {
                radius: 4
                color: sectorButton.hovered ? preview.theme.bgCardHover : "transparent"
                border.width: sectorButton.activeFocus ? 2 : 0
                border.color: preview.theme.accent
            }
            contentItem: Column {
                spacing: 4
                Text {
                    width: parent.width
                    text: preview.directions[sectorButton.index]
                    horizontalAlignment: Text.AlignHCenter
                    font { family: uiState.fontFamily; pixelSize: 12 }
                    color: preview.theme.textSecondary
                }
                Text {
                    width: parent.width
                    text: preview.labels[sectorButton.index] || ""
                    horizontalAlignment: Text.AlignHCenter
                    font { family: uiState.fontFamily; pixelSize: 13; weight: sectorButton.checked ? Font.DemiBold : Font.Normal }
                    color: sectorButton.checked ? preview.theme.accent : preview.theme.textPrimary
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                    elide: Text.ElideRight
                }
            }
        }
    }
}
