import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: status
    property bool connected: false
    property string connectionType: ""
    property int batteryLevel: -1
    property bool charging: false
    property var theme
    property var s
    property string fontFamily

    readonly property bool batteryKnown: batteryLevel >= 0 && batteryLevel <= 100
    readonly property bool lowBattery: batteryKnown && batteryLevel <= 20 && !charging
    readonly property string connectionIconName: {
        var transport = connectionType.trim().toLowerCase();
        if (transport.indexOf("bluetooth") === 0)
            return "bluetooth";
        if (transport === "logi bolt" || transport === "usb receiver" || transport === "unifying")
            return "usb-receiver";
        return "link";
    }
    readonly property string connectionLabel: {
        var transport = connectionType.trim().toLowerCase();
        if (transport.indexOf("bluetooth") === 0)
            return s["device.bluetooth"];
        if (transport === "logi bolt")
            return s["device.bolt"];
        if (transport === "usb receiver" || transport === "unifying")
            return s["device.usb_receiver"];
        return connectionType.trim() || s["device.connection_unknown"];
    }
    readonly property string batteryLabel: {
        var label = batteryKnown ? s["device.battery_remaining"].replace("{percent}", batteryLevel) : s["device.battery_unknown"];
        if (charging)
            return s["device.charging"] + " · " + label;
        if (lowBattery)
            return s["device.low_battery"] + " · " + label;
        return label;
    }
    readonly property color batteryColor: charging ? theme.accent : lowBattery ? (batteryLevel <= 10 ? theme.danger : theme.warning) : theme.textSecondary

    implicitHeight: 26
    implicitWidth: statusRow.implicitWidth

    RowLayout {
        id: statusRow
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        Item {
            id: connection
            objectName: "deviceConnectionIndicator"
            visible: status.connected
            implicitWidth: 20
            implicitHeight: 24
            activeFocusOnTab: visible
            Accessible.role: Accessible.StaticText
            Accessible.name: status.connectionLabel
            AppIcon {
                objectName: "deviceConnectionIcon"
                anchors.centerIn: parent
                width: 18
                height: 18
                name: status.connectionIconName
                iconColor: status.theme.textSecondary
            }
            HoverHandler {
                id: connectionHover
            }
            ToolTip.visible: connectionHover.hovered || connection.activeFocus
            ToolTip.text: status.connectionLabel
            ToolTip.delay: connection.activeFocus ? 0 : 450
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                radius: 2
                border.width: connection.activeFocus ? 1 : 0
                border.color: status.theme.accent
            }
        }
        Rectangle {
            visible: status.connected
            implicitWidth: 1
            implicitHeight: 12
            color: status.theme.border
        }
        Item {
            id: battery
            objectName: "deviceBatteryIndicator"
            visible: status.connected
            implicitWidth: batteryContents.implicitWidth
            implicitHeight: 24
            activeFocusOnTab: visible
            Accessible.role: Accessible.StaticText
            Accessible.name: status.batteryLabel
            RowLayout {
                id: batteryContents
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Item {
                    objectName: "deviceBatteryIcon"
                    implicitWidth: 25
                    implicitHeight: 20
                    Rectangle {
                        x: 1
                        y: 4
                        width: 21
                        height: 12
                        radius: 2
                        color: "transparent"
                        border.width: 1.5
                        border.color: status.batteryColor
                    }
                    Rectangle {
                        x: 23
                        y: 8
                        width: 1.5
                        height: 4
                        radius: 0.5
                        color: status.batteryColor
                    }
                    Rectangle {
                        objectName: "deviceBatteryFill"
                        visible: status.batteryKnown && !status.charging
                        x: 3.5
                        y: 6.5
                        height: 7
                        radius: 0.5
                        width: 16 * Math.max(0, Math.min(status.batteryLevel, 100)) / 100
                        color: status.batteryColor
                    }
                    AppIcon {
                        objectName: "deviceChargingIcon"
                        visible: status.charging
                        anchors.centerIn: parent
                        width: 10
                        height: 12
                        name: "lightning"
                        iconColor: status.batteryColor
                    }
                    Text {
                        visible: !status.batteryKnown && !status.charging
                        anchors.centerIn: parent
                        text: "?"
                        font {
                            family: status.fontFamily
                            pixelSize: 10
                        }
                        color: status.theme.textSecondary
                    }
                }
                Text {
                    objectName: "deviceBatteryText"
                    text: (status.batteryKnown ? status.batteryLevel + "%" : "—") + (status.lowBattery ? " " + status.s["device.low_battery"] : "")
                    font {
                        family: status.fontFamily
                        pixelSize: 12
                    }
                    color: status.batteryColor
                }
            }
            HoverHandler {
                id: batteryHover
            }
            ToolTip.visible: batteryHover.hovered || battery.activeFocus
            ToolTip.text: status.batteryLabel
            ToolTip.delay: battery.activeFocus ? 0 : 450
            Rectangle {
                anchors.fill: parent
                anchors.margins: -2
                color: "transparent"
                radius: 2
                border.width: battery.activeFocus ? 1 : 0
                border.color: status.theme.accent
            }
        }
        Text {
            objectName: "deviceDisconnectedText"
            visible: !status.connected
            text: status.s["device.disconnected"]
            font {
                family: status.fontFamily
                pixelSize: 12
            }
            color: status.theme.textSecondary
        }
    }
}
