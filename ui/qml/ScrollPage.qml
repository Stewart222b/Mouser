import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import "Theme.js" as Theme

Item {
    id: scrollPage
    property bool applicationSettings: false
    readonly property var theme: Theme.palette(uiState.darkMode)
    property var s: lm.strings
    readonly property var appearanceOptions: [
        {label: s["scroll.system"], value: "system"},
        {label: s["scroll.light"], value: "light"},
        {label: s["scroll.dark"], value: "dark"}
    ]
    readonly property var wheelModes: [
        {label: s["scroll.ratchet"], value: "ratchet"},
        {label: s["scroll.freespin"], value: "freespin"}
    ]
    readonly property var dpiPresets: [400, 800, 1000, 1600, 2400, 4000, 6000, 8000].filter(function(value) {
        return value >= backend.deviceDpiMin && value <= backend.deviceDpiMax
    })
    function updateStatusText() {
        if (backend.updateInstallStatus === "checking")
            return s["scroll.update_checking"]
        if (backend.updateInstallStatus === "downloading")
            return s["scroll.update_downloading"]
        if (backend.updateInstallStatus === "verifying")
            return s["scroll.update_verifying"]
        if (backend.updateInstallStatus === "ready_to_install")
            return s["scroll.update_ready"]
        if (backend.updateInstallStatus === "installing")
            return s["scroll.update_installing"]
        if (backend.updateInstallStatus === "installed")
            return backend.updateInstallMessage ? s["scroll.update_installed_version"].replace("%1", backend.updateInstallMessage) : s["scroll.update_installed"]
        if (backend.updateInstallStatus === "cancelled")
            return s["scroll.update_cancelled"]
        if (backend.updateInstallStatus === "manual_fallback") {
            if (backend.updateInstallMessage === "macos")
                return s["scroll.update_manual_macos"]
            if (backend.updateInstallMessage === "linux")
                return s["scroll.update_manual_linux"]
            if (backend.updateInstallMessage === "windows")
                return s["scroll.update_manual_windows"]
            if (backend.updateInstallMessage === "no_asset")
                return s["scroll.update_no_asset"]
            return s["scroll.update_manual"]
        }
        if (backend.updateInstallStatus === "error") {
            var key = "scroll.update_error_" + backend.updateInstallMessage
            if (s[key])
                return s[key]
            return s["scroll.update_error"]
        }
        if (backend.latestUpdateVersion)
            return s["scroll.update_available"].replace("%1", backend.latestUpdateVersion)
        return s["scroll.update_idle"]
    }

    ScrollView {
        id: pageScroll
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        SettingsContent {
            objectName: scrollPage.applicationSettings ? "appSettingsContent" : "pointerSettingsContent"
            viewportWidth: pageScroll.availableWidth
            Item { width: 1; height: Theme.pageTopPadding }
            SettingsPageHeader {
                title: scrollPage.applicationSettings ? s["ui.app_settings"] : s["ui.pointer_scroll"]
            }
            SettingsForm {
                objectName: scrollPage.applicationSettings ? "appSettingsForm" : "pointerSettingsForm"
                SettingsSection {
                    objectName: "pointerSettingsSection"
                    width: parent.width
                    visible: !scrollPage.applicationSettings
                    title: s["ui.pointer_section"]
                    SettingsSliderRow {
                        objectName: "dpiSetting"
                        width: parent.width
                        label: s["scroll.pointer_speed"]
                        description: backend.hidFeaturesReady ? s["scroll.pointer_speed_desc"] : s["ui.connect_device_hint"]
                        enabled: backend.hidFeaturesReady
                        from: backend.deviceDpiMin
                        to: backend.deviceDpiMax
                        stepSize: 50
                        value: backend.dpi
                        suffix: "DPI"
                        editableValue: true
                        onValueEdited: function(value) { backend.setDpi(Math.round(value)) }
                    }
                    SettingRow {
                        width: parent.width
                        label: s["ui.common_dpi"]
                        enabled: backend.hidFeaturesReady
                        SettingsComboBox {
                            objectName: "dpiPresetCombo"
                            Layout.preferredWidth: 180
                            model: scrollPage.dpiPresets
                            currentIndex: scrollPage.dpiPresets.indexOf(backend.dpi)
                            displayText: currentIndex >= 0 ? currentText + " DPI" : s["ui.choose_preset"]
                            font { family: uiState.fontFamily; pixelSize: 13 }
                            onActivated: function(index) { backend.setDpi(scrollPage.dpiPresets[index]) }
                        }
                    }
                }
                SettingsSection {
                    width: parent.width
                    visible: !scrollPage.applicationSettings && backend.deviceHasSmartShift
                    title: s["ui.wheel_section"]
                    SettingRow {
                        width: parent.width
                        label: s["scroll.smart_shift"]
                        description: s["scroll.smart_shift_desc"]
                        enabled: backend.smartShiftSupported
                        SettingsSwitch {
                            objectName: "smartShiftSwitch"
                            checked: backend.smartShiftEnabled
                            Accessible.name: s["scroll.smart_shift"]
                            onClicked: backend.setSmartShiftEnabled(checked)
                        }
                    }
                    SettingsSliderRow {
                        objectName: "smartShiftThresholdSetting"
                        width: parent.width
                        visible: backend.smartShiftEnabled
                        enabled: backend.smartShiftSupported
                        label: s["ui.shift_sensitivity"]
                        from: 1; to: 50; stepSize: 1
                        value: backend.smartShiftThreshold
                        displayMultiplier: 2
                        suffix: "%"
                        onValueEdited: function(value) { backend.setSmartShiftThreshold(Math.round(value)) }
                    }
                    SettingRow {
                        width: parent.width
                        visible: !backend.smartShiftEnabled
                        enabled: backend.smartShiftSupported
                        label: s["scroll.wheel_mode"]
                        SettingsComboBox {
                            objectName: "wheelModeCombo"
                            Layout.preferredWidth: 180
                            model: scrollPage.wheelModes
                            textRole: "label"
                            currentIndex: backend.smartShiftMode === "freespin" ? 1 : 0
                            font { family: uiState.fontFamily; pixelSize: 13 }
                            onActivated: function(index) { backend.setSmartShift(scrollPage.wheelModes[index].value) }
                        }
                    }
                    SettingsSliderRow {
                        objectName: "wheelForceSetting"
                        width: parent.width
                        visible: backend.smartShiftForceSupported && (backend.smartShiftEnabled || backend.smartShiftMode === "ratchet")
                        label: s["scroll.scroll_force"]
                        description: s["scroll.scroll_force_desc"]
                        from: 1; to: 100; stepSize: 1
                        value: backend.scrollForce
                        suffix: "%"
                        onValueEdited: function(value) { backend.setScrollForce(Math.round(value)) }
                    }
                }
                SettingsSection {
                    width: parent.width
                    visible: !scrollPage.applicationSettings
                    title: s["scroll.scroll_direction"]
                    SettingRow {
                        width: parent.width
                        label: s["scroll.invert_vertical"]
                        SettingsSwitch {
                            objectName: "invertVerticalSwitch"
                            checked: backend.invertVScroll
                            Accessible.name: s["scroll.invert_vertical"]
                            onClicked: backend.setInvertVScroll(checked)
                        }
                    }
                    SettingRow {
                        width: parent.width
                        label: s["scroll.invert_horizontal"]
                        SettingsSwitch {
                            objectName: "invertHorizontalSwitch"
                            checked: backend.invertHScroll
                            Accessible.name: s["scroll.invert_horizontal"]
                            onClicked: backend.setInvertHScroll(checked)
                        }
                    }
                    SettingRow {
                        width: parent.width
                        visible: backend.isMacOS
                        label: s["scroll.ignore_trackpad"]
                        description: s["scroll.ignore_trackpad_desc"]
                        SettingsSwitch {
                            checked: backend.ignoreTrackpad
                            Accessible.name: s["scroll.ignore_trackpad"]
                            onClicked: backend.setIgnoreTrackpad(checked)
                        }
                    }
                    Text {
                        width: parent.width
                        topPadding: 12
                        text: s["scroll.dpi_note"]
                        font { family: uiState.fontFamily; pixelSize: 12 }
                        color: scrollPage.theme.textSecondary
                        wrapMode: Text.WordWrap
                    }
                }
                SettingsSection {
                    objectName: "appearanceSettingsSection"
                    width: parent.width
                    visible: scrollPage.applicationSettings
                    title: s["ui.display_section"]
                    SettingRow {
                        width: parent.width
                        label: s["scroll.appearance"]
                        SettingsComboBox {
                            objectName: "appearanceCombo"
                            Layout.preferredWidth: 180
                            model: scrollPage.appearanceOptions
                            textRole: "label"
                            currentIndex: {
                                for (var i = 0; i < scrollPage.appearanceOptions.length; ++i)
                                    if (scrollPage.appearanceOptions[i].value === backend.appearanceMode) return i
                                return 0
                            }
                            font { family: uiState.fontFamily; pixelSize: 13 }
                            onActivated: function(index) { backend.setAppearanceMode(scrollPage.appearanceOptions[index].value) }
                        }
                    }
                    SettingRow {
                        width: parent.width
                        label: s["scroll.language"]
                        SettingsComboBox {
                            objectName: "languageCombo"
                            Layout.preferredWidth: 180
                            model: lm.availableLanguages
                            textRole: "name"
                            currentIndex: {
                                for (var i = 0; i < lm.availableLanguages.length; ++i)
                                    if (lm.availableLanguages[i].code === lm.language) return i
                                return 0
                            }
                            font { family: uiState.fontFamily; pixelSize: 13 }
                            onActivated: function(index) { lm.setLanguage(lm.availableLanguages[index].code) }
                        }
                    }
                }
                SettingsSection {
                    width: parent.width
                    visible: scrollPage.applicationSettings
                    title: s["scroll.startup"]
                    SettingRow {
                        width: parent.width
                        visible: backend.supportsStartAtLogin
                        label: s["scroll.start_at_login"]
                        SettingsSwitch {
                            objectName: "startAtLoginSwitch"
                            checked: backend.startAtLogin
                            Accessible.name: s["scroll.start_at_login"]
                            onClicked: backend.setStartAtLogin(checked)
                        }
                    }
                    SettingRow {
                        width: parent.width
                        label: s["scroll.start_minimized"]
                        SettingsSwitch {
                            objectName: "startMinimizedSwitch"
                            checked: backend.startMinimized
                            Accessible.name: s["scroll.start_minimized"]
                            onClicked: backend.setStartMinimized(checked)
                        }
                    }
                }
                SettingsSection {
                    width: parent.width
                    visible: scrollPage.applicationSettings
                    title: s["scroll.screenshots"]
                    SettingRow {
                        width: parent.width
                        label: s["scroll.screenshots_save_to"]
                        description: backend.hasCustomScreenshotDirectory ? backend.screenshotDirectoryLabel : s["scroll.screenshots_system_default"]
                        SettingsButton {
                            objectName: "chooseScreenshotFolderButton"
                            text: s["scroll.screenshots_choose"]
                            flat: true
                            onClicked: backend.chooseScreenshotDirectory()
                        }
                        SettingsButton {
                            objectName: "resetScreenshotFolderButton"
                            text: s["scroll.screenshots_default"]
                            flat: true
                            enabled: backend.hasCustomScreenshotDirectory
                            onClicked: backend.resetScreenshotDirectory()
                        }
                    }
                }
                SettingsSection {
                    width: parent.width
                    visible: scrollPage.applicationSettings
                    title: s["ui.updates_section"]
                    SettingRow {
                        width: parent.width
                        label: s["scroll.check_for_updates"]
                        description: s["scroll.check_for_updates_desc"]
                        SettingsSwitch {
                            objectName: "checkUpdatesSwitch"
                            checked: backend.checkForUpdates
                            Accessible.name: s["scroll.check_for_updates"]
                            onClicked: backend.setCheckForUpdates(checked)
                        }
                    }
                    Text {
                        width: parent.width
                        topPadding: 12
                        text: scrollPage.updateStatusText()
                        wrapMode: Text.WordWrap
                        font { family: uiState.fontFamily; pixelSize: 12 }
                        color: backend.updateInstallStatus === "error" ? scrollPage.theme.danger : scrollPage.theme.textSecondary
                    }
                    ProgressBar {
                        width: parent.width
                        visible: backend.updateInstallStatus === "downloading"
                        from: 0; to: 100
                        value: backend.updateInstallProgress
                    }
                    Flow {
                        width: parent.width
                        spacing: 8
                        SettingsButton {
                            objectName: "checkUpdateButton"
                            text: s["scroll.update_check"]
                            flat: true
                            enabled: !backend.updateInstallInProgress
                            onClicked: backend.manualCheckForUpdates()
                        }
                        SettingsButton {
                            objectName: "prepareUpdateButton"
                            text: backend.isWindows ? s["scroll.update_download"] : s["scroll.update_verify"]
                            visible: backend.latestUpdateVersion !== "" && !backend.updateInstallCanInstall && (!backend.isWindows || backend.updateInstallEnabled)
                            enabled: !backend.updateInstallInProgress
                            flat: true
                            onClicked: backend.prepareLatestUpdate()
                        }
                        SettingsButton {
                            objectName: "cancelUpdateButton"
                            text: s["scroll.update_cancel"]
                            visible: ["checking", "downloading", "verifying"].indexOf(backend.updateInstallStatus) !== -1
                            flat: true
                            onClicked: backend.cancelUpdatePreparation()
                        }
                        SettingsButton {
                            objectName: "installUpdateButton"
                            text: s["scroll.update_install"]
                            visible: backend.updateInstallCanInstall && backend.updateInstallEnabled
                            enabled: !backend.updateInstallInProgress
                            flat: true
                            onClicked: backend.installPreparedUpdate()
                        }
                        SettingsButton {
                            objectName: "openReleaseButton"
                            text: s["scroll.update_open_release"]
                            visible: backend.latestUpdateVersion !== ""
                            enabled: !backend.updateInstallInProgress
                            flat: true
                            onClicked: backend.openLatestReleasePage()
                        }
                    }
                }
            }
            Item { width: 1; height: 28 }
        }
    }
}
