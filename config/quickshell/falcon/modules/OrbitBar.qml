import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.components
import qs.services

// The orbit layout's bar: a floating glass pill at the bottom middle. An orb on the left with
// a moon circling it (it opens the dashboard), the workspaces as dots, the clock, the tray and a
// round status button on the right (it opens the round control center).
Rectangle {
    id: root

    property var screenInfo: null
    readonly property string output: screenInfo ? screenInfo.name : ""
    readonly property var netDevices: Networking.devices.values
    readonly property bool wiredUp: netDevices.some(d => d.type === DeviceType.Wired && d.connected)
    readonly property bool wifiUp: netDevices.some(d => d.type === DeviceType.Wifi && d.connected)
    readonly property bool clock24: Settings.get("panel.clock24", true)
    // The status button's middle, where the round control center grows from.
    readonly property real statusCenter: row.x + statusButton.x + statusButton.width / 2

    width: row.implicitWidth + 16
    height: 50
    radius: 25
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

    SystemClock {
        id: clock

        precision: SystemClock.Seconds
    }

    Row {
        id: row

        x: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        // The orb: a ring of the minute, a moon going round with the seconds.
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 38
            height: 38

            Rectangle {
                anchors.fill: parent
                radius: 19
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Qt.lighter(Theme.accent, 1.2)
                    }
                    GradientStop {
                        position: 1
                        color: Theme.accent
                    }
                }
                scale: orbArea.pressed ? 0.88 : orbArea.containsMouse ? 1.06 : 1

                Behavior on scale {
                    NumberAnimation {
                        duration: 160
                        easing.type: Easing.OutBack
                    }
                }
            }
            Icon {
                anchors.centerIn: parent
                name: "orbit"
                size: 18
                color: Theme.accentText
                rotation: Ui.popup === "dashboard" ? 180 : 0

                Behavior on rotation {
                    NumberAnimation {
                        duration: 500
                        easing.type: Easing.OutBack
                    }
                }
            }
            Item {
                anchors.fill: parent
                rotation: clock.seconds * 6

                Behavior on rotation {
                    enabled: clock.seconds !== 0

                    NumberAnimation {
                        duration: 300
                    }
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: -3
                    width: 7
                    height: 7
                    radius: 3.5
                    color: Theme.text
                    border.width: 1
                    border.color: Theme.glassBase
                }
            }
            MouseArea {
                id: orbArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Ui.togglePopup("dashboard")
            }
        }

        // Workspaces as dots, the current one a stretched pill.
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            visible: Settings.get("panel.ribbon", true)

            Repeater {
                model: Niri.workspacesOn(root.output).filter(w => w.is_active || Niri.hasWindows(w.id) || !Settings.get("panel.hideEmpty", false))

                delegate: Rectangle {
                    id: space

                    required property var modelData
                    readonly property bool busy: Niri.hasWindows(modelData.id)

                    anchors.verticalCenter: parent.verticalCenter
                    width: modelData.is_active ? 26 : 10
                    height: 10
                    radius: 5
                    color: modelData.is_active ? Theme.accent : modelData.is_urgent ? Theme.error : Qt.alpha(Theme.text, busy ? 0.6 : spaceArea.containsMouse ? 0.4 : 0.22)

                    Behavior on width {
                        NumberAnimation {
                            duration: 320
                            easing.type: Easing.OutBack
                        }
                    }

                    MouseArea {
                        id: spaceArea

                        anchors.fill: parent
                        anchors.margins: -5
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Sticky.active ? Sticky.switchTo(space.modelData.idx) : Niri.focusWorkspace(space.modelData.idx)
                    }
                }
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 22
            color: Qt.alpha(Theme.text, 0.14)
        }

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: Ui.pad(root.clock24 ? clock.hours : clock.hours % 12 || 12) + ":" + Ui.pad(clock.minutes) + (Settings.get("panel.clockSeconds", false) ? ":" + Ui.pad(clock.seconds) : "")
            font.family: Theme.display
            size: 15
            font.weight: Font.DemiBold

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: Ui.togglePopup("dashboard")
            }
        }

        // Recording and the timer, small round chips.
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: Ui.recordBusy
            width: recLabel.implicitWidth + 30
            height: 30
            radius: 15
            color: Qt.alpha(Theme.error, 0.2)

            Rectangle {
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 8
                height: 8
                radius: 4
                color: Theme.error
            }
            Label {
                id: recLabel

                x: 22
                anchors.verticalCenter: parent.verticalCenter
                text: Ui.recording ? Ui.pad(Math.floor(Ui.recordSeconds / 60)) + ":" + Ui.pad(Ui.recordSeconds % 60) : String(Ui.recordCountdown)
                size: 12
                color: Theme.error
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Ui.toggleRecording()
            }
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: Countdown.active
            width: timerLabel.implicitWidth + 20
            height: 30
            radius: 15
            color: Qt.alpha(Theme.accent, 0.2)

            Label {
                id: timerLabel

                anchors.centerIn: parent
                text: Countdown.text
                size: 12
                opacity: Countdown.paused ? 0.5 : 1
            }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => mouse.button === Qt.RightButton ? Countdown.stop() : Countdown.togglePause()
            }
        }

        Repeater {
            model: Settings.get("panel.tray", true) ? SystemTray.items : []

            delegate: Rectangle {
                id: trayItem

                required property var modelData

                anchors.verticalCenter: parent.verticalCenter
                width: 30
                height: 30
                radius: 15
                color: Qt.alpha(Theme.text, trayArea.containsMouse ? 0.1 : 0)

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: 16
                    source: trayItem.modelData.icon
                }
                MouseArea {
                    id: trayArea

                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        const item = trayItem.modelData;
                        if (mouse.button === Qt.MiddleButton)
                            item.secondaryActivate();
                        else if (mouse.button === Qt.LeftButton && !item.onlyMenu)
                            item.activate();
                        else if (item.hasMenu) {
                            Ui.trayItem = item;
                            Ui.popup = "tray";
                        }
                    }
                }
            }
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: Settings.get("panel.claude", true)
            width: 30
            height: 30
            radius: 15
            color: Qt.alpha(Theme.text, claudeArea.containsMouse || Ui.popup === "claude" ? 0.1 : 0)

            Icon {
                anchors.centerIn: parent
                name: "claude"
                size: 16
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
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: Settings.get("panel.lang", true)
            width: 30
            height: 30
            radius: 15
            color: Qt.alpha(Theme.text, langArea.containsMouse ? 0.1 : 0)

            Label {
                anchors.centerIn: parent
                text: Niri.layoutLabel
                size: 11
                font.weight: Font.DemiBold
            }
            MouseArea {
                id: langArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Niri.nextLayout()
            }
        }

        // The round status button: the battery as a ring around the network or sound icon.
        Item {
            id: statusButton

            anchors.verticalCenter: parent.verticalCenter
            width: 38
            height: 38

            Rectangle {
                anchors.fill: parent
                radius: 19
                color: Ui.popup === "control" ? Qt.alpha(Theme.accent, 0.3) : Qt.alpha(Theme.text, statusArea.containsMouse ? 0.12 : 0.06)
            }
            Ring {
                anchors.fill: parent
                visible: Sys.hasBattery && Settings.get("panel.battery", true)
                thickness: 3
                value: Sys.batteryPercent / 100
                color: Sys.charging ? Theme.good : Sys.batteryPercent <= 15 ? Theme.error : Theme.accent
            }
            Icon {
                anchors.centerIn: parent
                name: Privacy.mic.length > 0 ? "mic" : root.wiredUp ? "ethernet" : (root.wifiUp || Networking.wifiEnabled ? "wifi" : "wifiOff")
                size: 16
                color: Privacy.mic.length > 0 ? Theme.error : Theme.text
                opacity: root.wiredUp || root.wifiUp || Privacy.mic.length > 0 ? 1 : 0.45
            }
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                visible: Toasts.unread > 0 || Caffeine.enabled || GameMode.enabled
                width: 9
                height: 9
                radius: 4.5
                color: Theme.accent
                border.width: 1
                border.color: Theme.glassBase
            }
            MouseArea {
                id: statusArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Ui.togglePopup("control")
            }
        }
    }
}
