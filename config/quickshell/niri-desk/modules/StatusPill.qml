import QtQuick
import Quickshell.Networking
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.components
import qs.services

Rectangle {
    id: root

    implicitWidth: row.implicitWidth + (Settings.hug ? 26 : 12)
    height: Settings.hug ? 45 : 34
    // In the corner only the free corner stays round. The border on the screen edges lies off the screen.
    topRightRadius: Settings.hug ? 0 : 11
    bottomRightRadius: Settings.hug ? 0 : 11
    topLeftRadius: Settings.bar ? 0 : Settings.hug ? (Settings.bottom ? 18 : 0) : 11
    bottomLeftRadius: Settings.bar ? 0 : Settings.hug ? (Settings.bottom ? 0 : 18) : 11
    gradient: Gradient {
        GradientStop {
            position: 0
            color: Settings.bar ? "transparent" : Theme.glassTop
        }
        GradientStop {
            position: 1
            color: Settings.bar ? "transparent" : Theme.panel
        }
    }
    border.width: Settings.bar ? 0 : 1
    border.color: Theme.panelEdge

    EdgeCurve {
        visible: Settings.hug && !Settings.bar
        x: -size
        y: Settings.bottom ? 44 - size : 1
        flipX: true
        flipY: Settings.bottom
        color: Settings.bottom ? Theme.panel : Theme.glassTop
    }
    EdgeCurve {
        visible: Settings.hug && !Settings.bar
        x: root.width - 1 - size
        y: Settings.bottom ? -size : root.height
        flipX: true
        flipY: Settings.bottom
        color: Settings.bottom ? Theme.glassTop : Theme.panel
    }

    // Belgi radio yoqilganini emas, haqiqiy ulanishni ko'rsatadi. Sim ustun turadi.
    readonly property var netDevices: Networking.devices.values
    readonly property bool wiredUp: netDevices.some(d => d.type === DeviceType.Wired && d.connected)
    readonly property bool wifiUp: netDevices.some(d => d.type === DeviceType.Wifi && d.connected)
    readonly property bool showNetwork: Settings.get("panel.wifi", true)

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 0

        // Tray: dasturlar ikonkasi. Chap tugma ochadi, o'ng tugma menyu chiqaradi.
        Repeater {
            model: Settings.get("panel.tray", true) ? SystemTray.items : []

            delegate: Item {
                id: trayItem

                required property var modelData

                width: 28
                height: 34

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: 16
                    source: trayItem.modelData.icon
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
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
                }
            }
        }

        // Claude limiti: faqat ikonka, limitlar bosilganda ochiladi.
        Rectangle {
            visible: Settings.get("panel.claude", true)
            width: 34
            height: 34
            radius: 9
            color: claudeArea.containsMouse || Ui.popup === "claude" ? Qt.alpha(Theme.text, 0.08) : "transparent"

            Icon {
                anchors.centerIn: parent
                name: "claude"
                size: 18
                opacity: ClaudeUsage.hasData ? 1 : 0.45
            }
            MouseArea {
                id: claudeArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Ui.togglePopup("claude")
            }
        }

        // Klaviatura tili
        Rectangle {
            visible: Settings.get("panel.lang", true)
            width: langLabel.implicitWidth + 18
            height: 34
            radius: 9
            color: langArea.containsMouse ? Qt.alpha(Theme.text, 0.08) : "transparent"

            Label {
                id: langLabel

                anchors.centerIn: parent
                text: Niri.layoutLabel
                size: 14
            }

            MouseArea {
                id: langArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Niri.nextLayout()
            }
        }

        // Holat: bosilganda boshqaruv paneli ochiladi
        Rectangle {
            width: stateRow.implicitWidth + 18
            height: 34
            radius: 9
            color: stateArea.containsMouse || Ui.popup === "control" ? Qt.alpha(Theme.text, 0.08) : "transparent"

            Row {
                id: stateRow

                anchors.centerIn: parent
                spacing: 6

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: root.wiredUp ? "ethernet" : (root.wifiUp || Networking.wifiEnabled ? "wifi" : "wifiOff")
                    opacity: root.wiredUp || root.wifiUp ? 1 : 0.4
                    visible: root.showNetwork
                }
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Audio.muted ? "mute" : "volume"
                    visible: Audio.available && Settings.get("panel.volume", true)
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Audio.available && Settings.get("panel.volume", true)
                    text: Audio.percent
                    size: 14
                }
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Sys.charging ? "charging" : "battery"
                    visible: Sys.hasBattery && Settings.get("panel.battery", true)
                    color: Sys.batteryPercent <= 15 && !Sys.charging ? Theme.error : Theme.text
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Sys.hasBattery && Settings.get("panel.battery", true)
                    text: Sys.batteryPercent
                    size: 14
                }
                // O'qilmagan xabarlar va kofe rejimi belgisi
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Toasts.unread > 0
                    width: 7
                    height: 7
                    radius: 3.5
                    color: Theme.accent
                }
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "coffee"
                    color: Theme.accent
                    visible: Caffeine.enabled
                }
                // Hech narsa ko'rinmaydigan qurilmada ham tugma bosiladigan bo'lsin.
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "sun"
                    visible: !root.showNetwork && !(Audio.available && Settings.get("panel.volume", true)) && !(Sys.hasBattery && Settings.get("panel.battery", true)) && Toasts.unread === 0 && !Caffeine.enabled
                }
            }

            MouseArea {
                id: stateArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Ui.togglePopup("control")
            }
        }
    }
}
