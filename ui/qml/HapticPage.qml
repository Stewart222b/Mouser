import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import "Theme.js" as Theme

Item {
    id: hapticPage
    readonly property var theme: Theme.palette(uiState.darkMode)
    property var s: lm.strings
    property bool advancedExpanded: false
    readonly property var hapticLevels: [
        {label: s["haptic.level_subtle"], value: 0},
        {label: s["haptic.level_low"], value: 1},
        {label: s["haptic.level_medium"], value: 2},
        {label: s["haptic.level_high"], value: 3}
    ]
    readonly property var forcePresets: {
        var lo = backend.forceSensingMin
        var span = backend.forceSensingMax - lo
        return [
            {label: s["haptic.force_light"], value: lo},
            {label: s["haptic.force_low"], value: Math.round(lo + span * 0.33)},
            {label: s["haptic.force_medium"], value: Math.round(lo + span * 0.66)},
            {label: s["haptic.force_firm"], value: Math.round(lo + span)}
        ]
    }
    readonly property int nearestForceIndex: {
        var best = 0
        for (var i = 1; i < forcePresets.length; ++i)
            if (Math.abs(backend.forceSensitivity - forcePresets[i].value)
                    < Math.abs(backend.forceSensitivity - forcePresets[best].value)) best = i
        return best
    }
    function buttonEnabled(key) {
        var rows = backend.hapticEnabledButtons
        for (var i = 0; i < rows.length; ++i) if (rows[i].key === key) return true
        return false
    }
    function actionEnabled(id) {
        var rows = backend.hapticEnabledActions
        for (var i = 0; i < rows.length; ++i) if (rows[i].id === id) return true
        return false
    }

    ScrollView {
        id: pageScroll
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        SettingsContent {
            objectName: "hapticSettingsContent"
            viewportWidth: pageScroll.availableWidth
            spacing: 0
            Item { width: 1; height: Theme.pageTopPadding }
            SettingsPageHeader {
                width: Math.min(parent.width, Theme.settingsMaximumWidth)
                title: s["haptic.title"]
                SettingsSwitch {
                    objectName: "hapticEnableSwitch"
                    text: s["haptic.enabled"]
                    checked: backend.hapticEnabled
                    font { family: uiState.fontFamily; pixelSize: 13 }
                    onClicked: backend.setHapticEnabled(checked)
                }
            }
            SettingsForm {
                objectName: "hapticSettingsForm"
                SettingRow {
                    width: parent.width
                    label: s["haptic.level"]
                    enabled: backend.hapticEnabled
                    ButtonGroup { id: levelGroup }
                    Repeater {
                        model: hapticPage.hapticLevels
                        RadioButton {
                            implicitHeight: Theme.controlHeight
                            topPadding: 0; bottomPadding: 0
                            required property var modelData
                            objectName: "hapticLevel_" + modelData.value
                            text: modelData.label
                            checked: backend.hapticLevel === modelData.value
                            ButtonGroup.group: levelGroup
                            font { family: uiState.fontFamily; pixelSize: 13 }
                            onClicked: backend.setHapticLevel(modelData.value)
                        }
                    }
                }
                Item { width: 1; height: 25 }
                Text {
                    text: s["ui.haptic_on_press"]
                    font { family: uiState.fontFamily; pixelSize: 16; weight: Font.DemiBold }
                    color: hapticPage.theme.textPrimary
                }
                Item { width: 1; height: 7 }
                Repeater {
                    model: backend.hapticButtonRows
                    SettingRow {
                        required property var modelData
                        width: parent.width
                        label: (lm.strings, lm.trButton(modelData.label))
                        enabled: backend.hapticEnabled
                        SettingsSwitch {
                            objectName: "buttonHaptic_" + modelData.key
                            checked: hapticPage.buttonEnabled(modelData.key)
                            Accessible.name: (lm.strings, lm.trButton(modelData.label))
                            onClicked: backend.setButtonHaptic(modelData.key, checked)
                        }
                    }
                }
                Item { width: 1; height: 25 }
                Text {
                    text: s["ui.other_feedback"]
                    font { family: uiState.fontFamily; pixelSize: 16; weight: Font.DemiBold }
                    color: hapticPage.theme.textPrimary
                }
                Item { width: 1; height: 7 }
                SettingRow {
                    width: parent.width
                    visible: backend.screenSwitchHapticAvailable
                    label: s["haptic.screen_switch_title"]
                    description: s["haptic.screen_switch_desc"]
                    enabled: backend.hapticEnabled
                    SettingsSwitch {
                        objectName: "screenSwitchHapticToggle"
                        checked: backend.screenSwitchHaptic
                        Accessible.name: s["haptic.screen_switch_title"]
                        onClicked: backend.setScreenSwitchHaptic(checked)
                    }
                }
                SettingRow {
                    width: parent.width
                    visible: backend.deviceHasActionsRing
                    label: s["haptic.ring_hover_title"]
                    description: s["haptic.ring_hover_desc"]
                    enabled: backend.hapticEnabled
                    SettingsSwitch {
                        objectName: "ringHoverHapticSwitch"
                        checked: backend.actionsRingHoverHaptic
                        Accessible.name: s["haptic.ring_hover_title"]
                        onClicked: backend.setActionsRingHoverHaptic(checked)
                    }
                }
                SettingsButton {
                    objectName: "hapticAdvancedButton"
                    leftPadding: 0
                    text: (hapticPage.advancedExpanded ? "\u2212  " : "+  ") + s["ui.advanced"]
                    flat: true
                    onClicked: hapticPage.advancedExpanded = !hapticPage.advancedExpanded
                    checkable: true
                    checked: hapticPage.advancedExpanded
                }
                Column {
                    width: parent.width
                    visible: hapticPage.advancedExpanded
                    SettingRow {
                        width: parent.width
                        visible: backend.forceSensingSupported
                        label: s["haptic.force_title"]
                        description: s["haptic.force_desc"]
                        SettingsComboBox {
                            objectName: "forceSensitivityCombo"
                            model: hapticPage.forcePresets
                            textRole: "label"
                            currentIndex: hapticPage.nearestForceIndex
                            font { family: uiState.fontFamily; pixelSize: 13 }
                            onActivated: function(index) { backend.setForceSensitivity(hapticPage.forcePresets[index].value) }
                        }
                    }
                    Text {
                        width: parent.width
                        topPadding: 8; bottomPadding: 8
                        visible: backend.forceSensingSupported && backend.forceSensitivity < backend.forceSensingDefault
                        text: s["haptic.force_warning"]
                        wrapMode: Text.WordWrap
                        font { family: uiState.fontFamily; pixelSize: 12 }
                        color: hapticPage.theme.warning
                    }
                    SettingRow {
                        width: parent.width
                        label: s["haptic.dedup_title"]
                        description: s["haptic.dedup_desc"]
                        enabled: backend.hapticEnabled
                        SettingsSwitch {
                            objectName: "hapticDedupSwitch"
                            checked: backend.hapticDedup
                            Accessible.name: s["haptic.dedup_title"]
                            onClicked: backend.setHapticDedup(checked)
                        }
                    }
                    Item { width: 1; height: 20 }
                    Text {
                        text: s["haptic.actions_title"]
                        font { family: uiState.fontFamily; pixelSize: 14; weight: Font.DemiBold }
                        color: hapticPage.theme.textPrimary
                    }
                    Text {
                        width: parent.width
                        topPadding: 6; bottomPadding: 8
                        text: s["ui.action_feedback_hint"]
                        wrapMode: Text.WordWrap
                        font { family: uiState.fontFamily; pixelSize: 12 }
                        color: hapticPage.theme.textSecondary
                    }
                    Repeater {
                        model: backend.hapticActionRows
                        SettingRow {
                            required property var modelData
                            width: parent.width
                            label: (lm.strings, lm.trAction(modelData.label))
                            enabled: backend.hapticEnabled
                            SettingsSwitch {
                                objectName: "actionHaptic_" + modelData.id
                                checked: hapticPage.actionEnabled(modelData.id)
                                Accessible.name: (lm.strings, lm.trAction(modelData.label))
                                onClicked: backend.setActionHaptic(modelData.id, checked)
                            }
                        }
                    }
                    Text {
                        width: parent.width
                        topPadding: 14
                        text: s["haptic.experimental_note"]
                        wrapMode: Text.WordWrap
                        font { family: uiState.fontFamily; pixelSize: 12 }
                        color: hapticPage.theme.textSecondary
                    }
                }
            }
            Item { width: 1; height: 28 }
        }
    }
}
