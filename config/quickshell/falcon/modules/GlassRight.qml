import QtQuick
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.components
import qs.services

// The right island of the glass bar: screenshot and color tools, the tray, Claude, the
// microphone and camera in use, waiting updates, the keyboard layout, the status (network,
// Bluetooth, volume, battery) which opens the control center, and the notification bell.
GlassIsland {
    id: root

    readonly property var netDevices: Networking.devices.values
    readonly property bool wiredUp: netDevices.some(d => d.type === DeviceType.Wired && d.connected)
    readonly property bool wifiUp: netDevices.some(d => d.type === DeviceType.Wifi && d.connected)
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool btOn: !!adapter && adapter.enabled
    readonly property bool btLinked: btOn && adapter.devices.values.some(d => d.connected)
    readonly property bool showTools: Settings.get("panel.tools", true)
    readonly property bool showTray: Settings.get("panel.tray", true) && SystemTray.items.values.length > 0
    readonly property bool showNetwork: Settings.get("panel.wifi", true)
    readonly property bool showVolume: Audio.available && Settings.get("panel.volume", true)
    readonly property bool showBattery: Sys.hasBattery && Settings.get("panel.battery", true)

    property alias bellItem: bell

    spacing: 6

    BarButton {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.showTools
        objectName: "shot"
        icon: "screenshot"
        onClicked: Ui.region("copy")
    }
    BarButton {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.showTools
        objectName: "color"
        icon: "color"
        onClicked: Ui.run("falcon-color")
    }
    BarSeparator {
        visible: root.showTools
    }

    // Tray: a left click opens the app, a right click its menu.
    Row {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.showTray
        spacing: 0

        Repeater {
            model: Settings.get("panel.tray", true) ? SystemTray.items : []

            delegate: BarButton {
                id: trayItem

                required property var modelData

                objectName: "tray"

                anchors.verticalCenter: parent.verticalCenter
                padding: 6
                lit: Ui.popup === "tray" && Ui.trayItem === modelData
                onClicked: mouse => {
                    const item = trayItem.modelData;
                    if (mouse.button === Qt.MiddleButton) {
                        item.secondaryActivate();
                    } else if (mouse.button === Qt.LeftButton && !item.onlyMenu) {
                        item.activate();
                    } else if (item.hasMenu) {
                        Ui.trayItem = item;
                        Ui.popup = "tray";
                    }
                }

                IconImage {
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: 16
                    source: trayItem.modelData.icon
                }
            }
        }
    }
    BarSeparator {
        visible: root.showTray
    }

    BarButton {
        anchors.verticalCenter: parent.verticalCenter
        visible: Settings.get("panel.claude", true)
        objectName: "claude"
        icon: "claude"
        lit: Ui.popup === "claude"
        color: Qt.alpha(Theme.text, ClaudeUsage.hasData ? 1 : 0.45)
        onClicked: Ui.togglePopup("claude")
    }

    // Who is using the microphone or the camera. A click names the apps.
    BarButton {
        anchors.verticalCenter: parent.verticalCenter
        visible: Settings.get("panel.privacy", true) && (Privacy.mic.length > 0 || Privacy.camera.length > 0)
        onClicked: Privacy.tell()

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5

            Icon {
                visible: Privacy.mic.length > 0
                name: Audio.micMuted ? "micOff" : "mic"
                size: 16
                color: Audio.micMuted ? Theme.muted : Theme.error
            }
            Icon {
                visible: Privacy.camera.length > 0
                name: "camera"
                size: 16
                color: Theme.error
            }
        }
    }

    // Waiting system updates. Hidden when there are none.
    BarButton {
        anchors.verticalCenter: parent.verticalCenter
        visible: Settings.get("panel.updates", true) && Updates.enabled && (Updates.count > 0 || Updates.rebootNeeded)
        onClicked: Updates.clicked()

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "update"
                size: 16
                color: Updates.rebootNeeded && Updates.count === 0 ? Theme.accent : Theme.text
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                visible: Updates.count > 0
                text: Updates.count
                size: 13
                font.weight: Font.DemiBold
            }
        }
    }

    // Keyboard layout, a click switches it.
    BarButton {
        anchors.verticalCenter: parent.verticalCenter
        objectName: "lang"
        visible: Settings.get("panel.lang", true)
        onClicked: Niri.nextLayout()

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: Niri.layoutLabel
            size: 13
            font.weight: Font.DemiBold
        }
    }

    // Status: a click opens the control center.
    BarButton {
        id: status

        objectName: "status"
        anchors.verticalCenter: parent.verticalCenter
        lit: Ui.popup === "control"
        onClicked: Ui.togglePopup("control")

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.showNetwork
                name: root.wiredUp ? "ethernet" : (root.wifiUp || Networking.wifiEnabled ? "wifi" : "wifiOff")
                size: 16
                opacity: root.wiredUp || root.wifiUp ? 1 : 0.4
            }
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.showNetwork && root.btOn
                name: "bluetooth"
                size: 16
                opacity: root.btLinked ? 1 : 0.45
            }
            Row {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.showVolume
                spacing: 4

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Audio.muted ? "mute" : "volume"
                    size: 16
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Audio.percent
                    size: 12
                    font.weight: Font.DemiBold
                    font.features: {
                        "tnum": 1
                    }
                }
            }
            Row {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.showBattery
                spacing: 5

                BarBattery {
                    anchors.verticalCenter: parent.verticalCenter
                    value: Sys.batteryPercent / 100
                    charging: Sys.charging
                    color: Sys.batteryPercent <= 15 && !Sys.charging ? Theme.error : Theme.text
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Sys.batteryPercent + "%"
                    size: 12
                    font.weight: Font.DemiBold
                    color: Sys.batteryPercent <= 15 && !Sys.charging ? Theme.error : Theme.text
                    font.features: {
                        "tnum": 1
                    }
                }
            }
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: Caffeine.enabled
                name: "coffee"
                size: 16
                color: Theme.accent
            }
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: GameMode.enabled
                name: "game"
                size: 16
                color: Theme.accent
            }
            // A device with nothing to show still gets something to press.
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.showNetwork && !root.showVolume && !root.showBattery && !Caffeine.enabled && !GameMode.enabled
                name: "sun"
                size: 16
            }
        }
    }

    // Notifications: the badge counts the unread ones, a click opens their menu. It swings when a
    // notification card flies into it.
    BarButton {
        id: bell

        anchors.verticalCenter: parent.verticalCenter
        objectName: "bell"
        icon: "bell"
        lit: Ui.popup === "notifications"
        transformOrigin: Item.Top
        onClicked: Ui.togglePopup("notifications")

        Connections {
            target: Ui
            function onBellRingsChanged() {
                ring.restart();
            }
        }
        SequentialAnimation {
            id: ring

            NumberAnimation {
                target: bell
                property: "scale"
                to: 1.25
                duration: 90
                easing.type: Easing.OutCubic
            }
            ParallelAnimation {
                NumberAnimation {
                    target: bell
                    property: "scale"
                    to: 1
                    duration: 420
                    easing.type: Easing.OutBack
                }
                SequentialAnimation {
                    NumberAnimation {
                        target: bell
                        property: "rotation"
                        to: 18
                        duration: 80
                    }
                    NumberAnimation {
                        target: bell
                        property: "rotation"
                        to: -14
                        duration: 110
                    }
                    NumberAnimation {
                        target: bell
                        property: "rotation"
                        to: 8
                        duration: 100
                    }
                    NumberAnimation {
                        target: bell
                        property: "rotation"
                        to: 0
                        duration: 120
                    }
                }
            }
        }

        Rectangle {
            visible: Toasts.unread > 0
            x: bell.width - width + 1
            y: 1
            width: Math.max(15, badgeLabel.implicitWidth + 7)
            height: 15
            radius: 7.5
            color: Theme.error

            Label {
                id: badgeLabel

                anchors.centerIn: parent
                text: Toasts.unread > 99 ? "99+" : Toasts.unread
                size: 10
                font.weight: Font.Bold
                color: Theme.pill
            }
        }
    }
}
