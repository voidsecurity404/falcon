import QtQuick
import Quickshell.Networking
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.components
import qs.services

Rectangle {
    id: root

    // A copy drawn in the settings preview takes no clicks.
    property bool preview: false
    // panel.status: "together" is one panel, "chips" gives every group its own small glass
    // capsule, "minimal" leaves only the icons.
    readonly property string look: Settings.get("panel.status", "together")
    readonly property bool chips: look === "chips"
    readonly property bool minimal: look === "minimal"
    readonly property int groupHeight: 34
    // Where each visible group lies inside this item, for the blur behind the separate capsules.
    readonly property var groupRects: {
        const list = [];
        for (const g of [trayGroup, claudeGroup, privacyGroup, updateGroup, langGroup, stateGroup]) {
            if (g.visible && g.width > 0)
                list.push(Qt.rect(row.x + g.x, row.y + g.y, g.width, g.height));
        }
        return list;
    }

    implicitWidth: row.implicitWidth + (chips ? 0 : Settings.hug ? 26 : 12)
    height: Settings.hug ? 45 : 34
    // In the corner only the free corner stays round. The border on the screen edges lies off the screen.
    topRightRadius: Settings.hug ? 0 : 11
    bottomRightRadius: Settings.hug ? 0 : 11
    topLeftRadius: Settings.hug ? (Settings.bottom ? 18 : 0) : 11
    bottomLeftRadius: Settings.hug ? (Settings.bottom ? 0 : 18) : 11
    color: "transparent"

    // The panel itself. With separate capsules every group draws its own glass instead.
    Rectangle {
        anchors.fill: parent
        visible: !root.chips
        topRightRadius: root.topRightRadius
        bottomRightRadius: root.bottomRightRadius
        topLeftRadius: root.topLeftRadius
        bottomLeftRadius: root.bottomLeftRadius
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Theme.glassTop
            }
            GradientStop {
                position: 1
                color: Theme.panel
            }
        }
        border.width: 1
        border.color: Theme.panelEdge
    }

    EdgeCurve {
        visible: Settings.hug && !root.chips
        x: -size
        y: Settings.bottom ? 44 - size : 1
        flipX: true
        flipY: Settings.bottom
        color: Settings.bottom ? Theme.panel : Theme.glassTop
    }
    EdgeCurve {
        visible: Settings.hug && !root.chips
        x: root.width - 1 - size
        y: Settings.bottom ? -size : root.height
        flipX: true
        flipY: Settings.bottom
        color: Settings.bottom ? Theme.glassTop : Theme.panel
    }

    // One group of the panel. As a separate capsule it has its own glass and padding.
    component Group: Item {
        id: group

        default property alias content: inner.data
        readonly property real pad: root.chips ? 6 : 0

        width: visible ? inner.childrenRect.width + pad * 2 : 0
        height: root.groupHeight
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined

        Rectangle {
            anchors.fill: parent
            visible: root.chips
            radius: height / 2
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Theme.glassTop
                }
                GradientStop {
                    position: 1
                    color: Theme.panel
                }
            }
            border.width: 1
            border.color: Theme.panelEdge
        }
        Item {
            id: inner

            x: group.pad
            width: childrenRect.width
            height: parent.height
        }
    }

    // Belgi radio yoqilganini emas, haqiqiy ulanishni ko'rsatadi. Sim ustun turadi.
    readonly property var netDevices: Networking.devices.values
    readonly property bool wiredUp: netDevices.some(d => d.type === DeviceType.Wired && d.connected)
    readonly property bool wifiUp: netDevices.some(d => d.type === DeviceType.Wifi && d.connected)
    readonly property bool showNetwork: Settings.get("panel.wifi", true)

    Row {
        id: row

        anchors.centerIn: parent
        spacing: root.chips ? 6 : 0

        // Tray: dasturlar ikonkasi. Chap tugma ochadi, o'ng tugma menyu chiqaradi.
        Group {
            id: trayGroup

            visible: trayRow.width > 0

            Row {
                id: trayRow

                height: root.groupHeight

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
                            enabled: !root.preview
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
            }
        }

        // Claude limiti: faqat ikonka, limitlar bosilganda ochiladi.
        Group {
            id: claudeGroup

            visible: Settings.get("panel.claude", true)

            Rectangle {
                width: 34
                height: 34
                radius: root.chips ? height / 2 : 9
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
                    enabled: !root.preview
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Ui.togglePopup("claude")
                }
            }
        }

        // Who is using the microphone or the camera. A click names the apps.
        Group {
            id: privacyGroup

            visible: Privacy.mic.length > 0 || Privacy.camera.length > 0

            Rectangle {
                width: privacyRow.implicitWidth + 16
                height: 34
                radius: root.chips ? height / 2 : 9
                color: privacyArea.containsMouse ? Qt.alpha(Theme.text, 0.08) : "transparent"

                Row {
                    id: privacyRow

                    anchors.centerIn: parent
                    spacing: 6

                    Icon {
                        visible: Privacy.mic.length > 0
                        name: Audio.micMuted ? "micOff" : "mic"
                        color: Audio.micMuted ? Theme.muted : Theme.error
                    }
                    Icon {
                        visible: Privacy.camera.length > 0
                        name: "camera"
                        color: Theme.error
                    }
                }
                MouseArea {
                    id: privacyArea

                    anchors.fill: parent
                    enabled: !root.preview
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Privacy.tell()
                }
            }
        }

        // Waiting system updates. Hidden when there are none.
        Group {
            id: updateGroup

            visible: Settings.get("panel.updates", true) && Updates.enabled && (Updates.count > 0 || Updates.rebootNeeded)

            Rectangle {
                width: updateRow.implicitWidth + 16
                height: 34
                radius: root.chips ? height / 2 : 9
                color: updateArea.containsMouse ? Qt.alpha(Theme.text, 0.08) : "transparent"

                Row {
                    id: updateRow

                    anchors.centerIn: parent
                    spacing: 5

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "update"
                        color: Updates.rebootNeeded && Updates.count === 0 ? Theme.accent : Theme.text
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !root.minimal && Updates.count > 0
                        text: Updates.count
                        size: 14
                    }
                }
                MouseArea {
                    id: updateArea

                    anchors.fill: parent
                    enabled: !root.preview
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Updates.clicked()
                }
            }
        }

        // Klaviatura tili
        Group {
            id: langGroup

            visible: Settings.get("panel.lang", true)

            Rectangle {
                width: langLabel.implicitWidth + 18
                height: 34
                radius: root.chips ? height / 2 : 9
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
                    enabled: !root.preview
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Niri.nextLayout()
                }
            }
        }

        // Holat: bosilganda boshqaruv paneli ochiladi
        Group {
            id: stateGroup

            Rectangle {
                width: stateRow.implicitWidth + 18
                height: 34
                radius: root.chips ? height / 2 : 9
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
                        visible: !root.minimal && Audio.available && Settings.get("panel.volume", true)
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
                        visible: !root.minimal && Sys.hasBattery && Settings.get("panel.battery", true)
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
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "game"
                        color: Theme.accent
                        visible: GameMode.enabled
                    }
                    // Hech narsa ko'rinmaydigan qurilmada ham tugma bosiladigan bo'lsin.
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "sun"
                        visible: !root.showNetwork && !(Audio.available && Settings.get("panel.volume", true)) && !(Sys.hasBattery && Settings.get("panel.battery", true)) && Toasts.unread === 0 && !Caffeine.enabled && !GameMode.enabled
                    }
                }

                MouseArea {
                    id: stateArea

                    anchors.fill: parent
                    enabled: !root.preview
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Ui.togglePopup("control")
                }
            }
        }
    }
}
