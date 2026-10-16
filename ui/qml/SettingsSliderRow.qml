import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

SettingRow {
    id: row
    property real from: 0
    property real to: 100
    property real stepSize: 1
    property real value: from
    property real displayMultiplier: 1
    property string suffix: ""
    property bool editableValue: false
    property bool pendingEdit: false
    signal valueEdited(real newValue)

    onValueChanged: {
        if (!slider.pressed) slider.value = value
    }
    WheelSafeSlider {
        id: slider
        objectName: row.objectName + "_slider"
        Layout.preferredWidth: Math.min(245, Math.max(120, row.width * 0.28))
        from: row.from
        to: row.to
        stepSize: row.stepSize
        value: row.value
        accentColor: row.theme.accent
        accentDimColor: row.theme.accentDim
        trackColor: row.theme.border
        activeFocusOnTab: true
        Accessible.role: Accessible.Slider
        Accessible.name: row.label
        Accessible.description: Math.round(value * row.displayMultiplier) + " " + row.suffix
        function nudge(delta) {
            value = Math.max(from, Math.min(to, value + delta * stepSize))
            moved()
        }
        Keys.onLeftPressed: nudge(-1)
        Keys.onDownPressed: nudge(-1)
        Keys.onRightPressed: nudge(1)
        Keys.onUpPressed: nudge(1)
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Home) { value = from; moved(); event.accepted = true }
            else if (event.key === Qt.Key_End) { value = to; moved(); event.accepted = true }
        }
        onMoved: {
            row.pendingEdit = true
            if (!pressed) saveDelay.restart()
        }
        onPressedChanged: {
            if (!pressed && row.pendingEdit) {
                saveDelay.stop()
                row.pendingEdit = false
                row.valueEdited(value)
            }
        }
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            radius: 4
            border.width: slider.activeFocus ? 1 : 0
            border.color: row.theme.accent
        }
    }
    SpinBox {
        objectName: row.objectName + "_value"
        visible: row.editableValue
        Layout.preferredWidth: 160
        from: Math.round(row.from)
        to: Math.round(row.to)
        stepSize: Math.round(row.stepSize)
        value: Math.round(slider.value)
        editable: true
        font { family: uiState.fontFamily; pixelSize: 13 }
        Accessible.name: row.label
        onValueModified: row.valueEdited(value)
    }
    Text {
        Layout.preferredWidth: row.editableValue ? implicitWidth : 70
        text: row.editableValue ? row.suffix : Math.round(slider.value * row.displayMultiplier) + " " + row.suffix
        font { family: uiState.fontFamily; pixelSize: 13 }
        color: row.theme.textPrimary
        horizontalAlignment: Text.AlignRight
    }
    Timer {
        id: saveDelay
        interval: 300
        onTriggered: {
            if (row.pendingEdit && !slider.pressed) {
                row.pendingEdit = false
                row.valueEdited(slider.value)
            }
        }
    }
}
