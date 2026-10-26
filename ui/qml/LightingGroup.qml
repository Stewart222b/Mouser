import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Theme.js" as Theme

Column {
    id: group
    property string title: ""
    property string description: ""
    property var state: ({})
    property bool customAnimation: false
    property bool dirty: false
    property bool initialized: false
    property string mode: "keep"
    property var s: lm.strings
    readonly property var theme: Theme.palette(uiState.darkMode)
    readonly property bool needsColor: mode === "static" || mode === "breathe"
    readonly property bool animated: mode === "cycle" || mode === "breathe"
    readonly property bool valid: !needsColor || /^#[0-9a-fA-F]{6}$/.test(colorInput.text)
    readonly property var modes: ["keep", "off", "static", "breathe", "cycle"]
    readonly property var choices: [s["light.keep"], s["light.off"], s["light.static"], s["light.breathe"], s["light.cycle"]]
    spacing: 0

    function load() {
        if (!initialized) return
        mode = customAnimation ? "keep" : (state.mode || "keep")
        effectChoice.currentIndex = Math.max(0, modes.indexOf(mode))
        colorInput.text = state.color || "#66AAFF"
        periodInput.value = Math.max(1, Math.min(20, Math.round((state.periodMs || 5000) / 1000)))
    }
    function reset() { dirty = false; load() }
    function draft() { return {mode: mode, color: colorInput.text, periodMs: periodInput.value * 1000} }
    onStateChanged: if (!dirty) load()
    onCustomAnimationChanged: if (!dirty) load()
    Component.onCompleted: { initialized = true; load() }

    Text {
        width: parent.width
        topPadding: 24
        bottomPadding: 8
        text: group.title
        color: group.theme.textPrimary
        font { family: uiState.fontFamily; pixelSize: 17; weight: Font.DemiBold }
    }
    Text {
        width: parent.width
        bottomPadding: 12
        text: group.description
        wrapMode: Text.WordWrap
        color: group.theme.textSecondary
        font { family: uiState.fontFamily; pixelSize: 12 }
    }
    SettingRow {
        width: parent.width
        label: s["light.effect"]
        description: group.customAnimation ? s["light.custom_active"] : ""
        SettingsComboBox {
            id: effectChoice
            objectName: group.objectName + "Effect"
            Layout.preferredWidth: 220
            model: group.choices
            Accessible.name: group.title + " " + s["light.effect"]
            onActivated: function(index) {
                group.mode = group.modes[index]
                group.dirty = group.mode !== "keep"
            }
        }
    }
    SettingRow {
        width: parent.width
        visible: group.needsColor
        label: s["light.color"]
        Rectangle {
            width: 24; height: 24; radius: 4
            color: group.valid ? colorInput.text : "transparent"
            border.width: 1; border.color: group.theme.border
        }
        TextField {
            id: colorInput
            objectName: group.objectName + "Color"
            Layout.preferredWidth: 150
            maximumLength: 7
            placeholderText: "#66AAFF"
            Accessible.name: group.title + " " + s["light.color"]
            onTextEdited: group.dirty = true
        }
    }
    SettingRow {
        width: parent.width
        visible: group.animated
        label: s["light.period"]
        SpinBox {
            id: periodInput
            objectName: group.objectName + "Period"
            from: 1; to: 20; value: 5
            Layout.preferredWidth: 150
            Accessible.name: group.title + " " + s["light.period"]
            onValueModified: group.dirty = true
        }
    }
}
