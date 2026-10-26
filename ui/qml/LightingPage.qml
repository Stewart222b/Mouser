import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Theme.js" as Theme

Item {
    id: page
    readonly property var theme: Theme.palette(uiState.darkMode)
    property var s: lm.strings
    readonly property var controller: backend.g502
    readonly property var lighting: controller.state.lighting || ({})
    readonly property bool editable: controller.supported && !!controller.state.writable && !!lighting.supported && !controller.busy
    readonly property bool pending: normalGroup.dirty || idleGroup.dirty

    Connections {
        target: page.controller
        function onLightingSaved() { normalGroup.reset(); idleGroup.reset() }
        function onSupportedChanged() { normalGroup.reset(); idleGroup.reset() }
    }
    SettingsPageHeader {
        x: settingsContent.x
        y: Theme.pageTopPadding
        width: settingsContent.width
        title: s["light.title"]
    }
    ScrollView {
        id: pageScroll
        anchors.fill: parent
        anchors.topMargin: Theme.pageTopPadding + Theme.pageHeaderHeight
        contentWidth: availableWidth
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        SettingsContent {
            id: settingsContent
            viewportWidth: pageScroll.availableWidth
            spacing: 0
            SettingsForm {
            Text {
                width: parent.width
                topPadding: 12
                bottomPadding: 12
                text: s["light.scope"]
                wrapMode: Text.WordWrap
                color: page.theme.textSecondary
                font { family: uiState.fontFamily; pixelSize: 12 }
            }
            SettingRow {
                width: parent.width
                label: page.controller.busy ? s["mouse.onboard_reading"] : s["light.device_status"]
                description: page.controller.error !== "" ? (lm.strings, lm.trStatus(page.controller.error))
                    : page.controller.message !== "" ? (lm.strings, lm.trStatus(page.controller.message))
                    : !page.controller.state.writable ? s["mouse.onboard_readonly"] : s["light.ready"]
                SettingsButton {
                    text: s["mouse.onboard_refresh"]
                    enabled: page.controller.supported && !page.controller.busy
                    onClicked: page.controller.refresh()
                }
            }
            LightingGroup {
                id: normalGroup
                objectName: "normalLighting"
                width: parent.width
                enabled: page.editable
                title: s["light.normal"]
                description: s["light.normal_desc"]
                state: page.lighting.normal || ({})
                customAnimation: !!page.lighting.customAnimation
            }
            LightingGroup {
                id: idleGroup
                objectName: "idleLighting"
                width: parent.width
                enabled: page.editable
                title: s["light.idle"]
                description: s["light.idle_desc"]
                state: page.lighting.idle || ({})
                customAnimation: !!page.lighting.customAnimation
            }
            Text {
                width: parent.width
                topPadding: 20
                bottomPadding: 12
                text: page.lighting.customAnimation ? s["light.animation_notice"] : s["light.save_hint"]
                wrapMode: Text.WordWrap
                color: page.theme.textSecondary
                font { family: uiState.fontFamily; pixelSize: 12 }
            }
            RowLayout {
                width: parent.width
                spacing: 12
                SettingsButton {
                    objectName: "saveLighting"
                    text: s["mouse.onboard_save"]
                    enabled: page.editable && page.pending && normalGroup.valid && idleGroup.valid
                    onClicked: {
                        var changes = {}
                        if (normalGroup.dirty && normalGroup.mode !== "keep") changes.normal = normalGroup.draft()
                        if (idleGroup.dirty && idleGroup.mode !== "keep") changes.idle = idleGroup.draft()
                        page.controller.saveLighting(changes)
                    }
                }
                SettingsButton {
                    text: s["light.discard"]
                    flat: true
                    enabled: page.pending && !page.controller.busy
                    onClicked: { normalGroup.reset(); idleGroup.reset() }
                }
                Item { Layout.fillWidth: true }
            }
            Item { width: 1; height: 28 }
            }
        }
    }
}
