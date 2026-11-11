import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.components
import qs.services

// The windows layout's taskbar, after Windows 11: a full width bar along the bottom. The weather
// on the left; Start, search, task view and the apps in the middle (pinned ones from the dock
// setting first, a short line under running ones, a longer accent one under the focused app);
// the tray, the quick settings group and the two line clock on the right.
Rectangle {
    id: root

    property var screenInfo: null
    readonly property var netDevices: Networking.devices.values
    readonly property bool wiredUp: netDevices.some(d => d.type === DeviceType.Wired && d.connected)
    readonly property bool wifiUp: netDevices.some(d => d.type === DeviceType.Wifi && d.connected)
    readonly property bool clock24: Settings.get("panel.clock24", true)
    readonly property var pinned: Settings.get("dock.pinned", [])
    readonly property var running: {
        const groups = {};
        for (const key of Object.keys(Niri.windows)) {
            const w = Niri.windows[key];
            const id = w.app_id || "";
            if (id === "" || id === "org.quickshell")
                continue;
            (groups[id] = groups[id] || []).push(w);
        }
        return groups;
    }
    readonly property var apps: pinned.concat(Object.keys(running).filter(id => !pinned.includes(id)).sort())
    readonly property string focusedApp: {
        const w = Niri.windows[Niri.focusedWindowId];
        return w ? w.app_id || "" : "";
    }
    // Where Start sits, for the start menu's opening.
    readonly property real startX: center.x

    function openApp(id) {
        const windows = (running[id] || []).slice().sort((a, b) => a.id - b.id);
        if (windows.length === 0) {
            const entry = DesktopEntries.heuristicLookup(id);
            if (entry)
                entry.execute();
            return;
        }
        const now = windows.findIndex(w => w.is_focused);
        Niri.action("focus-window", "--id", String(windows[(now + 1) % windows.length].id));
    }

    height: 48
    color: Qt.alpha(Theme.glassBase, Math.max(0.78, Theme.glassOpacity))

    // The light top edge of the bar.
    Rectangle {
        width: parent.width
        height: 1
        color: Qt.alpha(Theme.text, 0.1)
    }

    // A button of the bar: a rounded light under the pointer and while its panel is open.
    component BarButton: Rectangle {
        id: button

        property bool lit: false
        property alias hovered: buttonArea.containsMouse
        property alias pressed: buttonArea.pressed
        property int buttons: Qt.LeftButton
        signal clicked(var mouse)

        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        height: 40
        radius: 5
        color: Qt.alpha(Theme.text, lit ? 0.1 : buttonArea.pressed ? 0.05 : buttonArea.containsMouse ? 0.08 : 0)
        border.width: lit || buttonArea.containsMouse ? 1 : 0
        border.color: Qt.alpha(Theme.text, 0.06)

        MouseArea {
            id: buttonArea

            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: button.buttons
            onClicked: mouse => button.clicked(mouse)
        }
    }

    // ------------------------------------------------ weather, left
    BarButton {
        x: 8
        width: weatherRow.implicitWidth + 20
        visible: Settings.get("weather.enabled", true) && Weather.hasData
        onClicked: Ui.togglePopup("dashboard")

        Row {
            id: weatherRow

            anchors.centerIn: parent
            spacing: 8

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: Weather.icon(Weather.code, Weather.isDay)
                size: 22
                color: Theme.accent
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter

                Label {
                    text: Weather.temperature + "°"
                    size: 12
                    font.weight: Font.DemiBold
                }
                Label {
                    text: Weather.describe(Weather.code)
                    size: 11
                    color: Theme.muted
                }
            }
        }
    }

    // ------------------------------------------------ start, search, task view and apps
    Row {
        id: center

        anchors.horizontalCenter: parent.horizontalCenter
        height: parent.height
        spacing: 4

        BarButton {
            width: 42
            lit: Ui.popup === "dashboard"
            onClicked: Ui.togglePopup("dashboard")

            // Four panes of the logo, lit from the top left like Windows 11's.
            Grid {
                anchors.centerIn: parent
                columns: 2
                spacing: 1.5
                scale: parent.pressed ? 0.85 : 1

                Repeater {
                    model: 4

                    Rectangle {
                        required property int index

                        width: 9.5
                        height: 9.5
                        radius: 1
                        gradient: Gradient {
                            GradientStop {
                                position: 0
                                color: Qt.lighter(Theme.accent, index === 0 ? 1.35 : 1.15)
                            }
                            GradientStop {
                                position: 1
                                color: Theme.accent
                            }
                        }
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: 120
                        easing.type: Easing.OutBack
                    }
                }
            }
        }
        BarButton {
            width: 42
            onClicked: Ui.togglePopup("menu")

            Icon {
                anchors.centerIn: parent
                name: "search"
                size: 19
            }
        }
        BarButton {
            width: 42
            lit: Niri.overview
            onClicked: Niri.action("toggle-overview")

            Icon {
                anchors.centerIn: parent
                name: "taskView"
                size: 19
            }
        }

        Repeater {
            model: root.apps

            delegate: BarButton {
                id: app

                required property string modelData
                readonly property var entry: DesktopEntries.heuristicLookup(modelData)
                readonly property bool isRunning: !!root.running[modelData]
                readonly property bool focused: root.focusedApp === modelData

                width: 42
                lit: focused
                buttons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton)
                        Settings.set("dock.pinned", root.pinned.includes(app.modelData) ? root.pinned.filter(p => p !== app.modelData) : root.pinned.concat([app.modelData]));
                    else if (mouse.button === Qt.MiddleButton && app.entry)
                        app.entry.execute();
                    else
                        root.openApp(app.modelData);
                }

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: 24
                    source: app.entry ? Quickshell.iconPath(app.entry.icon, true) : Quickshell.iconPath(app.modelData, true)
                    scale: app.pressed ? 0.82 : 1

                    Behavior on scale {
                        NumberAnimation {
                            duration: 140
                            easing.type: Easing.OutBack
                        }
                    }
                }
                // Short and gray when running, long and in the accent when focused.
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height - 4
                    width: app.focused ? 16 : 6
                    height: 3
                    radius: 1.5
                    visible: app.isRunning
                    color: app.focused ? Theme.accent : Qt.alpha(Theme.text, 0.55)

                    Behavior on width {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------------ tray, quick settings and clock, right
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 8
        height: parent.height
        spacing: 2

        Repeater {
            model: Settings.get("panel.tray", true) ? SystemTray.items : []

            delegate: BarButton {
                id: trayItem

                required property var modelData

                width: 30
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
                    implicitSize: 16
                    source: trayItem.modelData.icon
                }
            }
        }
        BarButton {
            visible: Settings.get("panel.claude", true)
            width: 32
            lit: Ui.popup === "claude"
            onClicked: Ui.togglePopup("claude")

            Icon {
                anchors.centerIn: parent
                name: "claude"
                size: 16
                opacity: ClaudeUsage.hasData ? 1 : 0.45
            }
        }
        BarButton {
            visible: Settings.get("panel.updates", true) && Updates.enabled && (Updates.count > 0 || Updates.rebootNeeded)
            width: 32
            onClicked: Updates.clicked()

            Icon {
                anchors.centerIn: parent
                name: "update"
                size: 16
                color: Theme.accent
            }
        }
        BarButton {
            visible: Settings.get("panel.lang", true)
            width: langLabel.implicitWidth + 16
            onClicked: Niri.nextLayout()

            Label {
                id: langLabel

                anchors.centerIn: parent
                text: Niri.layoutLabel
                size: 12
            }
        }
        // Recording, or the seconds before it starts. A click stops it.
        BarButton {
            visible: Ui.recordBusy
            width: recRow.implicitWidth + 16
            onClicked: Ui.toggleRecording()

            Row {
                id: recRow

                anchors.centerIn: parent
                spacing: 6

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8
                    height: 8
                    radius: 4
                    color: Theme.error
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Ui.recording ? Ui.pad(Math.floor(Ui.recordSeconds / 60)) + ":" + Ui.pad(Ui.recordSeconds % 60) : String(Ui.recordCountdown)
                    size: 12
                    color: Theme.error
                }
            }
        }
        BarButton {
            visible: Countdown.active
            width: timerRow.implicitWidth + 16
            onClicked: Countdown.togglePause()

            Row {
                id: timerRow

                anchors.centerIn: parent
                spacing: 5
                opacity: Countdown.paused ? 0.5 : 1

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Countdown.icon
                    size: 15
                    color: Theme.accent
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Countdown.text
                    size: 12
                }
            }
        }
        // The quick settings group: network, sound and battery in one button.
        BarButton {
            width: quickRow.implicitWidth + 20
            lit: Ui.popup === "control"
            onClicked: Ui.togglePopup("control")

            Row {
                id: quickRow

                anchors.centerIn: parent
                spacing: 10

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Privacy.mic.length > 0 || Privacy.camera.length > 0
                    name: Privacy.camera.length > 0 ? "camera" : "mic"
                    size: 16
                    color: Theme.error
                }
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Settings.get("panel.wifi", true)
                    name: root.wiredUp ? "ethernet" : (root.wifiUp || Networking.wifiEnabled ? "wifi" : "wifiOff")
                    opacity: root.wiredUp || root.wifiUp ? 1 : 0.45
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
                    visible: Sys.hasBattery && Settings.get("panel.battery", true)
                    name: Sys.charging ? "charging" : "battery"
                    size: 18
                    color: Sys.batteryPercent <= 15 && !Sys.charging ? Theme.error : Theme.text
                }
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Caffeine.enabled
                    name: "coffee"
                    size: 15
                    color: Theme.accent
                }
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: GameMode.enabled
                    name: "game"
                    size: 15
                    color: Theme.accent
                }
            }
        }
        // The clock, two lines. Opens the notifications and the calendar.
        BarButton {
            width: clockColumn.implicitWidth + 22 + (Toasts.unread > 0 ? 14 : 0)
            lit: Ui.popup === "calendar"
            onClicked: Ui.togglePopup("calendar")

            SystemClock {
                id: clock

                precision: SystemClock.Minutes
            }
            Column {
                id: clockColumn

                x: 11
                anchors.verticalCenter: parent.verticalCenter

                Label {
                    anchors.right: parent.right
                    text: Ui.pad(root.clock24 ? clock.hours : clock.hours % 12 || 12) + ":" + Ui.pad(clock.minutes) + (root.clock24 ? "" : clock.hours < 12 ? " AM" : " PM")
                    size: 12
                }
                Label {
                    anchors.right: parent.right
                    text: Ui.pad(clock.date.getDate()) + "." + Ui.pad(clock.date.getMonth() + 1) + "." + clock.date.getFullYear()
                    size: 12
                }
            }
            // Unread notifications: a dot beside the clock, like the bell on Windows 11.
            Rectangle {
                visible: Toasts.unread > 0
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 8
                height: 8
                radius: 4
                color: Theme.accent
            }
        }
    }
}
