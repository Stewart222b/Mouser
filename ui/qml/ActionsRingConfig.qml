import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import "Theme.js" as Theme

Item {
    id: actionsRingConfig
    readonly property var theme: Theme.palette(uiState.darkMode)
    property var s: lm.strings
    property int selectedSector: 0
    property int pendingCustomSlot: -1
    property bool hasBlockingDialog: ringKeyCaptureDialog.visible
    readonly property var directions: [s["ui.ring_north"], s["ui.ring_east"], s["ui.ring_south"], s["ui.ring_west"]]

    Component.onCompleted: {
        if (!backend.actionsRingUseGlobal) backend.setRingEditProfile(backend.ringEditProfile)
    }
    function actionForSlot(index) {
        var slots = backend.actionsRingSlots
        return index >= 0 && index < slots.length ? slots[index] : "none"
    }
    function actionIndexForId(actionId) {
        var target = actionId.indexOf("custom:") === 0 ? "__custom__" : actionId
        var rows = backend.allActions
        for (var i = 0; i < rows.length; ++i) if (rows[i].id === target) return i
        return 0
    }
    function rebuildSlots(index, actionId) {
        var slots = backend.actionsRingSlots.slice()
        while (slots.length < 4) slots.push("none")
        slots[index] = actionId
        backend.setActionsRingSlots(slots)
    }
    SettingsPageHeader {
        x: settingsContent.x
        y: Theme.pageTopPadding
        width: settingsContent.width
        title: "Actions Ring"
    }
    ScrollView {
        id: pageScroll
        anchors.fill: parent
        anchors.topMargin: Theme.pageTopPadding + Theme.pageHeaderHeight
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        SettingsContent {
            id: settingsContent
            objectName: "ringSettingsContent"
            viewportWidth: pageScroll.availableWidth
            SettingsForm {
                objectName: "ringSettingsForm"
                SettingRow {
                    width: parent.width
                    label: s["ring.scope_title"]
                    description: backend.actionsRingUseGlobal ? s["ring.scope_global_desc"] : s["ring.scope_perapp_desc"]
                    SettingsSwitch {
                        objectName: "ringGlobalSwitch"
                        checked: backend.actionsRingUseGlobal
                        Accessible.name: s["ring.scope_title"]
                        onClicked: {
                            var profile = backend.ringEditProfile
                            backend.setActionsRingUseGlobal(checked)
                            if (!checked) backend.setRingEditProfile(profile)
                        }
                    }
                }
                SettingRow {
                    width: parent.width
                    visible: !backend.actionsRingUseGlobal
                    label: s["ui.edit_profile"]
                    SettingsComboBox {
                        objectName: "ringProfileCombo"
                        Layout.preferredWidth: 240
                        model: backend.profiles
                        textRole: "label"
                        currentIndex: {
                            var profiles = backend.profiles
                            for (var i = 0; i < profiles.length; ++i) if (profiles[i].name === backend.ringEditProfile) return i
                            return 0
                        }
                        displayText: currentIndex >= 0 && currentIndex < backend.profiles.length
                                     ? (lm.strings, lm.trProfile(backend.profiles[currentIndex].name, backend.profiles[currentIndex].label)) : ""
                        delegate: ItemDelegate {
                            required property var modelData
                            width: parent ? parent.width : implicitWidth
                            text: (lm.strings, lm.trProfile(modelData.name, modelData.label))
                            highlighted: ListView.isCurrentItem
                            font { family: uiState.fontFamily; pixelSize: 13 }
                        }
                        font { family: uiState.fontFamily; pixelSize: 13 }
                        onActivated: function(index) { backend.setRingEditProfile(backend.profiles[index].name) }
                    }
                }
                SettingsSliderRow {
                    objectName: "ringHoldSetting"
                    width: parent.width
                    label: s["ring.hold_delay"]
                    from: 100; to: 500; stepSize: 10
                    value: backend.actionsRingHoldMs
                    suffix: "ms"
                    onValueEdited: function(value) { backend.setActionsRingHoldMs(Math.round(value)) }
                }
            }
            RowLayout {
                objectName: "ringWorkbench"
                width: parent.width
                height: Math.max(374, Math.min(540, width * 0.45, actionsRingConfig.height - 280))
                spacing: 24
                RingPreview {
                    objectName: "ringPreview"
                    Layout.fillWidth: true
                    Layout.minimumWidth: 320
                    Layout.preferredWidth: 560
                    Layout.preferredHeight: 360
                    Layout.fillHeight: true
                    selectedSector: actionsRingConfig.selectedSector
                    labels: {
                        var strings = lm.strings
                        var slots = backend.actionsRingSlots
                        return [0, 1, 2, 3].map(function(index) {
                            return lm.trAction(backend.ringActionLabelFor(index < slots.length ? slots[index] : "none"))
                        })
                    }
                    fullLabels: {
                        var strings = lm.strings
                        var slots = backend.actionsRingSlots
                        return [0, 1, 2, 3].map(function(index) {
                            return lm.trAction(backend.actionLabelFor(index < slots.length ? slots[index] : "none"))
                        })
                    }
                    onSectorSelected: function(index) { actionsRingConfig.selectedSector = index }
                }
                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    Layout.topMargin: 30; Layout.bottomMargin: 30
                    color: actionsRingConfig.theme.border
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    Layout.minimumWidth: 300
                    Layout.preferredWidth: 360
                    Layout.maximumWidth: 420
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 12
                    Text {
                        text: actionsRingConfig.directions[actionsRingConfig.selectedSector]
                        font { family: uiState.fontFamily; pixelSize: 18; weight: Font.DemiBold }
                        color: actionsRingConfig.theme.textPrimary
                    }
                    Text {
                        text: s["ui.execute_action"]
                        font { family: uiState.fontFamily; pixelSize: 14 }
                        color: actionsRingConfig.theme.textPrimary
                    }
                    SettingsComboBox {
                        id: ringActionCombo
                        objectName: "ringActionCombo"
                        Layout.fillWidth: true
                        model: backend.allActions
                        textRole: "label"
                        font { family: uiState.fontFamily; pixelSize: 13 }
                        currentIndex: actionsRingConfig.actionIndexForId(actionsRingConfig.actionForSlot(actionsRingConfig.selectedSector))
                        displayText: (lm.strings, lm.trAction(backend.actionLabelFor(actionsRingConfig.actionForSlot(actionsRingConfig.selectedSector))))
                        delegate: ItemDelegate {
                            required property var modelData
                            width: parent ? parent.width : implicitWidth
                            text: (lm.strings, lm.trAction(modelData.label))
                            highlighted: ListView.isCurrentItem
                            font { family: uiState.fontFamily; pixelSize: 13 }
                        }
                        onActivated: function(index) {
                            var aid = backend.allActions[index].id
                            if (aid === "__custom__") {
                                actionsRingConfig.pendingCustomSlot = actionsRingConfig.selectedSector
                                ringKeyCaptureDialog.open("", "")
                            } else actionsRingConfig.rebuildSlots(actionsRingConfig.selectedSector, aid)
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: s["ui.ring_edit_hint"]
                        wrapMode: Text.WordWrap
                        font { family: uiState.fontFamily; pixelSize: 12 }
                        color: actionsRingConfig.theme.textSecondary
                    }
                }
            }
            Text {
                width: parent.width
                text: s["ui.ring_trigger_hint"]
                wrapMode: Text.WordWrap
                font { family: uiState.fontFamily; pixelSize: 12 }
                color: actionsRingConfig.theme.textSecondary
            }
            Item { width: 1; height: 28 }
        }
    }
    KeyCaptureDialog {
        id: ringKeyCaptureDialog
        objectName: "ringShortcutCaptureDialog"
        onCaptured: function(comboString) {
            if (actionsRingConfig.pendingCustomSlot >= 0) {
                actionsRingConfig.rebuildSlots(actionsRingConfig.pendingCustomSlot, "custom:" + comboString)
                actionsRingConfig.pendingCustomSlot = -1
            }
        }
        onCancelled: {
            actionsRingConfig.pendingCustomSlot = -1
            ringActionCombo.currentIndex = Qt.binding(function() {
                return actionsRingConfig.actionIndexForId(actionsRingConfig.actionForSlot(actionsRingConfig.selectedSector))
            })
        }
    }
}
