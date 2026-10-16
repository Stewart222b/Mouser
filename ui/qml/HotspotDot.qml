import QtQuick
import "Theme.js" as Theme

/*  A single clickable hotspot dot placed over the mouse image.
    Position is given as normalised coordinates (0-1) within the
    source image, so it adapts when the image is scaled.

    An annotation label with a connecting line is drawn from the
    dot to an offset position.                                    */

Item {
    id: hotspot
    readonly property var theme: Theme.palette(uiState.darkMode)

    // ── Required properties ───────────────────────────────────
    required property var imgItem         // the Image element
    required property real normX          // 0-1 x in source image
    required property real normY          // 0-1 y in source image
    required property string buttonKey    // config key (e.g. "middle")
    property bool isHScroll: false        // true for horizontal scroll dot

    property string label: ""
    property string sublabel: ""
    property string labelSide: "right"    // "left" or "right"
    property real labelOffX: 120          // x offset for annotation
    property real labelOffY: -30          // y offset for annotation

    // ── Computed centre ───────────────────────────────────────
    property real cx: imgItem.x + imgItem.offX + normX * imgItem.paintedWidth
    property real cy: imgItem.y + imgItem.offY + normY * imgItem.paintedHeight

    property bool isSelected: isHScroll ? mousePage.selectedButton === "hscroll_left"
                                        : mousePage.selectedButton === buttonKey
    property bool isHovered: dotMa.containsMouse
    property real labelWidth: labelCol.implicitWidth + 20
    property real labelHeight: labelCol.implicitHeight + 14
    property real leftCandidateX: cx + labelOffX - labelWidth - 14
    property real rightCandidateX: cx + labelOffX + 6
    property bool leftFits: leftCandidateX >= 8
    property bool rightFits: rightCandidateX + labelWidth <= width - 8
    property string effectiveLabelSide: labelSide === "left"
                                       ? (leftFits || !rightFits ? "left" : "right")
                                       : (rightFits || !leftFits ? "right" : "left")
    property real unclampedLabelX: effectiveLabelSide === "left"
                                   ? leftCandidateX : rightCandidateX
    property real labelX: Math.max(8, Math.min(width - labelWidth - 8, unclampedLabelX))
    property real labelY: Math.max(8, Math.min(height - labelHeight - 8, cy + labelOffY - 8))
    property real labelCenterX: labelX + labelWidth / 2
    property bool sourceIsRightOfLabel: cx >= labelCenterX
    property real lineEndX: sourceIsRightOfLabel
                            ? labelX + labelWidth - 6
                            : labelX + 6
    property real lineEndY: labelY + labelHeight / 2

    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: label

    function triggerSelection() {
        if (isHScroll)
            mousePage.selectHScroll()
        else
            mousePage.selectButton(buttonKey)
    }

    Keys.onReturnPressed: triggerSelection()
    Keys.onEnterPressed: triggerSelection()
    Keys.onSpacePressed: triggerSelection()

    // ── Glow ring ─────────────────────────────────────────────
    Rectangle {
        id: glow
        visible: isSelected || hotspot.activeFocus
        x: cx - width / 2
        y: cy - height / 2
        width: 30; height: 30; radius: 15
        color: "transparent"
        border.width: isSelected || hotspot.activeFocus ? 2 : 1
        border.color: isSelected || hotspot.activeFocus
                      ? theme.accent
                      : Theme.alpha(theme.accent, 0.3)
        opacity: isSelected || isHovered || hotspot.activeFocus ? 1 : 0.6

        Behavior on opacity { NumberAnimation { duration: 200 } }
        Behavior on border.width { NumberAnimation { duration: 150 } }

        // Pulse animation when selected

    }

    // ── Dot ───────────────────────────────────────────────────
    Rectangle {
        id: dot
        x: cx - width / 2
        y: cy - height / 2
        width: 12; height: 12; radius: 6
        color: isSelected ? theme.accent : theme.textSecondary
        border.width: 2
        border.color: hotspot.activeFocus ? theme.textPrimary : Qt.rgba(0, 0, 0, 0.3)

        scale: isHovered ? 1.2 : 1.0
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    // ── Click area (larger than the dot for easier targeting) ─
    MouseArea {
        id: dotMa
        x: cx - 18
        y: cy - 18
        width: 36; height: 36
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: hotspot.triggerSelection()
    }

    // ── Connecting line ───────────────────────────────────────
    Canvas {
        id: lineCanvas
        visible: isSelected || isHovered || hotspot.activeFocus
        anchors.fill: parent
        z: 0
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.strokeStyle = isSelected ? theme.accent : Theme.alpha(theme.accent, 0.35)
            ctx.lineWidth = 1
            ctx.setLineDash([])
            ctx.beginPath()
            ctx.moveTo(cx, cy)
            ctx.lineTo(lineEndX, lineEndY)
            ctx.stroke()
        }

        // Repaint when position or selection changes
        Connections {
            target: hotspot
            function onCxChanged() { lineCanvas.requestPaint() }
            function onCyChanged() { lineCanvas.requestPaint() }
            function onIsSelectedChanged() { lineCanvas.requestPaint() }
            function onLabelXChanged() { lineCanvas.requestPaint() }
            function onLabelYChanged() { lineCanvas.requestPaint() }
        }
        Component.onCompleted: requestPaint()
    }

    // ── Annotation label ──────────────────────────────────────
    Rectangle {
        id: labelBg
        visible: isSelected || isHovered || hotspot.activeFocus
        z: 2
        x: labelX
        y: labelY
        width: labelWidth
        height: labelHeight
        radius: 4
        color: isSelected ? theme.accentDim : theme.bgCard
        border.width: isSelected || hotspot.activeFocus ? 1 : 0
        border.color: Theme.alpha(theme.accent, 0.3)

        Behavior on color { ColorAnimation { duration: 200 } }

        Column {
            id: labelCol
            anchors {
                left: parent.left; leftMargin: 10
                verticalCenter: parent.verticalCenter
            }
            spacing: 1

            Text {
                // lm.strings read creates a binding dependency → auto-updates on language change
                text: { var _lang = lm.strings; return lm.trButton(hotspot.label) }
                font { family: uiState.fontFamily; pixelSize: 12; bold: true }
                color: isSelected ? theme.accent : theme.textPrimary
            }

            Text {
                text: { var _lang = lm.strings; return lm.trAction(hotspot.sublabel) }
                font { family: uiState.fontFamily; pixelSize: 10 }
                color: theme.textSecondary
                visible: hotspot.sublabel !== ""
                width: Math.min(implicitWidth, 220)
                elide: Text.ElideRight
            }
        }

        // Make label clickable too
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: hotspot.triggerSelection()
        }
    }

    // ── Small dot at the end of the line ──────────────────────
    Rectangle {
        z: 1
        visible: isSelected || isHovered || hotspot.activeFocus
        x: lineEndX - 3
        y: lineEndY - 3
        width: 6; height: 6; radius: 3
        color: isSelected ? theme.accent : Theme.alpha(theme.accent, 0.5)
    }
}
