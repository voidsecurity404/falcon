import QtQuick
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import qs.components
import qs.services

// The charge of everything that has a battery: this computer, the phone through KDE Connect,
// Bluetooth devices that report one, and wireless mice, keyboards and pads UPower knows.
// Forms: wide (a row of rings), square (a grid), tall (a list).
Item {
    id: root

    readonly property bool widgetRoot: true
    property string widgetId: ""
    property string form: "wide"
    readonly property bool tall: form === "tall"
    readonly property bool square: form === "square"

    function iconForType(t) {
        switch (t) {
        case UPowerDeviceType.Mouse:
            return "mouse";
        case UPowerDeviceType.Keyboard:
            return "keyboard";
        case UPowerDeviceType.Headset:
        case UPowerDeviceType.Headphones:
            return "music";
        case UPowerDeviceType.GamingInput:
            return "game";
        case UPowerDeviceType.Phone:
            return "phone";
        default:
            return "bolt";
        }
    }
    function iconForBt(icon) {
        const i = String(icon || "");
        if (i.indexOf("audio") >= 0 || i.indexOf("head") >= 0)
            return "music";
        if (i.indexOf("mouse") >= 0)
            return "mouse";
        if (i.indexOf("keyboard") >= 0)
            return "keyboard";
        if (i.indexOf("phone") >= 0)
            return "phone";
        if (i.indexOf("game") >= 0 || i.indexOf("joystick") >= 0)
            return "game";
        return "bluetooth";
    }

    // { name, icon, share (0 to 1), charging }
    readonly property var items: {
        const out = [];
        if (Sys.hasBattery)
            out.push({ name: Tr.t("This computer"), icon: "monitor", share: Sys.batteryPercent / 100, charging: Sys.charging });
        if (Phone.connected && Phone.battery)
            out.push({ name: Phone.device ? Phone.device.name : Tr.t("Phone"), icon: "phone", share: Phone.battery.charge / 100, charging: Phone.battery.charging });
        const names = {};
        for (const d of (Bluetooth.devices ? Bluetooth.devices.values : [])) {
            if (!d.connected || !d.batteryAvailable)
                continue;
            names[d.name] = true;
            out.push({ name: d.name, icon: iconForBt(d.icon), share: d.battery, charging: false });
        }
        for (const d of (UPower.devices ? UPower.devices.values : [])) {
            if (!d.ready || d.isLaptopBattery || d.type === UPowerDeviceType.LinePower || d.type === UPowerDeviceType.Battery || !d.isPresent && d.percentage <= 0)
                continue;
            if (d.model && names[d.model])
                continue;
            out.push({ name: d.model || Tr.t("Device"), icon: iconForType(d.type), share: d.percentage, charging: d.state === UPowerDeviceState.Charging });
        }
        return out;
    }
    function colorOf(it) {
        return it.charging ? Theme.good : it.share <= 0.15 ? Theme.error : it.share <= 0.3 ? Theme.warn : Theme.accent;
    }

    WidgetCaption {
        x: 20
        y: 16
        icon: "battery"
        text: Tr.t("Batteries")
    }

    // ---------------------------------------------------------------- rings
    Grid {
        visible: !root.tall
        anchors.horizontalCenter: parent.horizontalCenter
        y: 52
        columns: root.square ? Math.min(3, Math.max(1, root.items.length)) : Math.max(1, Math.min(5, root.items.length))
        columnSpacing: root.square ? 12 : 18
        rowSpacing: 12

        Repeater {
            model: root.tall ? [] : root.items.slice(0, root.square ? 6 : 5)

            Column {
                id: cell

                required property var modelData

                width: 76
                spacing: 6

                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 64
                    height: 64

                    Ring {
                        anchors.fill: parent
                        thickness: 6
                        value: cell.modelData.share
                        color: root.colorOf(cell.modelData)
                    }
                    Icon {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -7
                        name: cell.modelData.charging ? "charging" : cell.modelData.icon
                        size: 16
                        color: root.colorOf(cell.modelData)
                    }
                    Label {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: 11
                        text: Math.round(cell.modelData.share * 100) + "%"
                        size: 12
                        font.weight: Font.Bold
                    }
                }
                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: cell.modelData.name
                    size: 11
                    color: Theme.muted
                }
            }
        }
    }

    // ---------------------------------------------------------------- list
    Column {
        visible: root.tall
        x: 18
        y: 52
        width: root.width - 36
        spacing: 10

        Repeater {
            model: root.tall ? root.items.slice(0, 6) : []

            Item {
                id: row

                required property var modelData

                width: parent.width
                height: 40

                Rectangle {
                    width: 34
                    height: 34
                    radius: 17
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.alpha(root.colorOf(row.modelData), 0.16)

                    Icon {
                        anchors.centerIn: parent
                        name: row.modelData.charging ? "charging" : row.modelData.icon
                        size: 15
                        color: root.colorOf(row.modelData)
                    }
                }
                Label {
                    x: 44
                    y: 2
                    width: parent.width - 44 - 50
                    elide: Text.ElideRight
                    text: row.modelData.name
                    size: 13
                    font.weight: Font.Medium
                }
                Label {
                    anchors.right: parent.right
                    y: 2
                    text: Math.round(row.modelData.share * 100) + "%"
                    size: 13
                    font.weight: Font.DemiBold
                }
                Rectangle {
                    x: 44
                    y: 26
                    width: parent.width - 44
                    height: 6
                    radius: 3
                    color: Qt.alpha(Theme.text, 0.12)

                    Rectangle {
                        width: Math.max(6, parent.width * row.modelData.share)
                        height: parent.height
                        radius: 3
                        color: root.colorOf(row.modelData)
                    }
                }
            }
        }
    }
    Label {
        anchors.centerIn: parent
        visible: root.items.length === 0
        text: Tr.t("No devices with a battery")
        size: 13
        color: Theme.muted
    }
}
