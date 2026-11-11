import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.components
import qs.services

// The inside of the halo capsule: workspaces, the clock and the status, parted by thin lines.
// The clock opens the dashboard and the status opens the control center, both grown out of
// the same capsule.
Row {
    id: root

    property string output: ""

    readonly property var netDevices: Networking.devices.values
    readonly property bool wiredUp: netDevices.some(d => d.type === DeviceType.Wired && d.connected)
    readonly property bool wifiUp: netDevices.some(d => d.type === DeviceType.Wifi && d.connected)
    readonly property bool showSeconds: Settings.get("panel.clockSeconds", false)
    readonly property bool showDate: Settings.get("panel.clockDate", false)
    readonly property bool clock24: Settings.get("panel.clock24", true)

    height: 40
    spacing: 4

    component Divider: Rectangle {
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        width: 1
        height: 16
        color: Qt.alpha(Theme.text, 0.14)
    }

    // A rounded hover light behind a part of the capsule.
    component Part: Rectangle {
        id: part

        property alias hovered: partArea.containsMouse
        property bool lit: false
        signal clicked

        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        height: 32
        radius: 16
        color: Qt.alpha(Theme.text, lit ? 0.12 : partArea.containsMouse ? 0.08 : 0)

        Behavior on color {
            ColorAnimation {
                duration: 140
            }
        }

        MouseArea {
            id: partArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: part.clicked()
        }
    }

    // ------------------------------------------------ workspaces: dots, the current one a numbered pill
    Item {
        id: spaces

        readonly property var list: Niri.workspacesOn(root.output).filter(w => w.is_active || Niri.hasWindows(w.id) || !Settings.get("panel.hideEmpty", false))

        anchors.verticalCenter: parent.verticalCenter
        width: spaceRow.width + 12
        height: 32

        Row {
            id: spaceRow

            anchors.centerIn: parent
            spacing: 3

            Repeater {
                model: spaces.list

                delegate: Item {
                    id: space

                    required property var modelData
                    readonly property bool active: modelData.is_active
                    readonly property bool busy: Niri.hasWindows(modelData.id)

                    width: active ? 30 : 14
                    height: 22

                    Behavior on width {
                        NumberAnimation {
                            duration: 380
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: [0.3, 1.35, 0.4, 1, 1, 1]
                        }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: space.active ? parent.width : spaceArea.containsMouse ? 9 : 7
                        height: space.active ? 22 : width
                        radius: height / 2
                        color: space.active ? Theme.accent : space.modelData.is_urgent ? Theme.error : Qt.alpha(Theme.text, space.busy ? 0.75 : 0.28)

                        Behavior on width {
                            NumberAnimation {
                                duration: 260
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on height {
                            NumberAnimation {
                                duration: 260
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                            }
                        }
                    }
                    Label {
                        anchors.centerIn: parent
                        text: space.modelData.idx
                        size: 12
                        font.family: Theme.mono
                        font.weight: Font.Bold
                        color: Theme.accentText
                        opacity: space.active ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 200
                            }
                        }
                    }
                    MouseArea {
                        id: spaceArea

                        anchors.fill: parent
                        anchors.margins: -2
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Sticky.active ? Sticky.switchTo(space.modelData.idx) : Niri.focusWorkspace(space.modelData.idx)
                    }
                }
            }
        }
    }

    Divider {}

    // ------------------------------------------------ clock, recording and timer
    Part {
        width: clockRow.implicitWidth + 28
        lit: Ui.popup === "dashboard"
        onClicked: Ui.togglePopup("dashboard")

        SystemClock {
            id: clock

            precision: root.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
        }

        Row {
            id: clockRow

            anchors.centerIn: parent
            spacing: 8

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: Ui.recordBusy
                width: 8
                height: 8
                radius: 4
                color: Theme.error
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                visible: Ui.recordBusy
                text: Ui.recording ? Ui.pad(Math.floor(Ui.recordSeconds / 60)) + ":" + Ui.pad(Ui.recordSeconds % 60) : String(Ui.recordCountdown)
                color: Theme.error
                size: 14
                font.weight: Font.Medium
            }
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: Countdown.active
                name: Countdown.icon
                size: 16
                color: Theme.accent
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                visible: Countdown.active
                text: Countdown.text
                size: 14
                color: Theme.accent
                font.weight: Font.Medium
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.showDate
                text: clock.date.toLocaleDateString(Qt.locale(), "ddd d MMM")
                color: Qt.alpha(Theme.text, 0.7)
                size: 13
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    const hours = root.clock24 ? clock.hours : clock.hours % 12 || 12;
                    return Ui.pad(hours) + ":" + Ui.pad(clock.minutes) + (root.showSeconds ? ":" + Ui.pad(clock.seconds) : "") + (root.clock24 ? "" : clock.hours < 12 ? " AM" : " PM");
                }
                size: 15
                font.weight: Font.DemiBold
                font.features: {
                    "tnum": 1
                }
            }
        }
    }

    Divider {}

    // ------------------------------------------------ tray
    Row {
        anchors.verticalCenter: parent.verticalCenter
        visible: trayRepeater.count > 0

        Repeater {
            id: trayRepeater

            model: Settings.get("panel.tray", true) ? SystemTray.items : []

            delegate: Part {
                id: trayItem

                required property var modelData

                width: 28
                onClicked: {
                    const item = trayItem.modelData;
                    if (!item.onlyMenu)
                        item.activate();
                    else if (item.hasMenu) {
                        Ui.trayItem = item;
                        Ui.popup = "tray";
                    }
                }

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: 16
                    source: trayItem.modelData.icon
                }
                // The menu is on a right click, which Part does not take.
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    onClicked: {
                        if (trayItem.modelData.hasMenu) {
                            Ui.trayItem = trayItem.modelData;
                            Ui.popup = "tray";
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------------ the keyboard layout
    Part {
        visible: Settings.get("panel.lang", true)
        width: langLabel.implicitWidth + 18
        onClicked: Niri.nextLayout()

        Label {
            id: langLabel

            anchors.centerIn: parent
            text: Niri.layoutLabel
            size: 13
            font.weight: Font.Medium
        }
    }

    // ------------------------------------------------ status: opens the control center
    Part {
        width: stateRow.implicitWidth + 24
        lit: Ui.popup === "control"
        onClicked: Ui.togglePopup("control")

        Row {
            id: stateRow

            anchors.centerIn: parent
            spacing: 7

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: Privacy.mic.length > 0 || Privacy.camera.length > 0
                name: Privacy.camera.length > 0 ? "camera" : "mic"
                color: Theme.error
                size: 16
            }
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: Settings.get("panel.wifi", true)
                name: root.wiredUp ? "ethernet" : (root.wifiUp || Networking.wifiEnabled ? "wifi" : "wifiOff")
                opacity: root.wiredUp || root.wifiUp ? 1 : 0.4
                size: 16
            }
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: Audio.available && Settings.get("panel.volume", true)
                name: Audio.muted ? "mute" : "volume"
                size: 16
            }
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: Caffeine.enabled
                name: "coffee"
                color: Theme.accent
                size: 16
            }
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: GameMode.enabled
                name: "game"
                color: Theme.accent
                size: 16
            }
            // Battery as a small gauge with the number beside it.
            Row {
                anchors.verticalCenter: parent.verticalCenter
                visible: Sys.hasBattery && Settings.get("panel.battery", true)
                spacing: 5

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 11
                    radius: 3.5
                    color: "transparent"
                    border.width: 1.2
                    border.color: Qt.alpha(Theme.text, 0.6)

                    Rectangle {
                        x: 2
                        y: 2
                        width: Math.max(2, (parent.width - 4) * Sys.batteryPercent / 100)
                        height: parent.height - 4
                        radius: 1.5
                        color: Sys.charging ? Theme.good : Sys.batteryPercent <= 15 ? Theme.error : Theme.text
                    }
                    Rectangle {
                        x: parent.width + 1
                        anchors.verticalCenter: parent.verticalCenter
                        width: 2
                        height: 4
                        radius: 1
                        color: Qt.alpha(Theme.text, 0.6)
                    }
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Sys.batteryPercent
                    size: 13
                    font.weight: Font.Medium
                }
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: Toasts.unread > 0
                width: 7
                height: 7
                radius: 3.5
                color: Theme.accent
            }
        }
    }
}
