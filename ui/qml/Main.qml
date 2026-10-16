import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import "Theme.js" as Theme

ApplicationWindow {
    id: root
    visible: !launchHidden
    width: 1240
    height: 800
    minimumWidth: 1040
    minimumHeight: 620
    readonly property string versionLabel: "v" + appVersion
    title: backend.mouseConnected
           ? "Mouser " + versionLabel + " — " + backend.deviceDisplayName
           : "Mouser " + versionLabel

    property string appearanceMode: uiState.appearanceMode
    readonly property bool darkMode: appearanceMode === "dark"
                                    || (appearanceMode === "system"
                                        && uiState.systemDarkMode)
    readonly property var theme: Theme.palette(darkMode)
    readonly property string monoFontFamily: Qt.platform.os === "osx"
                                               ? "Menlo"
                                               : (Qt.platform.os === "windows"
                                                  ? "Consolas"
                                                  : "monospace")
    property var s: lm.strings
    property int currentPage: 0
    readonly property bool shortcutsBlocked: aboutDialog.visible
                                            || mousePageView.hasBlockingDialog
                                            || (ringPageLoader.item && ringPageLoader.item["hasBlockingDialog"])

    property var navModel: {
        var items = [
            { icon: "mouse-simple", tipKey: "ui.buttons", page: 0 },
            { icon: "sliders-horizontal", tipKey: "ui.pointer_scroll", page: 1 }
        ]
        if (backend.hapticSupported) {
            items.push({ icon: "vibration", tipKey: "nav.haptic_feedback", page: 2 })
        }
        if (backend.deviceHasActionsRing && backend.actionsRingActive) {
            items.push({ icon: "target", tipKey: "nav.actions_ring", page: 3 })
        }
        return items
    }

    function openPage(page) {
        if (root.currentPage === page)
            return
        root.currentPage = page
        root.contentItem.forceActiveFocus(Qt.OtherFocusReason)
    }

    color: theme.bg

    Material.theme: darkMode ? Material.Dark : Material.Light
    Material.accent: theme.accent
    Material.background: theme.bg
    Material.foreground: theme.textPrimary

    RowLayout {
        anchors.fill: parent
        spacing: 0
        Rectangle {
            id: sidebar
            Layout.preferredWidth: 184
            Layout.fillHeight: true
            color: root.theme.bgSidebar
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 4
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 15
                    Layout.leftMargin: 12
                    Layout.bottomMargin: 5
                    spacing: 10
                    AppIcon { name: "mouse-simple"; Layout.preferredWidth: 22; Layout.preferredHeight: 24; iconColor: root.theme.textPrimary }
                    Text {
                        text: "Mouser"
                        font { family: uiState.fontFamily; pixelSize: 18; weight: Font.DemiBold }
                        color: root.theme.textPrimary
                    }
                }
                Text {
                    Layout.leftMargin: 12
                    Layout.bottomMargin: 26
                    Layout.fillWidth: true
                    text: backend.mouseConnected ? backend.deviceDisplayName : s["ui.no_mouse"]
                    font { family: uiState.fontFamily; pixelSize: 12 }
                    color: root.theme.textSecondary
                    elide: Text.ElideRight
                }
                Repeater {
                    model: root.navModel
                    Button {
                        id: navButton
                        enabled: !root.shortcutsBlocked
                        required property var modelData
                        objectName: "navigation_" + modelData.page
                        Layout.fillWidth: true
                        implicitHeight: 42
                        hoverEnabled: true
                        Accessible.name: lm.strings[modelData.tipKey]
                        Accessible.role: Accessible.PageTab
                        Accessible.selected: root.currentPage === modelData.page
                        onClicked: root.openPage(modelData.page)
                        background: Rectangle {
                            radius: 4
                            color: root.currentPage === navButton.modelData.page ? root.theme.accentDim
                                 : navButton.hovered ? root.theme.bgCardHover : "transparent"
                            border.width: navButton.activeFocus ? 1 : 0
                            border.color: root.theme.accent
                            Rectangle {
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                width: 3; height: 17; radius: 2
                                color: root.theme.accent
                                visible: root.currentPage === navButton.modelData.page
                            }
                        }
                        contentItem: RowLayout {
                            spacing: 11
                            AppIcon { name: navButton.modelData.icon; Layout.preferredWidth: 18; Layout.preferredHeight: 18; iconColor: root.theme.textPrimary }
                            Text {
                                Layout.fillWidth: true
                                text: lm.strings[navButton.modelData.tipKey]
                                color: root.theme.textPrimary
                                font { family: uiState.fontFamily; pixelSize: 14; weight: root.currentPage === navButton.modelData.page ? Font.DemiBold : Font.Normal }
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
                Item { Layout.fillHeight: true }
                Button {
                    id: appSettingsNav
                    enabled: !root.shortcutsBlocked
                    objectName: "navigation_4"
                    Layout.fillWidth: true
                    implicitHeight: 42
                    text: s["ui.app_settings"]
                    font { family: uiState.fontFamily; pixelSize: 14 }
                    flat: true
                    onClicked: root.openPage(4)
                    background: Rectangle {
                        radius: 4
                        color: root.currentPage === 4 ? root.theme.accentDim
                             : appSettingsNav.hovered ? root.theme.bgCardHover : "transparent"
                        border.width: appSettingsNav.activeFocus ? 1 : 0
                        border.color: root.theme.accent
                        Rectangle {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            width: 3; height: 17; radius: 2
                            color: root.theme.accent
                            visible: root.currentPage === 4
                        }
                    }
                }
                Button {
                    Layout.fillWidth: true
                    implicitHeight: 36
                    text: s["nav.about"]
                    enabled: !root.shortcutsBlocked
                    font { family: uiState.fontFamily; pixelSize: 12 }
                    flat: true
                    onClicked: aboutDialog.open()
                }
                Text {
                    Layout.leftMargin: 12
                    Layout.bottomMargin: 4
                    text: "Mouser " + root.versionLabel
                    font { family: uiState.fontFamily; pixelSize: 12 }
                    color: root.theme.textSecondary
                }
            }
            Rectangle { anchors { right: parent.right; top: parent.top; bottom: parent.bottom } width: 1; color: root.theme.border }
        }
        StackLayout {
            id: contentStack
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.currentPage
            MousePage { id: mousePageView }
            Loader { active: root.currentPage === 1 || item; source: "ScrollPage.qml" }
            Loader { active: (root.currentPage === 2 || item) && backend.hapticSupported; source: "HapticPage.qml" }
            Loader { id: ringPageLoader; active: (root.currentPage === 3 || item) && backend.deviceHasActionsRing && backend.actionsRingActive; source: "ActionsRingConfig.qml" }
            Loader {
                active: root.currentPage === 4 || item
                sourceComponent: Component { ScrollPage { applicationSettings: true } }
            }
        }
    }

    Dialog {
        id: aboutDialog
        parent: Overlay.overlay
        modal: true
        focus: true
        title: ""
        width: 500
        height: 430
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        padding: 0

        background: Rectangle {
            radius: 24
            color: theme.bgElevated
            border.width: 1
            border.color: theme.border
        }

        contentItem: Item {
            width: aboutDialog.width
            height: aboutDialog.height

            Item {
                id: aboutHeader
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 16
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                height: 44

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    Rectangle {
                        width: 36
                        height: 36
                        radius: 12
                        color: root.theme.accentDim

                        AppIcon {
                            anchors.centerIn: parent
                            width: 18
                            height: 18
                            name: "info"
                            iconColor: root.theme.accent
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3

                        Text {
                            text: lm.strings["about.title"] || "About Mouser"
                            font { family: uiState.fontFamily; pixelSize: 17; bold: true }
                            color: theme.textPrimary
                        }

                        Text {
                            text: lm.strings["about.subtitle"] || ""
                            font { family: uiState.fontFamily; pixelSize: 11 }
                            color: theme.textSecondary
                        }
                    }
                }

                Rectangle {
                    width: 34
                    height: 34
                    radius: 12
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    color: closeAboutMouse.containsMouse
                           ? Qt.rgba(1, 1, 1, uiState.darkMode ? 0.08 : 0.65)
                           : "transparent"

                    Accessible.role: Accessible.Button
                    Accessible.name: s["dialog.close"]
                    Accessible.onPressAction: aboutDialog.close()

                    AppIcon {
                        anchors.centerIn: parent
                        width: 14
                        height: 14
                        name: "x"
                        iconColor: theme.textSecondary
                    }

                    MouseArea {
                        id: closeAboutMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: aboutDialog.close()
                    }
                }
            }

            Column {
                anchors {
                    top: aboutHeader.bottom
                    topMargin: 20
                    left: parent.left
                    right: parent.right
                    leftMargin: 24
                    rightMargin: 24
                }
                spacing: 14

                Rectangle {
                    width: parent.width
                    height: versionHero.implicitHeight + 24
                    radius: 20
                    color: root.theme.accentDim
                    border.width: 1
                    border.color: Qt.rgba(0, 0, 0, root.darkMode ? 0.0 : 0.04)

                    Column {
                        id: versionHero
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 10

                        Text {
                            text: lm.strings["about.version"] || "Version"
                            font { family: uiState.fontFamily; pixelSize: 11; bold: true }
                            color: root.theme.textSecondary
                        }

                        Row {
                            spacing: 10

                            Text {
                                text: root.versionLabel
                                font { family: uiState.fontFamily; pixelSize: 28; bold: true }
                                color: root.theme.textPrimary
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                radius: 999
                                color: Qt.rgba(1, 1, 1, root.darkMode ? 0.08 : 0.6)
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, root.darkMode ? 0.05 : 0.18)
                                width: buildModeChipLabel.implicitWidth + 22
                                height: 30

                                Text {
                                    id: buildModeChipLabel
                                    anchors.centerIn: parent
                                    text: (lm.strings, lm.trStatus(appBuildMode))
                                    font { family: uiState.fontFamily; pixelSize: 11; bold: true }
                                    color: root.theme.textPrimary
                                }
                            }
                        }

                        Text {
                            text: (lm.strings["about.commit"] || "Commit") + ": " + appCommit
                            font { family: root.monoFontFamily; pixelSize: 12 }
                            color: root.theme.textSecondary
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: metadataColumn.implicitHeight + 2
                    radius: 18
                    color: theme.bgSubtle
                    border.width: 1
                    border.color: theme.border

                    Column {
                        id: metadataColumn
                        anchors.fill: parent
                        spacing: 0

                        Item {
                            width: parent.width
                            height: 64

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 18
                                anchors.verticalCenter: parent.verticalCenter
                                width: 92
                                text: lm.strings["about.build_mode"] || "Build mode"
                                font { family: uiState.fontFamily; pixelSize: 11; bold: true }
                                color: theme.textSecondary
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 126
                                anchors.right: parent.right
                                anchors.rightMargin: 18
                                anchors.verticalCenter: parent.verticalCenter
                                text: (lm.strings, lm.trStatus(appBuildMode))
                                font { family: uiState.fontFamily; pixelSize: 14 }
                                color: theme.textPrimary
                            }
                        }

                        Rectangle {
                            width: parent.width - 36
                            height: 1
                            x: 18
                            color: theme.border
                            opacity: 0.9
                        }

                        Item {
                            width: parent.width
                            height: 64

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 18
                                anchors.verticalCenter: parent.verticalCenter
                                width: 92
                                text: lm.strings["about.commit"] || "Commit"
                                font { family: uiState.fontFamily; pixelSize: 11; bold: true }
                                color: theme.textSecondary
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 126
                                anchors.right: parent.right
                                anchors.rightMargin: 18
                                anchors.verticalCenter: parent.verticalCenter
                                text: appCommit
                                font { family: root.monoFontFamily; pixelSize: 13 }
                                color: theme.textPrimary
                            }
                        }

                        Rectangle {
                            width: parent.width - 36
                            height: 1
                            x: 18
                            color: theme.border
                            opacity: 0.9
                        }

                        Item {
                            width: parent.width
                            height: launchPathValue.implicitHeight + 34

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 18
                                anchors.top: parent.top
                                anchors.topMargin: 18
                                width: 92
                                text: lm.strings["about.launch_path"] || "Launch path"
                                font { family: uiState.fontFamily; pixelSize: 11; bold: true }
                                color: theme.textSecondary
                            }

                            Text {
                                id: launchPathValue
                                anchors.left: parent.left
                                anchors.leftMargin: 126
                                anchors.right: parent.right
                                anchors.rightMargin: 18
                                anchors.top: parent.top
                                anchors.topMargin: 18
                                text: appLaunchPath
                                wrapMode: Text.WrapAnywhere
                                font { family: root.monoFontFamily; pixelSize: 12 }
                                color: theme.textPrimary
                            }
                        }
                    }
                }
            }

        }
    }

    Rectangle {
        id: toast
        anchors {
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
            bottomMargin: 24
        }
        width: toastText.implicitWidth + 32
        height: 38
        radius: 19
        color: root.theme.accent
        opacity: 0
        visible: opacity > 0

        Text {
            id: toastText
            anchors.centerIn: parent
            font {
                family: uiState.fontFamily
                pixelSize: 12
                bold: true
            }
            color: root.theme.bgSidebar
        }

        Behavior on opacity { NumberAnimation { duration: 200 } }

        function show(msg) {
            toastText.text = msg
            toast.opacity = 1
            toastTimer.restart()
        }

        Timer {
            id: toastTimer
            interval: 2000
            onTriggered: toast.opacity = 0
        }
    }

    // Hide-to-tray: every "close window" idiom on every supported platform routes through
    // dismiss() so the engine and tray icon keep running. macOS LSUIElement bundles depend
    // on this because the Dock close button never terminates the process; Linux and Windows
    // tray builds inherit the same behavior for consistency.
    function dismiss() {
        if (!root.visible) {
            return
        }
        root.hide()
    }

    onClosing: function(close) {
        close.accepted = false
        root.dismiss()
    }

    // LSUIElement apps have no platform menu bar binding StandardKey.Close to Cmd-W, and
    // Ctrl/Cmd+M mirrors the OS "minimize" idiom. Keep these scoped to the main window
    // and disable them while any blocking dialog / shortcut-capture overlay is open so
    // typing flows cannot get swallowed by a global hide-to-tray shortcut.
    Shortcut {
        // On macos StandardKey.Close is Cmd-W, Cmd-F4 and Close.
        // For multiple shortcuts, sequences needs to be an array.
        sequences: [StandardKey.Close]
        context: Qt.WindowShortcut
        enabled: root.visible && !root.shortcutsBlocked
        onActivated: root.dismiss()
    }

    Shortcut {
        sequence: "Ctrl+M"
        context: Qt.WindowShortcut
        enabled: root.visible && !root.shortcutsBlocked
        onActivated: root.dismiss()
    }

    // Keep Esc on the same main-window path; blocking dialogs and the key-capture overlay
    // own Escape while open, so dismiss() only runs when the real shell is frontmost.
    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        enabled: root.visible && !root.shortcutsBlocked
        onActivated: root.dismiss()
    }

    Connections {
        target: backend
        function onStatusMessage(msg) { toast.show(lm.trStatus(msg)) }
    }
}
