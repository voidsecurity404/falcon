import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.components
import qs.services

// The rail layout: one glass column along the left edge. Workspaces at the top, the clock in the
// middle (it opens the dashboard as a drawer beside the rail), the tray and the status at the bottom
// (the status opens the control center beside it).
Rectangle {
    id: root

    property var screenInfo: null
    readonly property string output: screenInfo ? screenInfo.name : ""
    readonly property var netDevices: Networking.devices.values
    readonly property bool wiredUp: netDevices.some(d => d.type === DeviceType.Wired && d.connected)
    readonly property bool wifiUp: netDevices.some(d => d.type === DeviceType.Wifi && d.connected)
    readonly property bool clock24: Settings.get("panel.clock24", true)
    readonly property bool showSeconds: Settings.get("panel.clockSeconds", false)
    readonly property bool showDate: Settings.get("panel.clockDate", false)
    // The bottom group, where the control center opens from.
    readonly property alias statusItem: statusPart

    width: 54
    radius: 20
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

    // A part of the rail with a rounded light on hover, or while its panel is open.
    component Part: Rectangle {
        id: part

        property bool lit: false
        property alias hovered: partArea.containsMouse
        signal clicked

        anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
        width: 42
        radius: 14
        color: lit ? Qt.alpha(Theme.accent, 0.22) : Qt.alpha(Theme.text, partArea.containsMouse ? 0.08 : 0)

        Behavior on color {
            ColorAnimation {
                duration: 160
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

    // ------------------------------------------------ workspaces, top
    Item {
        id: spaces

        readonly property var list: Niri.workspacesOn(root.output).filter(w => w.is_active || Niri.hasWindows(w.id) || !Settings.get("panel.hideEmpty", false))
        readonly property int step: 34

        anchors.horizontalCenter: parent.horizontalCenter
        y: 8
        width: 42
        height: list.length * step

        // The current workspace: a pill that slides between the numbers with a little stretch.
        Rectangle {
            readonly property int at: Math.max(0, spaces.list.findIndex(w => w.is_active))
            property real head: at * spaces.step
            property real tail: at * spaces.step

            x: 3
            y: Math.min(head, tail) + 2
            width: 36
            height: Math.abs(head - tail) + spaces.step - 4
            radius: 12
            color: Theme.accent
            visible: spaces.list.length > 0

            Behavior on head {
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on tail {
                NumberAnimation {
                    duration: 520
                    easing.type: Easing.OutCubic
                }
            }
        }

        Column {
            Repeater {
                model: spaces.list

                delegate: Item {
                    id: space

                    required property var modelData
                    readonly property bool active: modelData.is_active
                    readonly property bool busy: Niri.hasWindows(modelData.id)

                    width: 42
                    height: spaces.step

                    Label {
                        anchors.centerIn: parent
                        text: space.modelData.idx
                        font.family: Theme.mono
                        size: 14
                        font.weight: space.active ? Font.Bold : Font.Medium
                        color: space.active ? Theme.accentText : space.modelData.is_urgent ? Theme.error : space.busy || spaceArea.containsMouse ? Theme.text : Qt.alpha(Theme.text, 0.35)

                        Behavior on color {
                            ColorAnimation {
                                duration: 160
                            }
                        }
                    }
                    // A small mark under a busy workspace.
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: parent.height - 7
                        width: 4
                        height: 4
                        radius: 2
                        visible: space.busy && !space.active
                        color: Qt.alpha(Theme.text, 0.5)
                    }
                    MouseArea {
                        id: spaceArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Sticky.active ? Sticky.switchTo(space.modelData.idx) : Niri.focusWorkspace(space.modelData.idx)
                    }
                }
            }
        }
    }

    // ------------------------------------------------ clock, middle
    Part {
        anchors.verticalCenter: parent.verticalCenter
        height: clockColumn.implicitHeight + 20
        lit: Ui.popup === "dashboard"
        onClicked: Ui.togglePopup("dashboard")

        SystemClock {
            id: clock

            precision: root.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
        }

        Column {
            id: clockColumn

            anchors.centerIn: parent
            spacing: 0

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: Ui.recordBusy
                width: 8
                height: 8
                radius: 4
                color: Theme.error
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Ui.pad(root.clock24 ? clock.hours : clock.hours % 12 || 12)
                font.family: Theme.display
                size: 16
                font.weight: Font.DemiBold
                color: Theme.accent
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Ui.pad(clock.minutes)
                font.family: Theme.display
                size: 16
                font.weight: Font.DemiBold
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.showSeconds
                text: Ui.pad(clock.seconds)
                font.family: Theme.display
                size: 11
                color: Theme.muted
            }
            Item {
                width: 1
                height: root.showDate ? 6 : 0
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.showDate
                text: Ui.pad(clock.date.getDate()) + "." + Ui.pad(clock.date.getMonth() + 1)
                size: 11
                color: Qt.alpha(Theme.text, 0.7)
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: Countdown.active
                topPadding: 4
                text: Countdown.text
                size: 10
                color: Theme.accent
            }
        }
    }

    // ------------------------------------------------ tray, layout and status, bottom
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        spacing: 2

        Repeater {
            model: Settings.get("panel.tray", true) ? SystemTray.items : []

            delegate: Part {
                id: trayItem

                required property var modelData

                height: 32
                onClicked: {
                    if (!trayItem.modelData.onlyMenu)
                        trayItem.modelData.activate();
                    else if (trayItem.modelData.hasMenu) {
                        Ui.trayItem = trayItem.modelData;
                        Ui.popup = "tray";
                    }
                }

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: 16
                    source: trayItem.modelData.icon
                }
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

        Part {
            visible: Settings.get("panel.claude", true)
            height: 34
            lit: Ui.popup === "claude"
            onClicked: Ui.togglePopup("claude")

            Icon {
                anchors.centerIn: parent
                name: "claude"
                size: 17
                opacity: ClaudeUsage.hasData ? 1 : 0.45
            }
        }

        Part {
            visible: Settings.get("panel.lang", true)
            height: 30
            onClicked: Niri.nextLayout()

            Label {
                anchors.centerIn: parent
                text: Niri.layoutLabel
                size: 12
                font.weight: Font.Medium
            }
        }

        Part {
            id: statusPart

            height: statusColumn.implicitHeight + 18
            lit: Ui.popup === "control"
            onClicked: Ui.togglePopup("control")

            Column {
                id: statusColumn

                anchors.centerIn: parent
                spacing: 9

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: Privacy.mic.length > 0 || Privacy.camera.length > 0
                    name: Privacy.camera.length > 0 ? "camera" : "mic"
                    color: Theme.error
                    size: 17
                }
                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: Settings.get("panel.wifi", true)
                    name: root.wiredUp ? "ethernet" : (root.wifiUp || Networking.wifiEnabled ? "wifi" : "wifiOff")
                    opacity: root.wiredUp || root.wifiUp ? 1 : 0.4
                    size: 17
                }
                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: Audio.available && Settings.get("panel.volume", true)
                    name: Audio.muted ? "mute" : "volume"
                    size: 17
                }
                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: Caffeine.enabled
                    name: "coffee"
                    color: Theme.accent
                    size: 17
                }
                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: GameMode.enabled
                    name: "game"
                    color: Theme.accent
                    size: 17
                }
                // Battery as a small upright gauge with the number under it.
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: Sys.hasBattery && Settings.get("panel.battery", true)
                    spacing: 3

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 12
                        height: 20
                        radius: 3.5
                        color: "transparent"
                        border.width: 1.2
                        border.color: Qt.alpha(Theme.text, 0.6)

                        Rectangle {
                            x: 2
                            width: parent.width - 4
                            height: Math.max(2, (parent.height - 4) * Sys.batteryPercent / 100)
                            y: parent.height - 2 - height
                            radius: 1.5
                            color: Sys.charging ? Theme.good : Sys.batteryPercent <= 15 ? Theme.error : Theme.text
                        }
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Sys.batteryPercent
                        size: 10
                        font.weight: Font.Medium
                    }
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: Toasts.unread > 0
                    width: 7
                    height: 7
                    radius: 3.5
                    color: Theme.accent
                }
            }
        }
    }
}
