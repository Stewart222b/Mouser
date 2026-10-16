import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import "Theme.js" as Theme

/* Profile selection stays above the workspace; preview and editor share one screen. */

Item {
    id: mousePage
    readonly property var theme: Theme.palette(uiState.darkMode)
    readonly property bool hasBlockingDialog: addAppDialog.visible
                                             || deleteDialog.visible
                                             || keyCaptureDialog.visible
                                             || deviceTools.visible
    property string pendingDeleteProfile: ""
    // Reactive i18n shortcut — all s["key"] bindings update on lm.languageChanged
    property var s: lm.strings

    // Shared delegate for action-picker ComboBoxes: translates every list item.
    Component {
        id: actionComboDelegate
        ItemDelegate {
            width: parent ? parent.width : implicitWidth
            highlighted: ListView.isCurrentItem
            font { family: uiState.fontFamily; pixelSize: 12 }
            contentItem: Text {
                leftPadding: 10; rightPadding: 10
                text: (lm.strings, lm.trAction(modelData ? modelData.label : ""))
                font { family: uiState.fontFamily; pixelSize: 12 }
                color: highlighted ? mousePage.theme.accent : mousePage.theme.textPrimary
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                color: highlighted ? Theme.alpha(theme.accent, 0.1) : "transparent"
            }
        }
    }

    // Shared delegate for the device-layout override ComboBox (translates "Auto-detect").
    Component {
        id: layoutComboDelegate
        ItemDelegate {
            width: parent ? parent.width : implicitWidth
            highlighted: ListView.isCurrentItem
            font { family: uiState.fontFamily; pixelSize: 12 }
            contentItem: Text {
                leftPadding: 10; rightPadding: 10
                text: {
                    if (!modelData) return ""
                    var lbl = modelData.label || ""
                    return lbl === "Auto-detect"
                           ? (s["mouse.auto_detect"] || lbl)
                           : lbl
                }
                font { family: uiState.fontFamily; pixelSize: 12 }
                color: highlighted ? mousePage.theme.accent : mousePage.theme.textPrimary
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                color: highlighted ? Theme.alpha(theme.accent, 0.1) : "transparent"
            }
        }
    }

    // ── Profile state ─────────────────────────────────────────
    property string selectedProfile: backend.activeProfile
    property string selectedProfileLabel: ""
    property var selectedProfileMappingState: ({})
    property string appSearchText: ""
    property var filteredKnownApps: []
    property var suggestedKnownApps: []
    property var selectedKnownApp: null

    Component.onCompleted: {
        selectProfile(backend.activeProfile)
        refreshSuggestedApps()
        refreshAppSearch()
    }

    function refreshSelectedProfileMappings() {
        var mappings = backend.getProfileMappings(selectedProfile)
        var mappingState = ({})
        for (var i = 0; i < mappings.length; i++) {
            var mapping = mappings[i]
            mappingState[mapping.key] = mapping
        }
        selectedProfileMappingState = mappingState
    }

    function mappingFor(key) {
        return selectedProfileMappingState[key] || null
    }

    function selectProfile(name) {
        selectedProfile = name
        selectedProfileLabel = ""
        var profs = backend.profiles
        for (var i = 0; i < profs.length; i++) {
            if (profs[i].name === name) {
                selectedProfileLabel = profs[i].label
                break
            }
        }
        refreshSelectedProfileMappings()
        // Clear hotspot selection when switching profiles
        selectedButton = ""
        selectedButtonName = ""
        selectedActionId = ""
    }

    function appMatchesSearch(app, query) {
        if (!query)
            return false
        var lowered = query.toLowerCase()
        if ((app.label || "").toLowerCase().indexOf(lowered) !== -1)
            return true
        if ((app.id || "").toLowerCase().indexOf(lowered) !== -1)
            return true
        var aliases = app.aliases || []
        for (var i = 0; i < aliases.length; i++) {
            if ((aliases[i] || "").toLowerCase().indexOf(lowered) !== -1)
                return true
        }
        return false
    }

    function appIsSystem(app) {
        var path = (app && app.path) ? app.path : ""
        return path.indexOf("/System/") === 0
    }

    function appLocationLabel(app) {
        if (!app || !app.path)
            return s["mouse.installed_app"] || "Installed app"
        if (app.path.indexOf("/Applications/") === 0)
            return s["mouse.applications"] || "Applications"
        if (app.path.indexOf("/System/Applications/") === 0)
            return s["mouse.system_applications"] || "System Applications"
        if (app.path.indexOf("/System/Library/CoreServices/") === 0)
            return s["mouse.macos_coreservices"] || "macOS CoreServices"
        if (app.path.indexOf("/Users/") === 0)
            return app.path
        return app.path
    }

    function isPreferredAppLabel(label) {
        var preferred = [
            "Google Chrome", "Safari", "Arc", "Firefox", "Visual Studio Code",
            "Cursor", "Terminal", "iTerm2", "Warp", "Finder", "Figma",
            "Slack", "Discord", "Spotify", "Notion", "Preview", "Calendar",
            "Messages", "Music", "App Store", "System Settings"
        ]
        return preferred.indexOf(label || "") !== -1
    }

    function preferredAppRank(label) {
        var preferred = [
            "Google Chrome", "Safari", "Arc", "Firefox", "Visual Studio Code",
            "Cursor", "Terminal", "iTerm2", "Warp", "Finder", "Figma",
            "Slack", "Discord", "Spotify", "Notion", "Preview", "Calendar",
            "Messages", "Music", "App Store", "System Settings"
        ]
        var idx = preferred.indexOf(label || "")
        return idx === -1 ? 999 : idx
    }

    function suggestedAppScore(app) {
        var score = preferredAppRank(app.label)
        if (score === 999) {
            if (app.path && app.path.indexOf("/Applications/") === 0)
                score = 200
            else if (app.path && app.path.indexOf("/Users/") === 0)
                score = 260
            else if (appIsSystem(app))
                score = 500
            else
                score = 350
        }

        if (app.path && app.path.indexOf("/System/Library/CoreServices/") === 0)
            score += 100
        return score
    }

    function shouldSuggestApp(app) {
        if (!app || !app.label)
            return false
        if (isPreferredAppLabel(app.label))
            return true
        if (app.path && app.path.indexOf("/Applications/") === 0)
            return true
        if (app.path && app.path.indexOf("/Users/") === 0)
            return true
        return false
    }

    function refreshSuggestedApps() {
        var apps = backend.knownApps || []
        var matches = []
        for (var i = 0; i < apps.length; i++) {
            if (!shouldSuggestApp(apps[i]))
                continue
            matches.push({
                app: apps[i],
                score: suggestedAppScore(apps[i])
            })
        }

        matches.sort(function(a, b) {
            if (a.score !== b.score)
                return a.score - b.score
            return (a.app.label || "").localeCompare(b.app.label || "")
        })

        var results = []
        for (var j = 0; j < matches.length && j < 14; j++)
            results.push(matches[j].app)
        suggestedKnownApps = results
    }

    function appResultScore(app, query) {
        var lowered = query.toLowerCase()
        var label = (app.label || "").toLowerCase()
        var score = 50

        if (label === lowered)
            score = 0
        else if (label.indexOf(lowered) === 0)
            score = 1
        else if (label.indexOf(lowered) !== -1)
            score = 2

        var aliases = app.aliases || []
        for (var i = 0; i < aliases.length; i++) {
            var alias = (aliases[i] || "").toLowerCase()
            if (alias === lowered)
                score = Math.min(score, 3)
            else if (alias.indexOf(lowered) === 0)
                score = Math.min(score, 4)
            else if (alias.indexOf(lowered) !== -1)
                score = Math.min(score, 5)
        }

        if (appIsSystem(app))
            score += 10
        return score
    }

    function refreshAppSearch() {
        var query = (appSearchText || "").trim()
        var apps = backend.knownApps || []
        var matches = []

        if (query.length === 0) {
            filteredKnownApps = []
            return
        }

        for (var i = 0; i < apps.length; i++) {
            if (appMatchesSearch(apps[i], query)) {
                matches.push({
                    app: apps[i],
                    score: appResultScore(apps[i], query)
                })
            }
        }

        matches.sort(function(a, b) {
            if (a.score !== b.score)
                return a.score - b.score
            return (a.app.label || "").localeCompare(b.app.label || "")
        })

        var results = []
        for (var j = 0; j < matches.length && j < 12; j++)
            results.push(matches[j].app)

        filteredKnownApps = results
    }

    function selectKnownApp(app) {
        selectedKnownApp = app
    }

    function syncSelectedKnownApp() {
        if (!selectedKnownApp || !selectedKnownApp.id)
            return
        var apps = backend.knownApps || []
        for (var i = 0; i < apps.length; i++) {
            if (apps[i].id === selectedKnownApp.id) {
                selectedKnownApp = apps[i]
                return
            }
        }
        selectedKnownApp = null
    }

    function openAddProfileDialog() {
        selectedKnownApp = null
        appSearchText = ""
        filteredKnownApps = []
        refreshSuggestedApps()
        if (appSearchInput)
            appSearchInput.text = ""
        addAppDialog.open()
    }

    Connections {
        target: backend
        function onProfilesChanged() {
            // Refresh label/apps if current profile still exists
            var profs = backend.profiles
            for (var i = 0; i < profs.length; i++) {
                if (profs[i].name === selectedProfile) {
                    selectedProfileLabel = profs[i].label
                    return
                }
            }
            // Profile deleted — fall back to active
            selectProfile(backend.activeProfile)
        }
        function onActiveProfileChanged() {
            // Auto-select when engine switches profile
            selectProfile(backend.activeProfile)
        }
    }

    // ── Button / hotspot state ────────────────────────────────
    property string selectedButton: ""
    property string selectedButtonName: ""
    property string selectedActionId: ""
    readonly property string hscrollLeftActionId: selectedProfileMappingState.hscroll_left
                                             ? selectedProfileMappingState.hscroll_left.actionId
                                             : "none"
    readonly property string hscrollLeftActionLabel: selectedProfileMappingState.hscroll_left
                                                ? selectedProfileMappingState.hscroll_left.actionLabel
                                                : (s["mouse.do_nothing"] || "Do Nothing")
    readonly property string hscrollRightActionId: selectedProfileMappingState.hscroll_right
                                              ? selectedProfileMappingState.hscroll_right.actionId
                                              : "none"
    readonly property string hscrollRightActionLabel: selectedProfileMappingState.hscroll_right
                                                 ? selectedProfileMappingState.hscroll_right.actionLabel
                                                 : (s["mouse.do_nothing"] || "Do Nothing")
    // Unified model: every button uses the categorized action picker. Gesture
    // controls no longer get a dedicated always-on swipe editor (isSwipeButton
    // retired); instead any swipe-capable button opts in via the "Gesture
    // Swipe" action, which reveals the tap + swipe sub-editor below.
    readonly property bool isSwipeButton: false
    // A swipe-capable button (thumb gesture, Sense Panel, mode shift, back,
    // forward, middle -- whichever the device advertises) can be put into
    // gesture mode by choosing "Gesture Swipe". isGestureSwipeMode is true once
    // opted in; its keys are "<button>_tap" and "<button>_left/right/up/down".
    readonly property bool isGestureSwipeEligible:
        selectedButton !== ""
        && backend.gestureSwipeButtons.indexOf(selectedButton) !== -1
    readonly property string _selButtonActionId:
        (selectedButton !== "" && selectedProfileMappingState[selectedButton])
        ? selectedProfileMappingState[selectedButton].actionId : "none"
    readonly property bool isGestureSwipeMode:
        isGestureSwipeEligible && _selButtonActionId === "gesture_swipe"
    // Tap + direction bindings for a gesture-pad button ("<owner>_tap" and
    // "<owner>_left/right/up/down").
    readonly property var _gsTapMap: isGestureSwipeMode
        ? selectedProfileMappingState[selectedButton + "_tap"] : null
    readonly property string gsTapActionId: _gsTapMap ? _gsTapMap.actionId : "none"
    readonly property var _gsLeftMap: isGestureSwipeMode
        ? selectedProfileMappingState[selectedButton + "_left"] : null
    readonly property string gsLeftActionId: _gsLeftMap ? _gsLeftMap.actionId : "none"
    readonly property var _gsRightMap: isGestureSwipeMode
        ? selectedProfileMappingState[selectedButton + "_right"] : null
    readonly property string gsRightActionId: _gsRightMap ? _gsRightMap.actionId : "none"
    readonly property var _gsUpMap: isGestureSwipeMode
        ? selectedProfileMappingState[selectedButton + "_up"] : null
    readonly property string gsUpActionId: _gsUpMap ? _gsUpMap.actionId : "none"
    readonly property var _gsDownMap: isGestureSwipeMode
        ? selectedProfileMappingState[selectedButton + "_down"] : null
    readonly property string gsDownActionId: _gsDownMap ? _gsDownMap.actionId : "none"
    readonly property var _swipeTapMap: isSwipeButton
        ? selectedProfileMappingState[selectedButton] : null
    readonly property string swipeTapActionId: _swipeTapMap
        ? _swipeTapMap.actionId : "none"
    readonly property string swipeTapActionLabel: _swipeTapMap
        ? _swipeTapMap.actionLabel : (s["mouse.do_nothing"] || "Do Nothing")
    readonly property var _swipeLeftMap: isSwipeButton
        ? selectedProfileMappingState[selectedButton + "_left"] : null
    readonly property string swipeLeftActionId: _swipeLeftMap
        ? _swipeLeftMap.actionId : "none"
    readonly property var _swipeRightMap: isSwipeButton
        ? selectedProfileMappingState[selectedButton + "_right"] : null
    readonly property string swipeRightActionId: _swipeRightMap
        ? _swipeRightMap.actionId : "none"
    readonly property var _swipeUpMap: isSwipeButton
        ? selectedProfileMappingState[selectedButton + "_up"] : null
    readonly property string swipeUpActionId: _swipeUpMap
        ? _swipeUpMap.actionId : "none"
    readonly property var _swipeDownMap: isSwipeButton
        ? selectedProfileMappingState[selectedButton + "_down"] : null
    readonly property string swipeDownActionId: _swipeDownMap
        ? _swipeDownMap.actionId : "none"

    function selectButton(key) {
        if (selectedButton === key) {
            selectedButton = ""
            selectedButtonName = ""
            selectedActionId = ""
            return
        }
        var mapping = mappingFor(key)
        if (mapping) {
            selectedButton = key
            selectedButtonName = mapping.name
            selectedActionId = mapping.actionId
        }
    }

    function selectHScroll() {
        if (selectedButton === "hscroll_left") {
            selectedButton = ""
            selectedButtonName = ""
            selectedActionId = ""
            return
        }
        selectedButton = "hscroll_left"
        selectedButtonName = "Horizontal Scroll"
        var mapping = mappingFor("hscroll_left")
        selectedActionId = mapping ? mapping.actionId : "none"
    }

    Connections {
        id: mappingsConn
        target: backend
        function onMappingsChanged() {
            refreshSelectedProfileMappings()
            if (selectedButton === "") return
            var mapping = mappingFor(selectedButton)
            if (mapping) {
                selectedActionId = mapping.actionId
            }
        }
    }

    function actionFor(key) {
        var mapping = mappingFor(key)
        if (mapping)
            return lm.trAction(mapping.actionLabel)
        return s["mouse.do_nothing"] || "Do Nothing"
    }

    function actionFor_id(key) {
        var mapping = mappingFor(key)
        if (mapping)
            return mapping.actionId
        return "none"
    }

    function actionIndexForId(actionId) {
        var actions = backend.allActions
        for (var i = 0; i < actions.length; i++)
            if (actions[i].id === actionId) return i
        // Custom shortcut: point to the __custom__ sentinel at the end
        if (actionId.startsWith("custom:")) return actions.length - 1
        return 0
    }

    function customLabel(actionId) {
        if (!actionId.startsWith("custom:")) return ""
        return backend.actionLabelFor(actionId)
    }

    function isCustomAction(actionId) {
        return actionId.startsWith("custom:")
    }

    function gestureSummary(key) {
        // Per-button summary: tap action, or "Swipes configured" when the tap
        // is Do Nothing but at least one swipe direction is mapped.
        if (!backend.supportsGestureDirections)
            return actionFor(key)
        var tapId = actionFor_id(key)
        var hasSwipe = actionFor_id(key + "_left") !== "none"
                    || actionFor_id(key + "_right") !== "none"
                    || actionFor_id(key + "_up") !== "none"
                    || actionFor_id(key + "_down") !== "none"
        if (tapId === "none" && hasSwipe)
            return s["mouse.swipes_configured"] || "Swipes configured"
        return actionFor(key)
    }

    function hotspotSublabel(hotspot) {
        if (!hotspot)
            return ""
        if (hotspot.summaryType === "gesture")
            return gestureSummary(hotspot.buttonKey)
        if (hotspot.summaryType === "hscroll")
            return "L: " + lm.trAction(hscrollLeftActionLabel) + " | R: " + lm.trAction(hscrollRightActionLabel)
        return actionFor(hotspot.buttonKey)
    }

    function layoutHasButton(buttonKey) {
        var hotspots = backend.deviceHotspots
        for (var i = 0; i < hotspots.length; i++) {
            if (hotspots[i].buttonKey === buttonKey)
                return true
        }
        return false
    }

    function manualLayoutChoiceIndex(layoutKey) {
        var choices = backend.manualLayoutChoices
        for (var i = 0; i < choices.length; i++) {
            if (choices[i].key === layoutKey)
                return i
        }
        return 0
    }

    function currentLayoutChoiceLabel() {
        var idx = manualLayoutChoiceIndex(backend.deviceLayoutOverrideKey)
        var choices = backend.manualLayoutChoices
        if (idx >= 0 && idx < choices.length)
            return choices[idx].label
        return s["mouse.auto_detect"] || "Auto-detect"
    }

    Connections {
        target: backend
        function onDeviceLayoutChanged() {
            if (selectedButton !== "" && !layoutHasButton(selectedButton)) {
                selectedButton = ""
                selectedButtonName = ""
                selectedActionId = ""
            }
        }
    }

    readonly property var availableButtonActions: {
        var rows = backend.allActions.slice()
        if (isGestureSwipeEligible && backend.supportsGestureDirections)
            rows.splice(rows.length - 1, 0, {id: "gesture_swipe", label: "Gesture Swipe"})
        return rows
    }
    function buttonActionIndex(aid) {
        var target = isCustomAction(aid) ? "__custom__" : aid
        for (var i = 0; i < availableButtonActions.length; ++i)
            if (availableButtonActions[i].id === target) return i
        return 0
    }
    function profileIndex() {
        var rows = backend.profiles
        for (var i = 0; i < rows.length; ++i) if (rows[i].name === selectedProfile) return i
        return 0
    }
    readonly property var physicalButtons: {
        var keys = backend.hapticButtonRows.map(function(row) { return row.key })
        keys.push("hscroll_left")
        return backend.getProfileMappings(selectedProfile).filter(function(row) {
            return keys.indexOf(row.key) !== -1
        })
    }
    function selectedHapticEnabled() {
        var rows = backend.hapticEnabledButtons
        for (var i = 0; i < rows.length; ++i) if (rows[i].key === selectedButton) return true
        return false
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 28
        spacing: 14
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: s["ui.buttons"]
                font { family: uiState.fontFamily; pixelSize: 24; weight: Font.DemiBold }
                color: theme.textPrimary
                Layout.fillWidth: true
            }
            Text {
                text: {
                    var strings = lm.strings
                    if (!backend.mouseConnected) return strings["ui.no_mouse"]
                    var parts = [backend.deviceDisplayName]
                    if (backend.connectionType) parts.push(lm.trStatus(backend.connectionType))
                    if (backend.batteryLevel >= 0) parts.push(backend.batteryLevel + "%")
                    return parts.join("  ·  ")
                }
                font { family: uiState.fontFamily; pixelSize: 12 }
                color: theme.textSecondary
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text { text: s["ui.edit_profile"]; font { family: uiState.fontFamily; pixelSize: 14 } color: theme.textPrimary }
            ComboBox {
                objectName: "profileSelector"
                Layout.preferredWidth: Math.min(260, mousePage.width * 0.3)
                model: backend.profiles
                textRole: "label"
                currentIndex: mousePage.profileIndex()
                font { family: uiState.fontFamily; pixelSize: 14 }
                displayText: (lm.strings, lm.trProfile(selectedProfile, selectedProfileLabel))
                delegate: ItemDelegate {
                    required property var modelData
                    width: parent ? parent.width : implicitWidth
                    text: (lm.strings, lm.trProfile(modelData.name, modelData.label))
                    highlighted: ListView.isCurrentItem
                    font { family: uiState.fontFamily; pixelSize: 14 }
                }
                onActivated: function(index) { selectProfile(backend.profiles[index].name) }
            }
            Button { text: s["ui.add_profile"]; flat: true; onClicked: openAddProfileDialog() }
            Item { Layout.fillWidth: true }
            Button {
                visible: selectedProfile !== "" && selectedProfile !== "default"
                text: s["mouse.delete_profile"]
                flat: true
                onClicked: { pendingDeleteProfile = selectedProfile; deleteDialog.open() }
            }
        }
        Text {
            text: selectedProfile === "default" ? s["ui.default_profile_hint"] : s["ui.app_profile_hint"]
            font { family: uiState.fontFamily; pixelSize: 12 }
            color: theme.textSecondary
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: theme.border }
        RowLayout {
            id: buttonWorkspace
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 24
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 260
                Item {
                    id: mouseImageArea
                    objectName: "mousePreview"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Image {
                        id: mouseImg
                        source: backend.deviceImageSource
                        fillMode: Image.PreserveAspectFit
                        width: Math.min(backend.deviceImageWidth, parent.width - 24)
                        height: Math.min(backend.deviceImageHeight, parent.height - 24)
                        anchors.centerIn: parent
                        visible: backend.mouseConnected
                        smooth: true; mipmap: true; asynchronous: true
                        property real offX: (width - paintedWidth) / 2
                        property real offY: (height - paintedHeight) / 2
                    }
                    Repeater {
                        model: backend.mouseConnected && backend.hasInteractiveDeviceLayout ? backend.deviceHotspots : []
                        HotspotDot {
                            required property var modelData
                            anchors.fill: mouseImageArea
                            imgItem: mouseImg
                            normX: modelData.normX; normY: modelData.normY
                            buttonKey: modelData.buttonKey
                            isHScroll: modelData.isHScroll || false
                            label: modelData.label
                            sublabel: ""
                            labelSide: modelData.labelSide
                            labelOffX: Math.max(-80, Math.min(80, modelData.labelOffX))
                            labelOffY: Math.max(-45, Math.min(45, modelData.labelOffY))
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 32
                        visible: !backend.mouseConnected
                        text: s["mouse.turn_on_mouse"]
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        font { family: uiState.fontFamily; pixelSize: 14 }
                        color: theme.textSecondary
                    }
                }
                ComboBox {
                    objectName: "physicalButtonSelector"
                    Layout.fillWidth: true
                    model: mousePage.physicalButtons
                    textRole: "name"
                    font { family: uiState.fontFamily; pixelSize: 14 }
                    displayText: selectedButtonName ? (lm.strings, lm.trButton(selectedButtonName)) : s["ui.select_button"]
                    delegate: ItemDelegate {
                        required property var modelData
                        width: parent ? parent.width : implicitWidth
                        text: (lm.strings, lm.trButton(modelData.name))
                        font { family: uiState.fontFamily; pixelSize: 14 }
                        highlighted: ListView.isCurrentItem
                    }
                    onActivated: function(index) {
                        var row = model[index]
                        if (row.key === "hscroll_left" || row.key === "hscroll_right") {
                            if (selectedButton !== "hscroll_left") selectHScroll()
                        } else if (selectedButton !== row.key) selectButton(row.key)
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: s["ui.button_preview_hint"]
                    font { family: uiState.fontFamily; pixelSize: 12 }
                    color: theme.textSecondary
                    wrapMode: Text.WordWrap
                }
            }
            Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: theme.border }
            ScrollView {
                objectName: "buttonEditor"
                Layout.preferredWidth: Math.min(360, mousePage.width * 0.44)
                Layout.fillHeight: true
                clip: true
                contentWidth: availableWidth
                Column {
                    width: parent.width
                    spacing: 18
                    Text {
                        width: parent.width
                        visible: selectedButton === ""
                        text: s["ui.select_button_hint"]
                        font { family: uiState.fontFamily; pixelSize: 14 }
                        color: theme.textSecondary
                        wrapMode: Text.WordWrap
                    }
                    Rectangle {
                        id: actionPicker
                        width: parent.width
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: selectedButton !== ""
                                ? pickerCol.implicitHeight + 32 : 0
                        clip: true
                        color: "transparent"
                        visible: height > 0

                        Behavior on height {
                            NumberAnimation { duration: 250; easing.type: Easing.OutQuad }
                        }

                        Column {
                            id: pickerCol
                            anchors {
                                left: parent.left; right: parent.right
                                top: parent.top; topMargin: 0
                            }
                            spacing: 16

                            RowLayout {
                                width: parent.width
                                spacing: 12

                                Rectangle {
                                    Layout.preferredWidth: 0; Layout.preferredHeight: pickerTitleCol.height
                                    radius: 3; color: theme.accent
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Column {
                                    id: pickerTitleCol
                                    spacing: 2
                                    Layout.fillWidth: true

                                    Text {
                                        text: selectedButtonName
                                              ? (lm.strings, lm.trButton(selectedButtonName))
                                              : ""
                                        font { family: uiState.fontFamily; pixelSize: 18; bold: true }
                                        color: theme.textPrimary
                                    }
                                    Text {
                                        text: selectedButton === "hscroll_left"
                                              ? s["mouse.configure_scroll_actions"]
                                              : isSwipeButton
                                                && backend.supportsGestureDirections
                                                ? s["mouse.configure_gesture"]
                                              : s["mouse.select_button_action"]
                                        font { family: uiState.fontFamily; pixelSize: 12 }
                                        color: theme.textSecondary
                                        visible: selectedButton !== ""
                                    }
                                }

                            }

                            // Horizontal scroll: left + right rows
                            Column {
    width: parent.width
    spacing: 12
    visible: selectedButton === "hscroll_left"
    Repeater {
        model: [
            {key: "hscroll_left", label: s["mouse.scroll_left"], aid: hscrollLeftActionId},
            {key: "hscroll_right", label: s["mouse.scroll_right"], aid: hscrollRightActionId}
        ]
        Column {
            required property var modelData
            width: parent.width
            spacing: 6
            Text { text: modelData.label; font { family: uiState.fontFamily; pixelSize: 14 } color: theme.textPrimary }
            ComboBox {
                width: parent.width
                model: backend.allActions
                textRole: "label"
                delegate: actionComboDelegate
                font { family: uiState.fontFamily; pixelSize: 13 }
                currentIndex: actionIndexForId(modelData.aid)
                displayText: isCustomAction(modelData.aid) ? customLabel(modelData.aid) : (lm.strings, lm.trAction(currentText))
                onActivated: function(index) {
                    var aid = backend.allActions[index].id
                    if (aid === "__custom__") { keyCaptureDialog.open(selectedProfile, modelData.key); return }
                    backend.setProfileMapping(selectedProfile, modelData.key, aid)
                }
            }
        }
    }
}


                            Column {
                                width: parent.width
                                spacing: 14
                                visible: isSwipeButton
                                         && backend.supportsGestureDirections

                                Text {
                                    text: s["mouse.tap_action"]
                                    font { family: uiState.fontFamily; pixelSize: 12;
                                            letterSpacing: 0 }
                                    color: theme.textDim
                                }

                                ComboBox {
                                    width: parent.width
                                    model: backend.allActions
                                    textRole: "label"
                                    delegate: actionComboDelegate
                                    Material.accent: theme.accent
                                    font { family: uiState.fontFamily; pixelSize: 12 }
                                    currentIndex: actionIndexForId(swipeTapActionId)
                                    displayText: isCustomAction(swipeTapActionId)
                                                 ? customLabel(swipeTapActionId)
                                                 : (lm.strings, lm.trAction(currentText))
                                    onActivated: function(index) {
                                        var aid = backend.allActions[index].id
                                        if (aid === "__custom__") {
                                            keyCaptureDialog.open(selectedProfile, selectedButton)
                                            return
                                        }
                                        backend.setProfileMapping(selectedProfile, selectedButton, aid)
                                        selectedActionId = aid
                                    }
                                }

                                Rectangle {
                                    visible: swipeTapActionId === "none"
                                    width: parent.width
                                    height: 1
                                    color: theme.border
                                }

                                Row {
                                    visible: swipeTapActionId === "none"
                                    width: parent.width
                                    spacing: 12

                                Text {
                                    text: s["mouse.threshold"]
                                    font { family: uiState.fontFamily; pixelSize: 12; bold: true }
                                    color: theme.textPrimary
                                }

                                    Text {
                                        text: (
                                            gestureThresholdSlider.pressed
                                            ? Math.round(gestureThresholdSlider.value / 5.0) * 5
                                            : backend.gestureThreshold
                                        ) + " px"
                                        font { family: uiState.fontFamily; pixelSize: 12 }
                                        color: theme.textSecondary
                                    }
                                }

                                WheelSafeSlider {
                                    id: gestureThresholdSlider
                                    objectName: "nativeGestureThresholdSlider"
                                    visible: swipeTapActionId === "none"
                                    width: parent.width
                                    from: 20
                                    to: 400
                                    stepSize: 5
                                    value: backend.gestureThreshold
                                    accentColor: theme.accent
                                    accentDimColor: theme.accentDim
                                    trackColor: theme.border
                                    onCommitted: function(value) { backend.setGestureThreshold(Math.round(value / 5.0) * 5) }
                                }

                                Text {
                                    visible: swipeTapActionId === "none"
                                    text: s["mouse.swipe_actions"]
                                    font { family: uiState.fontFamily; pixelSize: 12;
                                            letterSpacing: 0 }
                                    color: theme.textDim
                                }

                                RowLayout {
                                    visible: swipeTapActionId === "none"
                                    width: parent.width
                                    spacing: 12

                                    Text {
                                        text: s["mouse.swipe_left"]
                                        Layout.preferredWidth: 100
                                        font { family: uiState.fontFamily; pixelSize: 12 }
                                        color: theme.textPrimary
                                    }

                                    ComboBox {
                                        Layout.fillWidth: true
                                        model: backend.allActions
                                        textRole: "label"
                                        delegate: actionComboDelegate
                                        Material.accent: theme.accent
                                        font { family: uiState.fontFamily; pixelSize: 12 }
                                        currentIndex: actionIndexForId(swipeLeftActionId)
                                        displayText: isCustomAction(swipeLeftActionId)
                                                     ? customLabel(swipeLeftActionId)
                                                     : (lm.strings, lm.trAction(currentText))
                                        onActivated: function(index) {
                                            var aid = backend.allActions[index].id
                                            if (aid === "__custom__") {
                                                keyCaptureDialog.open(selectedProfile, selectedButton + "_left")
                                                return
                                            }
                                            backend.setProfileMapping(
                                                selectedProfile, selectedButton + "_left", aid)
                                        }
                                    }
                                }

                                RowLayout {
                                    visible: swipeTapActionId === "none"
                                    width: parent.width
                                    spacing: 12

                                    Text {
                                        text: s["mouse.swipe_right"]
                                        Layout.preferredWidth: 100
                                        font { family: uiState.fontFamily; pixelSize: 12 }
                                        color: theme.textPrimary
                                    }

                                    ComboBox {
                                        Layout.fillWidth: true
                                        model: backend.allActions
                                        textRole: "label"
                                        delegate: actionComboDelegate
                                        Material.accent: theme.accent
                                        font { family: uiState.fontFamily; pixelSize: 12 }
                                        currentIndex: actionIndexForId(swipeRightActionId)
                                        displayText: isCustomAction(swipeRightActionId)
                                                     ? customLabel(swipeRightActionId)
                                                     : (lm.strings, lm.trAction(currentText))
                                        onActivated: function(index) {
                                            var aid = backend.allActions[index].id
                                            if (aid === "__custom__") {
                                                keyCaptureDialog.open(selectedProfile, selectedButton + "_right")
                                                return
                                            }
                                            backend.setProfileMapping(
                                                selectedProfile, selectedButton + "_right", aid)
                                        }
                                    }
                                }

                                RowLayout {
                                    visible: swipeTapActionId === "none"
                                    width: parent.width
                                    spacing: 12

                                    Text {
                                        text: s["mouse.swipe_up"]
                                        Layout.preferredWidth: 100
                                        font { family: uiState.fontFamily; pixelSize: 12 }
                                        color: theme.textPrimary
                                    }

                                    ComboBox {
                                        Layout.fillWidth: true
                                        model: backend.allActions
                                        textRole: "label"
                                        delegate: actionComboDelegate
                                        Material.accent: theme.accent
                                        font { family: uiState.fontFamily; pixelSize: 12 }
                                        currentIndex: actionIndexForId(swipeUpActionId)
                                        displayText: isCustomAction(swipeUpActionId)
                                                     ? customLabel(swipeUpActionId)
                                                     : (lm.strings, lm.trAction(currentText))
                                        onActivated: function(index) {
                                            var aid = backend.allActions[index].id
                                            if (aid === "__custom__") {
                                                keyCaptureDialog.open(selectedProfile, selectedButton + "_up")
                                                return
                                            }
                                            backend.setProfileMapping(
                                                selectedProfile, selectedButton + "_up", aid)
                                        }
                                    }
                                }

                                RowLayout {
                                    visible: swipeTapActionId === "none"
                                    width: parent.width
                                    spacing: 12

                                    Text {
                                        text: s["mouse.swipe_down"]
                                        Layout.preferredWidth: 100
                                        font { family: uiState.fontFamily; pixelSize: 12 }
                                        color: theme.textPrimary
                                    }

                                    ComboBox {
                                        Layout.fillWidth: true
                                        model: backend.allActions
                                        textRole: "label"
                                        delegate: actionComboDelegate
                                        Material.accent: theme.accent
                                        font { family: uiState.fontFamily; pixelSize: 12 }
                                        currentIndex: actionIndexForId(swipeDownActionId)
                                        displayText: isCustomAction(swipeDownActionId)
                                                     ? customLabel(swipeDownActionId)
                                                     : (lm.strings, lm.trAction(currentText))
                                        onActivated: function(index) {
                                            var aid = backend.allActions[index].id
                                            if (aid === "__custom__") {
                                                keyCaptureDialog.open(selectedProfile, selectedButton + "_down")
                                                return
                                            }
                                            backend.setProfileMapping(
                                                selectedProfile, selectedButton + "_down", aid)
                                        }
                                    }
                                }
                            }

                            // Single button: categorized chips
                            Column {
    width: parent.width
    spacing: 12
    visible: selectedButton !== "" && selectedButton !== "hscroll_left" && !isGestureSwipeMode
    Text {
        text: s["ui.execute_action"]
        font { family: uiState.fontFamily; pixelSize: 14; weight: Font.DemiBold }
        color: theme.textPrimary
    }
    ComboBox {
        objectName: "buttonActionCombo"
        width: parent.width
        model: mousePage.availableButtonActions
        textRole: "label"
        delegate: actionComboDelegate
        font { family: uiState.fontFamily; pixelSize: 14 }
        currentIndex: mousePage.buttonActionIndex(selectedActionId)
        displayText: isCustomAction(selectedActionId) ? customLabel(selectedActionId)
                     : (lm.strings, lm.trAction(backend.actionLabelFor(selectedActionId)))
        onActivated: function(index) {
            var aid = mousePage.availableButtonActions[index].id
            if (aid === "__custom__") { keyCaptureDialog.open(selectedProfile, selectedButton); return }
            backend.setProfileMapping(selectedProfile, selectedButton, aid)
            selectedActionId = aid
        }
    }
    Text {
        width: parent.width
        visible: selectedActionId === "ctrl_left_click"
        text: s["ui.ctrl_click_hint"]
        wrapMode: Text.WordWrap
        font { family: uiState.fontFamily; pixelSize: 12 }
        color: theme.textSecondary
    }
}


                            // ── Per-button Gesture Swipe editor ──────────────
                            // Shown when an eligible button's action is set to
                            // "Gesture Swipe": a tap action plus four swipe
                            // directions, like the thumb Gesture button. Keys are
                            // "<button>_tap" and "<button>_left/right/up/down".
                            Column {
                                width: parent.width
                                spacing: 14
                                visible: isGestureSwipeMode
                                objectName: "gestureButtonEditor"

                                RowLayout {
                                    width: parent.width
                                    Text {
                                        text: s["mouse.gesture_swipe"] || "Gesture Swipe"
                                        Layout.fillWidth: true
                                        font { family: uiState.fontFamily; pixelSize: 12;
                                                letterSpacing: 0 }
                                        color: theme.textDim
                                    }
                                    Text {
                                        text: s["mouse.remove"] || "Remove"
                                        font { family: uiState.fontFamily; pixelSize: 12; underline: true }
                                        color: theme.accent
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                backend.setProfileMapping(
                                                    selectedProfile, selectedButton, "none")
                                                selectedActionId = "none"
                                            }
                                        }
                                    }
                                }

                                Text {
                                    text: s["mouse.tap_action"] || "Tap action"
                                    font { family: uiState.fontFamily; pixelSize: 12;
                                            letterSpacing: 0 }
                                    color: theme.textDim
                                }
                                ComboBox {
                                    width: parent.width
                                    model: backend.allActions
                                    textRole: "label"
                                    delegate: actionComboDelegate
                                    Material.accent: theme.accent
                                    font { family: uiState.fontFamily; pixelSize: 12 }
                                    currentIndex: actionIndexForId(gsTapActionId)
                                    displayText: isCustomAction(gsTapActionId)
                                                 ? customLabel(gsTapActionId)
                                                 : (lm.strings, lm.trAction(currentText))
                                    onActivated: function(index) {
                                        var aid = backend.allActions[index].id
                                        if (aid === "__custom__") {
                                            keyCaptureDialog.open(selectedProfile, selectedButton + "_tap")
                                            return
                                        }
                                        backend.setProfileMapping(
                                            selectedProfile, selectedButton + "_tap", aid)
                                    }
                                }

                                Rectangle { width: parent.width; height: 1; color: theme.border }

                                Row {
                                    width: parent.width
                                    spacing: 12
                                    Text {
                                        text: s["mouse.threshold"] || "Threshold"
                                        font { family: uiState.fontFamily; pixelSize: 12; bold: true }
                                        color: theme.textPrimary
                                    }
                                    Text {
                                        text: (gsThreshold.pressed
                                               ? Math.round(gsThreshold.value / 5.0) * 5
                                               : backend.gestureThreshold) + " px"
                                        font { family: uiState.fontFamily; pixelSize: 12 }
                                        color: theme.textSecondary
                                    }
                                }
                                WheelSafeSlider {
                                    id: gsThreshold
                                    objectName: "gestureThresholdSlider"
                                    width: parent.width
                                    from: 20; to: 400; stepSize: 5
                                    value: backend.gestureThreshold
                                    accentColor: theme.accent
                                    accentDimColor: theme.accentDim
                                    trackColor: theme.border
                                    onCommitted: function(value) { backend.setGestureThreshold(Math.round(value / 5.0) * 5) }
                                }

                                Text {
                                    text: s["mouse.swipe_actions"] || "Swipe actions"
                                    font { family: uiState.fontFamily; pixelSize: 12;
                                            letterSpacing: 0 }
                                    color: theme.textDim
                                }

                                Repeater {
                                    model: [
                                        { dir: "left",  label: s["mouse.swipe_left"]  || "Swipe left",  aid: gsLeftActionId },
                                        { dir: "right", label: s["mouse.swipe_right"] || "Swipe right", aid: gsRightActionId },
                                        { dir: "up",    label: s["mouse.swipe_up"]    || "Swipe up",    aid: gsUpActionId },
                                        { dir: "down",  label: s["mouse.swipe_down"]  || "Swipe down",  aid: gsDownActionId }
                                    ]
                                    delegate: RowLayout {
                                        width: parent.width
                                        spacing: 12
                                        Text {
                                            text: modelData.label
                                            Layout.preferredWidth: 100
                                            font { family: uiState.fontFamily; pixelSize: 12 }
                                            color: theme.textPrimary
                                        }
                                        ComboBox {
                                            Layout.fillWidth: true
                                            model: backend.allActions
                                            textRole: "label"
                                            delegate: actionComboDelegate
                                            Material.accent: theme.accent
                                            font { family: uiState.fontFamily; pixelSize: 12 }
                                            currentIndex: actionIndexForId(modelData.aid)
                                            displayText: isCustomAction(modelData.aid)
                                                         ? customLabel(modelData.aid)
                                                         : (lm.strings, lm.trAction(currentText))
                                            onActivated: function(index) {
                                                var aid = backend.allActions[index].id
                                                var key = selectedButton + "_" + modelData.dir
                                                if (aid === "__custom__") {
                                                    keyCaptureDialog.open(selectedProfile, key)
                                                    return
                                                }
                                                backend.setProfileMapping(selectedProfile, key, aid)
                                            }
                                        }
                                    }
                                }
                            }

                            // ── DPI Presets editor (when cycle_dpi is selected)
                            Rectangle {
                                id: dpiPresetsCard
                                objectName: "dpiPresetEditor"
                                property int activeSlot: 0
                                readonly property var slotColors: ["#e8d44d", "#5da5e8", "#e8943a", "#e05daa"]
                                visible: selectedActionId === "cycle_dpi"
                                width: parent.width
                                height: dpiPresetsCol.implicitHeight + 28
                                radius: 12
                                color: Qt.rgba(0.5, 0.5, 0.5, 0.06)
                                border.width: 1
                                border.color: theme.border

                                Column {
                                    id: dpiPresetsCol
                                    anchors {
                                        left: parent.left; right: parent.right
                                        top: parent.top; margins: 14
                                    }
                                    spacing: 14

                                    Text {
                                        text: s["mouse.dpi_presets"]
                                        font { family: uiState.fontFamily; pixelSize: 12;
                                                letterSpacing: 0 }
                                        color: theme.textDim
                                    }

                                    // Slot pills row
                                    Row {
                                        spacing: 10
                                        Repeater {
                                            model: 4
                                            Rectangle {
                                                width: slotVal.implicitWidth + 24
                                                height: 32; radius: 8
                                                color: dpiPresetsCard.activeSlot === index
                                                       ? Qt.rgba(0.5, 0.5, 0.5, 0.14)
                                                       : "transparent"
                                                border.width: dpiPresetsCard.activeSlot === index ? 2 : 1
                                                border.color: dpiPresetsCard.slotColors[index]

                                                Text {
                                                    id: slotVal
                                                    anchors.centerIn: parent
                                                    text: {
                                                        var presets = backend.dpiPresets
                                                        return presets[index] !== undefined ? presets[index] : "---"
                                                    }
                                                    font { family: uiState.fontFamily; pixelSize: 13; bold: true }
                                                    color: dpiPresetsCard.slotColors[index]
                                                }

                                                // Active indicator dot
                                                Rectangle {
                                                    width: 5; height: 5; radius: 3
                                                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 2 }
                                                    color: dpiPresetsCard.slotColors[index]
                                                    visible: {
                                                        var presets = backend.dpiPresets
                                                        return presets[index] !== undefined && presets[index] === backend.dpi
                                                    }
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        dpiPresetsCard.activeSlot = index
                                                        var presets = backend.dpiPresets
                                                        if (presets[index] !== undefined)
                                                            dpiPresetSlider.value = presets[index]
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Slider for active slot
                                    Column {
                                        width: parent.width
                                        spacing: 6

                                        Row {
                                            spacing: 8
                                            Rectangle {
                                                width: 10; height: 10; radius: 5
                                                color: dpiPresetsCard.slotColors[dpiPresetsCard.activeSlot]
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            Text {
                                                text: s["mouse.dpi_slot"].replace("{slot}", dpiPresetsCard.activeSlot + 1)
                                                      .replace("{dpi}", Math.round(dpiPresetSlider.value))
                                                font { family: uiState.fontFamily; pixelSize: 12; bold: true }
                                                color: dpiPresetsCard.slotColors[dpiPresetsCard.activeSlot]
                                            }
                                        }

                                        WheelSafeSlider {
                                            id: dpiPresetSlider
                                            objectName: "dpiPresetSlider"
                                            width: parent.width
                                            from: backend.deviceDpiMin
                                            to: backend.deviceDpiMax
                                            stepSize: 50
                                            value: {
                                                var presets = backend.dpiPresets
                                                var idx = dpiPresetsCard.activeSlot
                                                return presets[idx] !== undefined ? presets[idx] : 1000
                                            }
                                            accentColor: dpiPresetsCard.slotColors[dpiPresetsCard.activeSlot]
                                            accentDimColor: Qt.rgba(0.5, 0.5, 0.5, 0.12)
                                            trackColor: theme.border
                                            onCommitted: function(value) {
                                                backend.setDpiPreset(dpiPresetsCard.activeSlot, Math.round(value))
                                            }
                                        }

                                        Row {
                                            width: parent.width
                                            Text {
                                                text: backend.deviceDpiMin
                                                font { family: uiState.fontFamily; pixelSize: 10 }
                                                color: theme.textDim
                                            }
                                            Item { width: parent.width - minDpiLabel.implicitWidth - maxDpiLabel.implicitWidth; height: 1 }
                                            Text {
                                                id: maxDpiLabel
                                                text: backend.deviceDpiMax
                                                font { family: uiState.fontFamily; pixelSize: 10 }
                                                color: theme.textDim
                                            }
                                            Text {
                                                id: minDpiLabel
                                                visible: false
                                                text: backend.deviceDpiMin
                                            }
                                        }
                                    }

                                    Text {
                                        width: parent.width
                                        wrapMode: Text.WordWrap
                                        text: s["mouse.dpi_cycle_hint"].replace("{values}", (function() {
                                                  var p = backend.dpiPresets
                                                  var parts = []
                                                  for (var i = 0; i < p.length; i++)
                                                      parts.push(p[i])
                                                  return parts.join(" \u2192 ")
                                              })())
                                        font { family: uiState.fontFamily; pixelSize: 12 }
                                        color: theme.textSecondary
                                    }
                                }
                            }

                            Item { width: 1; height: 8 }
                        }
                    }
                    SettingRow {
                        width: parent.width
                        visible: backend.hapticSupported && selectedButton !== "" && selectedButton !== "hscroll_left"
                        label: s["ui.haptic_on_press"]
                        enabled: backend.hapticEnabled
                        SettingsSwitch {
                            objectName: "selectedButtonHapticSwitch"
                            checked: mousePage.selectedHapticEnabled()
                            Accessible.name: s["ui.haptic_on_press"]
                            onClicked: backend.setButtonHaptic(selectedButton, checked)
                        }
                    }
                    Item { width: 1; height: 16 }
                }
            }
        }
        Button {
            objectName: "deviceToolsButton"
            text: s["ui.device_tools"]
            flat: true
            onClicked: deviceTools.open()
        }
    }
    Dialog {
        id: deviceTools
        parent: Overlay.overlay
        modal: true
        title: s["ui.device_tools"]
        width: Math.min(760, mousePage.width - 32)
        height: Math.min(620, mousePage.height - 32)
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        standardButtons: Dialog.Close
        contentItem: ScrollView {
            clip: true
            contentWidth: availableWidth
            Column {
                width: parent.width
                spacing: 16
                ComboBox {
                    width: parent.width
                    model: backend.manualLayoutChoices
                    textRole: "label"
                    delegate: layoutComboDelegate
                    currentIndex: manualLayoutChoiceIndex(backend.deviceLayoutOverrideKey)
                    displayText: currentLayoutChoiceLabel()
                    onActivated: function(index) { backend.setDeviceLayoutOverride(backend.manualLayoutChoices[index].key) }
                }
                                    Rectangle {
                        visible: backend.mouseConnected
                        width: parent.width
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: shareDevRow.implicitHeight + 24
                        radius: 14
                        color: theme.bgCard
                        border.width: 1
                        border.color: theme.border

                        Row {
                            id: shareDevRow
                            anchors.centerIn: parent
                            spacing: 10

                            Text {
                                text: s["ui.device_info"]
                                font { family: uiState.fontFamily; pixelSize: 12 }
                                color: theme.textSecondary
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Rectangle {
                                width: shareDevBtnRow.implicitWidth + 20
                                height: 30; radius: 10
                                color: shareDevBtnMa.containsMouse
                                       ? Theme.alpha(theme.accent, 0.22)
                                       : Theme.alpha(theme.accent, 0.12)
                                anchors.verticalCenter: parent.verticalCenter

                                Row {
                                    id: shareDevBtnRow
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        text: "\uD83D\uDCCB"
                                        font.pixelSize: 13
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: s["mouse.copy_device_info"] || "Copy device info"
                                        font { family: uiState.fontFamily; pixelSize: 12; bold: true }
                                        color: theme.accent
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: shareDevBtnMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var info = backend.dumpDeviceInfo()
                                        if (info) {
                                            backend.copyToClipboard(info)
                                            backend.statusMessage(
                                                s["mouse.device_info_copied"] || "Device info copied to clipboard -- paste it into a GitHub issue!")
                                        } else {
                                            backend.statusMessage(
                                                s["mouse.no_device_connected"] || "No device connected")
                                        }
                                    }
                                }
                            }
                        }
                    }
Rectangle {
                        width: parent.width
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: debugCol.implicitHeight + 24
                        radius: 14
                        color: theme.bgCard
                        border.width: 1
                        border.color: theme.border
                        visible: backend.debugMode

                        Column {
                            id: debugCol
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12

                            RowLayout {
                                width: parent.width
                                spacing: 12

                                Column {
                                    Layout.fillWidth: true
                                    spacing: 3

                                    Text {
                                        text: s["mouse.debug_events"]
                                        font { family: uiState.fontFamily; pixelSize: 14; bold: true }
                                        color: theme.textPrimary
                                    }

                                    Text {
                                        text: s["mouse.debug_events_desc"]
                                        font { family: uiState.fontFamily; pixelSize: 12 }
                                        color: theme.textSecondary
                                    }
                                }

                                SettingsSwitch {
                                    checked: backend.debugEventsEnabled
                                    text: checked ? s["mouse.on"] : s["mouse.off"]
                                    Material.accent: theme.accent
                                    onToggled: backend.setDebugEventsEnabled(checked)
                                }

                                SettingsSwitch {
                                    checked: backend.recordMode
                                    text: checked ? s["mouse.rec"] : s["mouse.record"]
                                    Material.accent: "#e46f4e"
                                    onToggled: backend.setRecordMode(checked)
                                }

                                Rectangle {
                                    Layout.preferredWidth: clearText.implicitWidth + 20
                                    Layout.preferredHeight: 28
                                    radius: 8
                                    color: clearMa.containsMouse
                                           ? Qt.rgba(1, 1, 1, 0.08)
                                           : Qt.rgba(1, 1, 1, 0.04)

                                    Text {
                                        id: clearText
                                        anchors.centerIn: parent
                                        text: s["mouse.clear"]
                                        font { family: uiState.fontFamily; pixelSize: 12; bold: true }
                                        color: theme.textPrimary
                                    }

                                    MouseArea {
                                        id: clearMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: backend.clearDebugLog()
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: clearRecText.implicitWidth + 20
                                    Layout.preferredHeight: 28
                                    radius: 8
                                    color: clearRecMa.containsMouse
                                           ? Qt.rgba(1, 1, 1, 0.08)
                                           : Qt.rgba(1, 1, 1, 0.04)

                                    Text {
                                        id: clearRecText
                                        anchors.centerIn: parent
                                        text: s["mouse.clear_rec"]
                                        font { family: uiState.fontFamily; pixelSize: 12; bold: true }
                                        color: theme.textPrimary
                                    }

                                    MouseArea {
                                        id: clearRecMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: backend.clearGestureRecords()
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: copyDevInfoText.implicitWidth + 20
                                    Layout.preferredHeight: 28
                                    radius: 8
                                    color: copyDevInfoMa.containsMouse
                                           ? Qt.rgba(1, 1, 1, 0.08)
                                           : Qt.rgba(1, 1, 1, 0.04)

                                    Text {
                                        id: copyDevInfoText
                                        anchors.centerIn: parent
                                        text: s["mouse.copy_device_info"]
                                        font { family: uiState.fontFamily; pixelSize: 12; bold: true }
                                        color: theme.textPrimary
                                    }

                                    MouseArea {
                                        id: copyDevInfoMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var info = backend.dumpDeviceInfo()
                                            if (info) {
                                                backend.copyToClipboard(info)
                                                backend.statusMessage("Device info copied to clipboard")
                                            } else {
                                                backend.statusMessage("No device connected")
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                radius: 10
                                color: Qt.rgba(1, 1, 1, 0.03)
                                border.width: 1
                                border.color: theme.border
                                height: monitorCol.implicitHeight + 20

                                Column {
                                    id: monitorCol
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 8

                                    Text {
                                        text: s["mouse.live_gesture_monitor"]
                                        font { family: uiState.fontFamily; pixelSize: 12; bold: true }
                                        color: theme.textPrimary
                                    }

                                    Row {
                                        spacing: 8

                                        Rectangle {
                                            width: activeText.implicitWidth + 16
                                            height: 24
                                            radius: 12
                                            color: backend.gestureActive
                                                   ? Qt.rgba(0.89, 0.45, 0.25, 0.18)
                                                   : Qt.rgba(1, 1, 1, 0.05)

                                            Text {
                                                id: activeText
                                                anchors.centerIn: parent
                                                text: backend.gestureActive ? s["mouse.held"] : s["mouse.idle"]
                                                font { family: uiState.fontFamily; pixelSize: 12; bold: true }
                                                color: backend.gestureActive ? "#f39c6b" : theme.textSecondary
                                            }
                                        }

                                        Rectangle {
                                            width: moveText.implicitWidth + 16
                                            height: 24
                                            radius: 12
                                            color: backend.gestureMoveSeen
                                                   ? Theme.alpha(theme.accent, 0.12)
                                                   : Qt.rgba(1, 1, 1, 0.05)

                                            Text {
                                                id: moveText
                                                anchors.centerIn: parent
                                                text: backend.gestureMoveSeen ? s["mouse.move_seen"] : s["mouse.no_move"]
                                                font { family: uiState.fontFamily; pixelSize: 12; bold: true }
                                                color: backend.gestureMoveSeen ? theme.accent : theme.textSecondary
                                            }
                                        }
                                    }

                                    Text {
                                        text: s["mouse.source"]
                                              + (backend.gestureMoveSource ? backend.gestureMoveSource : s["mouse.not_available"])
                                              + " | dx: " + backend.gestureMoveDx
                                              + " | dy: " + backend.gestureMoveDy
                                        font { family: "Menlo"; pixelSize: 12 }
                                        color: theme.textSecondary
                                    }

                                    Text {
                                        text: (lm.strings, lm.trStatus(backend.gestureStatus))
                                        font { family: uiState.fontFamily; pixelSize: 12 }
                                        color: theme.textPrimary
                                        wrapMode: Text.Wrap
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 160
                                radius: 10
                                color: Qt.rgba(0, 0, 0, 0.18)
                                border.width: 1
                                border.color: theme.border

                                ScrollView {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    clip: true

                                    TextArea {
                                        id: debugLogArea
                                        text: backend.debugLog.length
                                              ? backend.debugLog
                                              : s["mouse.debug_placeholder"]
                                        readOnly: true
                                        wrapMode: TextEdit.NoWrap
                                        selectByMouse: true
                                        color: backend.debugLog.length
                                               ? theme.textPrimary
                                               : theme.textSecondary
                                        font.pixelSize: 12
                                        font.family: "Menlo"
                                        background: null
                                        padding: 10

                                        onTextChanged: {
                                            cursorPosition = length
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 180
                                radius: 10
                                color: Qt.rgba(0, 0, 0, 0.18)
                                border.width: 1
                                border.color: theme.border

                                ScrollView {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    clip: true

                                    TextArea {
                                        text: backend.gestureRecords.length
                                              ? backend.gestureRecords
                                              : s["mouse.gesture_placeholder"]
                                        readOnly: true
                                        wrapMode: TextEdit.Wrap
                                        selectByMouse: true
                                        color: backend.gestureRecords.length
                                               ? theme.textPrimary
                                               : theme.textSecondary
                                        font.pixelSize: 12
                                        font.family: "Menlo"
                                        background: null
                                        padding: 10
                                    }
                                }
                            }
                        }
                    }
            }
        }
    }

    Dialog {
        id: addAppDialog
        parent: Overlay.overlay
        modal: true
        focus: true
        title: ""
        width: 720
        height: 520
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        padding: 0
        property bool searching: appSearchText.trim().length > 0
        property var visibleApps: searching ? filteredKnownApps : suggestedKnownApps

        function ensureSelection() {
            var apps = visibleApps || []
            if (!apps.length) {
                selectedKnownApp = null
                return
            }

            if (!selectedKnownApp || !selectedKnownApp.id) {
                selectedKnownApp = apps[0]
                return
            }

            for (var i = 0; i < apps.length; i++) {
                if (apps[i].id === selectedKnownApp.id)
                    return
            }

            selectedKnownApp = apps[0]
        }

        function selectedIndex() {
            var apps = visibleApps || []
            if (!selectedKnownApp || !selectedKnownApp.id)
                return -1
            for (var i = 0; i < apps.length; i++) {
                if (apps[i].id === selectedKnownApp.id)
                    return i
            }
            return -1
        }

        function moveSelection(delta) {
            var apps = visibleApps || []
            if (!apps.length)
                return

            var current = selectedIndex()
            if (current === -1)
                current = 0

            var next = current + delta
            if (next < 0)
                next = 0
            if (next >= apps.length)
                next = apps.length - 1

            selectedKnownApp = apps[next]
            if (appResultsList)
                appResultsList.positionViewAtIndex(next, ListView.Contain)
        }

        onOpened: {
            if (appSearchInput) {
                appSearchInput.text = ""
                appSearchInput.forceActiveFocus()
            }
            refreshSuggestedApps()
            refreshAppSearch()
            ensureSelection()
            backend.refreshKnownAppsSilently()
        }
        onVisibleAppsChanged: ensureSelection()

        background: Rectangle {
            radius: 24
            color: theme.bgElevated
            border.width: 1
            border.color: theme.border
        }

        contentItem: Item {
            width: addAppDialog.width
            height: addAppDialog.height

            Item {
                id: addDialogHeader
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 14
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                height: 42

                Column {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Text {
                        text: s["mouse.add_app_dialog.title"]
                        font { family: uiState.fontFamily; pixelSize: 17; bold: true }
                        color: theme.textPrimary
                    }

                    Text {
                        text: s["mouse.add_app_dialog.desc"]
                        font { family: uiState.fontFamily; pixelSize: 12 }
                        color: theme.textSecondary
                    }
                }

                Rectangle {
                    width: 34
                    height: 34
                    radius: 12
                    anchors.right: parent.right
                    anchors.rightMargin: 0
                    anchors.verticalCenter: parent.verticalCenter
                    color: closeAddDialogMa.containsMouse
                           ? Qt.rgba(1, 1, 1, uiState.darkMode ? 0.08 : 0.65)
                           : "transparent"

                    AppIcon {
                        anchors.centerIn: parent
                        width: 14
                        height: 14
                        name: "x"
                        iconColor: theme.textSecondary
                    }

                    MouseArea {
                        id: closeAddDialogMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: addAppDialog.close()
                    }
                }
            }

            Rectangle {
                id: searchField
                anchors.top: addDialogHeader.bottom
                anchors.topMargin: 12
                anchors.left: parent.left
                anchors.leftMargin: 24
                anchors.right: browseButton.left
                anchors.rightMargin: 12
                height: 46
                radius: 16
                color: theme.bgSubtle
                border.width: 1
                border.color: appSearchInput.activeFocus ? theme.accent : theme.border

                TextInput {
                    id: appSearchInput
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    color: theme.textPrimary
                    font { family: uiState.fontFamily; pixelSize: 12 }
                    verticalAlignment: TextInput.AlignVCenter
                    selectByMouse: true
                    clip: true

                    onTextChanged: {
                        appSearchText = text
                        refreshAppSearch()
                        addAppDialog.ensureSelection()
                    }

                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Down) {
                            addAppDialog.moveSelection(1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up) {
                            addAppDialog.moveSelection(-1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (selectedKnownApp) {
                                backend.addProfile(selectedKnownApp.id)
                                addAppDialog.close()
                            }
                            event.accepted = true
                        }
                    }
                }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: s["mouse.search_placeholder"]
                        font { family: uiState.fontFamily; pixelSize: 12 }
                        color: theme.textDim
                        visible: !appSearchInput.text.length
                    }
            }

            Rectangle {
                id: browseButton
                anchors.top: searchField.top
                anchors.right: parent.right
                anchors.rightMargin: 24
                width: 112
                height: 46
                radius: 16
                color: browseDialogMa.containsMouse
                       ? Qt.rgba(1, 1, 1, uiState.darkMode ? 0.08 : 0.55)
                       : theme.bgSubtle
                border.width: 1
                border.color: theme.border

                    Text {
                        anchors.centerIn: parent
                        text: s["mouse.browse"]
                        font { family: uiState.fontFamily; pixelSize: 12; bold: true }
                        color: theme.textPrimary
                    }

                MouseArea {
                    id: browseDialogMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        addAppDialog.close()
                        backend.browseForAppProfile()
                    }
                }
            }

            Item {
                id: resultsBlock
                anchors.top: searchField.bottom
                anchors.topMargin: 18
                anchors.left: parent.left
                anchors.leftMargin: 24
                anchors.right: parent.right
                anchors.rightMargin: 24
                anchors.bottom: footerRow.top
                anchors.bottomMargin: 20

                Row {
                    id: resultsHeader
                    anchors.top: parent.top
                    anchors.left: parent.left
                    height: 22
                    spacing: 10

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: addAppDialog.searching ? s["mouse.search_results"] : s["mouse.suggested_apps"]
                        font { family: uiState.fontFamily; pixelSize: 12; bold: true }
                        color: theme.textPrimary
                    }

                    Rectangle {
                        width: resultCountText.implicitWidth + 16
                        height: 22
                        radius: 11
                        color: Theme.alpha(theme.accent, uiState.darkMode ? 0.12 : 0.14)

                        Text {
                            id: resultCountText
                            anchors.centerIn: parent
                            text: addAppDialog.visibleApps.length
                            font { family: uiState.fontFamily; pixelSize: 10; bold: true }
                            color: theme.accent
                        }
                    }
                }

                Rectangle {
                    anchors.top: resultsHeader.bottom
                    anchors.topMargin: 12
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    radius: 20
                    color: theme.bg
                    border.width: 1
                    border.color: theme.border

                    ListView {
                        id: appResultsList
                        anchors.fill: parent
                        anchors.margins: 10
                        clip: true
                        model: addAppDialog.visibleApps
                        spacing: 6
                        visible: addAppDialog.visibleApps.length > 0
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            width: ListView.view.width
                            height: 58
                            radius: 15
                            color: selectedKnownApp && selectedKnownApp.id === modelData.id
                                   ? Theme.alpha(theme.accent, uiState.darkMode ? 0.16 : 0.12)
                                   : appRowMa.containsMouse
                                     ? Qt.rgba(1, 1, 1, uiState.darkMode ? 0.06 : 0.6)
                                     : "transparent"
                            border.width: selectedKnownApp && selectedKnownApp.id === modelData.id ? 1 : 0
                            border.color: theme.accent

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                spacing: 12

                                Image {
                                    anchors.verticalCenter: parent.verticalCenter
                                    source: modelData.iconSource || ""
                                    width: 24
                                    height: 24
                                    sourceSize.width: 24
                                    sourceSize.height: 24
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    visible: source !== ""
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    Text {
                                        text: modelData.label || ""
                                        font { family: uiState.fontFamily; pixelSize: 13; bold: true }
                                        color: theme.textPrimary
                                        elide: Text.ElideRight
                                        width: 470
                                    }

                                    Text {
                                        text: appLocationLabel(modelData)
                                        font { family: uiState.fontFamily; pixelSize: 10 }
                                        color: theme.textSecondary
                                        elide: Text.ElideRight
                                        width: 470
                                    }
                                }

                                Item {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 1
                                    height: 1
                                }
                            }

                            MouseArea {
                                id: appRowMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: selectedKnownApp = modelData
                                onDoubleClicked: {
                                    selectedKnownApp = modelData
                                    backend.addProfile(modelData.id)
                                    addAppDialog.close()
                                }
                            }
                        }
                    }

                    Column {
                        width: parent.width - 48
                        anchors.centerIn: parent
                        spacing: 8
                        visible: addAppDialog.visibleApps.length === 0

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: addAppDialog.searching
                                  ? s["mouse.no_matched"]
                                  : s["mouse.no_suggested"]
                            font { family: uiState.fontFamily; pixelSize: 13; bold: true }
                            color: theme.textPrimary
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: addAppDialog.searching
                                  ? s["mouse.try_different"]
                                  : s["mouse.use_search"]
                            font { family: uiState.fontFamily; pixelSize: 12 }
                            color: theme.textSecondary
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            Item {
                id: footerRow
                anchors.left: parent.left
                anchors.leftMargin: 24
                anchors.right: parent.right
                anchors.rightMargin: 24
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 24
                height: 48

                Rectangle {
                    id: createButton
                    anchors.right: parent.right
                    width: 160
                    height: parent.height
                    radius: 16
                    color: selectedKnownApp
                           ? (createDialogMa.containsMouse ? theme.accentHover : theme.accent)
                           : Theme.alpha(theme.accent, 0.22)

                    Text {
                        anchors.centerIn: parent
                        text: s["mouse.create_profile"]
                        font { family: uiState.fontFamily; pixelSize: 12; bold: true }
                        color: selectedKnownApp ? theme.bgSidebar : theme.textSecondary
                    }

                    MouseArea {
                        id: createDialogMa
                        anchors.fill: parent
                        enabled: !!selectedKnownApp
                        hoverEnabled: enabled
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (selectedKnownApp) {
                                backend.addProfile(selectedKnownApp.id)
                                addAppDialog.close()
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.right: createButton.left
                    anchors.rightMargin: 10
                    width: 108
                    height: parent.height
                    radius: 16
                    color: cancelDialogMa.containsMouse
                           ? Qt.rgba(1, 1, 1, uiState.darkMode ? 0.08 : 0.55)
                           : theme.bgSubtle
                    border.width: 1
                    border.color: theme.border

                    Text {
                        anchors.centerIn: parent
                        text: s["mouse.cancel"]
                        font { family: uiState.fontFamily; pixelSize: 12; bold: true }
                        color: theme.textPrimary
                    }

                    MouseArea {
                        id: cancelDialogMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: addAppDialog.close()
                    }
                }
            }
        }
    }

    Dialog {
        id: deleteDialog
        parent: Overlay.overlay
        modal: true
        focus: true
        title: s["mouse.delete_dialog.title"]
        width: 380
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        standardButtons: Dialog.Ok | Dialog.Cancel

        function confirmDelete() {
            if (pendingDeleteProfile && pendingDeleteProfile !== "default") {
                backend.deleteProfile(pendingDeleteProfile)
                selectProfile(backend.activeProfile)
            }
            pendingDeleteProfile = ""
        }

        function cancelDelete() {
            pendingDeleteProfile = ""
        }

        onAccepted: confirmDelete()
        onRejected: cancelDelete()

        contentItem: Column {
            width: deleteDialog.availableWidth
            spacing: 10

            Text {
                width: parent.width
                text: pendingDeleteProfile
                      ? (s["mouse.delete_dialog.confirm_prefix"] || "Delete the profile for ")
                        + (lm.strings, lm.trProfile(selectedProfile, selectedProfileLabel))
                        + (s["mouse.delete_dialog.confirm_suffix"] || "?")
                      : ""
                font { family: uiState.fontFamily; pixelSize: 13; bold: true }
                color: theme.textPrimary
                wrapMode: Text.WordWrap
            }

            Text {
                width: parent.width
                text: s["mouse.delete_dialog.desc"]
                font { family: uiState.fontFamily; pixelSize: 12 }
                color: theme.textSecondary
                wrapMode: Text.WordWrap
            }
        }
    }

    // ── Key capture dialog for custom shortcuts ──────────────
    KeyCaptureDialog {
        id: keyCaptureDialog
        objectName: "shortcutCaptureDialog"
        onCaptured: function(comboString) {
            backend.setProfileMapping(
                keyCaptureDialog.targetProfile,
                keyCaptureDialog.targetButton,
                "custom:" + comboString)
            refreshSelectedProfileMappings()
            selectedActionId = "custom:" + comboString
        }
    }
}
