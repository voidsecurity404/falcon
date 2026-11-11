import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.components
import qs.services

// The macos layout's menu bar: a thin translucent strip along the top. The apple menu and the
// focused app's name in bold on the left, then the workspaces; the tray, battery, Wi-Fi,
// search, the control center and the date and time on the right. The item whose menu is open
// stays lit, as on macOS.
Rectangle {
    id: root

    property var screenInfo: null
    readonly property string output: screenInfo ? screenInfo.name : ""
    readonly property var netDevices: Networking.devices.values
    readonly property bool wiredUp: netDevices.some(d => d.type === DeviceType.Wired && d.connected)
    readonly property bool wifiUp: netDevices.some(d => d.type === DeviceType.Wifi && d.connected)
    readonly property bool clock24: Settings.get("panel.clock24", true)
    readonly property var focused: {
        const w = Niri.windows[Niri.focusedWindowId];
        return w && w.app_id !== "org.quickshell" ? w : null;
    }
    readonly property string appName: {
        if (!focused)
            return "Falcon";
        const entry = DesktopEntries.heuristicLookup(focused.app_id);
        return entry ? entry.name : focused.app_id;
    }
    // Where the date sits, for the notification center.
    readonly property real clockRight: width

    height: 30
    color: Qt.alpha(Theme.glassBase, Math.max(0.5, Theme.glassOpacity * 0.8))

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Qt.alpha(Theme.text, 0.08)
    }

    component MenuItem: Rectangle {
        id: item

        property bool lit: false
        property int buttons: Qt.LeftButton
        signal clicked(var mouse)

        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        height: 24
        radius: 5
        color: Qt.alpha(Theme.text, lit ? 0.2 : itemArea.containsMouse ? 0.1 : 0)

        MouseArea {
            id: itemArea

            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: item.buttons
            onClicked: mouse => item.clicked(mouse)
        }
    }

    // ------------------------------------------------ left: apple, app name, workspaces
    Row {
        x: 8
        height: parent.height
        spacing: 2

        MenuItem {
            width: 34
            lit: Ui.popup === "apple"
            onClicked: Ui.togglePopup("apple")

            Icon {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -1
                name: "apple"
                filled: true
                size: 16
            }
        }
        MenuItem {
            width: appLabel.implicitWidth + 18
            onClicked: Ui.togglePopup("menu")

            Label {
                id: appLabel

                anchors.centerIn: parent
                text: root.appName
                size: 13
                font.weight: Font.Bold
            }
        }
        Repeater {
            model: Settings.get("panel.ribbon", true) ? Niri.workspacesOn(root.output).filter(w => w.is_active || Niri.hasWindows(w.id) || !Settings.get("panel.hideEmpty", false)) : []

            delegate: MenuItem {
                id: space

                required property var modelData

                width: 26
                lit: modelData.is_active
                onClicked: Sticky.active ? Sticky.switchTo(space.modelData.idx) : Niri.focusWorkspace(space.modelData.idx)

                Label {
                    anchors.centerIn: parent
                    text: space.modelData.idx
                    size: 12
                    font.weight: space.modelData.is_active ? Font.DemiBold : Font.Normal
                    color: space.modelData.is_active || Niri.hasWindows(space.modelData.id) ? Theme.text : Theme.muted
                }
            }
        }
    }

    // ------------------------------------------------ right: status and clock
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 8
        height: parent.height
        spacing: 2

        Repeater {
            model: Settings.get("panel.tray", true) ? SystemTray.items : []

            delegate: MenuItem {
                id: trayItem

                required property var modelData

                width: 28
                buttons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
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

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: 15
                    source: trayItem.modelData.icon
                }
            }
        }
        MenuItem {
            visible: Settings.get("panel.claude", true)
            width: 28
            lit: Ui.popup === "claude"
            onClicked: Ui.togglePopup("claude")

            Icon {
                anchors.centerIn: parent
                name: "claude"
                size: 15
                opacity: ClaudeUsage.hasData ? 1 : 0.45
            }
        }
        MenuItem {
            visible: Privacy.mic.length > 0 || Privacy.camera.length > 0
            width: 28
            onClicked: Privacy.tell()

            Rectangle {
                anchors.centerIn: parent
                width: 8
                height: 8
                radius: 4
                color: Privacy.camera.length > 0 ? Theme.good : "#ff9f0a"
            }
        }
        MenuItem {
            visible: Settings.get("panel.updates", true) && Updates.enabled && (Updates.count > 0 || Updates.rebootNeeded)
            width: 28
            onClicked: Updates.clicked()

            Icon {
                anchors.centerIn: parent
                name: "update"
                size: 15
            }
        }
        MenuItem {
            visible: Ui.recordBusy
            width: recLabel.implicitWidth + 26
            onClicked: Ui.toggleRecording()

            Rectangle {
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 7
                height: 7
                radius: 3.5
                color: Theme.error
            }
            Label {
                id: recLabel

                x: 20
                anchors.verticalCenter: parent.verticalCenter
                text: Ui.recording ? Ui.pad(Math.floor(Ui.recordSeconds / 60)) + ":" + Ui.pad(Ui.recordSeconds % 60) : String(Ui.recordCountdown)
                size: 12
            }
        }
        MenuItem {
            visible: Countdown.active
            width: timerLabel.implicitWidth + 16
            onClicked: Countdown.togglePause()

            Label {
                id: timerLabel

                anchors.centerIn: parent
                text: Countdown.text
                size: 12
                opacity: Countdown.paused ? 0.5 : 1
            }
        }
        MenuItem {
            visible: Settings.get("panel.lang", true)
            width: langLabel.implicitWidth + 16
            onClicked: Niri.nextLayout()

            Label {
                id: langLabel

                anchors.centerIn: parent
                text: Niri.layoutLabel
                size: 12
                font.weight: Font.Medium
            }
        }
        // The battery as on macOS: the number, then a small battery filled to the level.
        MenuItem {
            visible: Sys.hasBattery && Settings.get("panel.battery", true)
            width: batteryRow.implicitWidth + 16
            onClicked: Ui.togglePopup("control")

            Row {
                id: batteryRow

                anchors.centerIn: parent
                spacing: 6

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Sys.batteryPercent + "%"
                    size: 12
                }
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 25
                    height: 12

                    Rectangle {
                        width: 22
                        height: 12
                        radius: 3.5
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.alpha(Theme.text, 0.55)

                        Rectangle {
                            x: 2
                            y: 2
                            width: (parent.width - 4) * Sys.batteryPercent / 100
                            height: parent.height - 4
                            radius: 1.5
                            color: Sys.charging ? Theme.good : Sys.batteryPercent <= 15 ? Theme.error : Theme.text
                        }
                    }
                    Rectangle {
                        x: 23
                        y: 4
                        width: 2
                        height: 4
                        radius: 1
                        color: Qt.alpha(Theme.text, 0.55)
                    }
                }
            }
        }
        MenuItem {
            visible: Settings.get("panel.wifi", true)
            width: 30
            onClicked: {
                Ui.popup = "control";
                Ui.controlPage = "wifi";
            }

            Icon {
                anchors.centerIn: parent
                name: root.wiredUp ? "ethernet" : (root.wifiUp || Networking.wifiEnabled ? "wifi" : "wifiOff")
                opacity: root.wiredUp || root.wifiUp ? 1 : 0.45
                size: 15
            }
        }
        MenuItem {
            width: 30
            onClicked: Ui.togglePopup("menu")

            Icon {
                anchors.centerIn: parent
                name: "search"
                size: 14
            }
        }
        MenuItem {
            width: 30
            lit: Ui.popup === "control"
            onClicked: Ui.togglePopup("control")

            Icon {
                anchors.centerIn: parent
                name: "toggles"
                size: 16
            }
        }
        MenuItem {
            width: clockLabel.implicitWidth + 18
            lit: Ui.popup === "dashboard"
            onClicked: Ui.togglePopup("dashboard")

            SystemClock {
                id: clock

                precision: Settings.get("panel.clockSeconds", false) ? SystemClock.Seconds : SystemClock.Minutes
            }
            Label {
                id: clockLabel

                anchors.centerIn: parent
                text: {
                    const day = Tr.capitalized(clock.date.toLocaleDateString(Tr.locale, "ddd d MMM"));
                    const hours = root.clock24 ? clock.hours : clock.hours % 12 || 12;
                    const time = Ui.pad(hours) + ":" + Ui.pad(clock.minutes) + (Settings.get("panel.clockSeconds", false) ? ":" + Ui.pad(clock.seconds) : "") + (root.clock24 ? "" : clock.hours < 12 ? " AM" : " PM");
                    return day + "  " + time;
                }
                size: 13
                font.weight: Font.Medium
            }
            Rectangle {
                visible: Toasts.unread > 0
                anchors.right: parent.right
                anchors.rightMargin: 2
                anchors.top: parent.top
                anchors.topMargin: 2
                width: 6
                height: 6
                radius: 3
                color: Theme.accent
            }
        }
    }
}
