import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Networking
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.components
import qs.services

// The terminal layout's bar: a thin dark strip in a monospace font, set in segments with
// arrow-shaped ends like a shell prompt. The falcon segment and the clock open the console,
// the status segments open the control center.
Rectangle {
    id: root

    property var screenInfo: null
    readonly property string output: screenInfo ? screenInfo.name : ""
    readonly property var netDevices: Networking.devices.values
    readonly property var wifiNet: {
        const dev = netDevices.find(d => d.type === DeviceType.Wifi);
        return dev ? dev.networks.values.find(n => n.connected) || null : null;
    }
    readonly property bool wiredUp: netDevices.some(d => d.type === DeviceType.Wired && d.connected)
    readonly property var focused: {
        const w = Niri.windows[Niri.focusedWindowId];
        return w && w.app_id !== "org.quickshell" ? w : null;
    }

    height: 28
    color: Qt.alpha(Theme.glassBase, Math.max(0.9, Theme.glassOpacity))

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Qt.alpha(Theme.accent, 0.35)
    }

    // An arrow end of a segment, pointing right or left.
    component Arrow: Shape {
        id: arrow

        property color fill: Theme.accent
        property bool pointsLeft: false

        width: 10
        height: root.height
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: arrow.fill
            startX: arrow.pointsLeft ? arrow.width : 0
            startY: 0
            PathLine {
                x: arrow.pointsLeft ? 0 : arrow.width
                y: arrow.height / 2
            }
            PathLine {
                x: arrow.pointsLeft ? arrow.width : 0
                y: arrow.height
            }
            PathLine {
                x: arrow.pointsLeft ? arrow.width : 0
                y: 0
            }
        }
    }

    component Mono: Text {
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        font.family: Theme.mono
        font.pixelSize: 12
        color: Theme.text
    }

    // A plain status segment: words, lit on hover, clickable.
    component Seg: Rectangle {
        id: seg

        property string text: ""
        property color tint: Theme.text
        signal clicked

        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        width: segLabel.implicitWidth + 16
        height: root.height
        color: segArea.containsMouse ? Qt.alpha(Theme.accent, 0.18) : "transparent"

        Mono {
            id: segLabel

            anchors.centerIn: parent
            text: seg.text
            color: seg.tint
        }
        MouseArea {
            id: segArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: seg.clicked()
        }
    }

    // ------------------------------------------------ left
    Row {
        height: parent.height

        Rectangle {
            width: logoRow.implicitWidth + 18
            height: root.height
            color: Ui.popup === "dashboard" ? Qt.lighter(Theme.accent, 1.15) : Theme.accent

            Row {
                id: logoRow

                anchors.centerIn: parent
                spacing: 6

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "terminalBox"
                    size: 14
                    color: Theme.accentText
                }
                Mono {
                    text: "falcon"
                    font.bold: true
                    color: Theme.accentText
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Ui.togglePopup("dashboard")
            }
        }
        Arrow {
            fill: Theme.accent
        }

        // Workspaces: the current one in brackets.
        Repeater {
            model: Settings.get("panel.ribbon", true) ? Niri.workspacesOn(root.output).filter(w => w.is_active || Niri.hasWindows(w.id) || !Settings.get("panel.hideEmpty", false)) : []

            delegate: Rectangle {
                id: space

                required property var modelData

                anchors.verticalCenter: parent.verticalCenter
                width: 28
                height: root.height
                color: spaceArea.containsMouse ? Qt.alpha(Theme.accent, 0.18) : "transparent"

                Mono {
                    anchors.centerIn: parent
                    text: space.modelData.is_active ? "[" + space.modelData.idx + "]" : String(space.modelData.idx)
                    font.bold: space.modelData.is_active
                    color: space.modelData.is_active ? Theme.accent : space.modelData.is_urgent ? Theme.error : Niri.hasWindows(space.modelData.id) ? Theme.text : Theme.muted
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
        Mono {
            leftPadding: 10
            width: Math.min(implicitWidth, root.width * 0.3)
            elide: Text.ElideRight
            text: root.focused ? "› " + (root.focused.title || root.focused.app_id) : ""
            color: Theme.muted
        }
    }

    // ------------------------------------------------ right
    Row {
        anchors.right: parent.right
        height: parent.height

        Repeater {
            model: Settings.get("panel.tray", true) ? SystemTray.items : []

            delegate: Item {
                id: trayItem

                required property var modelData

                width: 24
                height: root.height

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: 14
                    source: trayItem.modelData.icon
                }
                MouseArea {
                    anchors.fill: parent
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
        Seg {
            visible: Settings.get("panel.claude", true)
            text: "claude"
            tint: ClaudeUsage.hasData ? Theme.text : Theme.muted
            onClicked: Ui.togglePopup("claude")
        }
        Seg {
            visible: Privacy.mic.length > 0 || Privacy.camera.length > 0
            text: Privacy.camera.length > 0 ? "● cam" : "● mic"
            tint: Theme.error
            onClicked: Privacy.tell()
        }
        Seg {
            visible: Settings.get("panel.updates", true) && Updates.enabled && (Updates.count > 0 || Updates.rebootNeeded)
            text: "upd " + Updates.count
            tint: Theme.accent
            onClicked: Updates.clicked()
        }
        Seg {
            visible: Ui.recordBusy
            text: "● rec " + (Ui.recording ? Ui.pad(Math.floor(Ui.recordSeconds / 60)) + ":" + Ui.pad(Ui.recordSeconds % 60) : String(Ui.recordCountdown))
            tint: Theme.error
            onClicked: Ui.toggleRecording()
        }
        Seg {
            visible: Countdown.active
            text: "timer " + Countdown.text
            tint: Countdown.paused ? Theme.muted : Theme.accent
            onClicked: Countdown.togglePause()
        }
        Seg {
            text: "cpu " + String(Sys.cpu).padStart(2, " ") + "%"
            tint: Sys.cpu >= 85 ? Theme.error : Theme.text
            onClicked: Ui.togglePopup("dashboard")
        }
        Seg {
            text: "mem " + Sys.ram + "%"
            tint: Sys.ram >= 90 ? Theme.error : Theme.text
            onClicked: Ui.togglePopup("dashboard")
        }
        Seg {
            visible: Audio.available && Settings.get("panel.volume", true)
            text: Audio.muted ? "vol mute" : "vol " + Audio.percent + "%"
            onClicked: Ui.togglePopup("control")
        }
        Seg {
            visible: Sys.hasBattery && Settings.get("panel.battery", true)
            text: (Sys.charging ? "chg " : "bat ") + Sys.batteryPercent + "%"
            tint: Sys.batteryPercent <= 15 && !Sys.charging ? Theme.error : Theme.text
            onClicked: Ui.togglePopup("control")
        }
        Seg {
            visible: Settings.get("panel.wifi", true)
            text: root.wiredUp ? "eth up" : root.wifiNet ? "wifi " + root.wifiNet.name : "net down"
            tint: root.wiredUp || root.wifiNet ? Theme.text : Theme.muted
            onClicked: Ui.togglePopup("control")
        }
        Seg {
            visible: Settings.get("panel.lang", true)
            text: Niri.layoutLabel.toLowerCase()
            onClicked: Niri.nextLayout()
        }
        Seg {
            visible: Toasts.unread > 0 || Caffeine.enabled || GameMode.enabled || Toasts.doNotDisturb
            text: [Toasts.unread > 0 ? "msg " + Toasts.unread : "", Caffeine.enabled ? "awake" : "", GameMode.enabled ? "game" : "", Toasts.doNotDisturb ? "dnd" : ""].filter(w => w !== "").join(" ")
            tint: Theme.accent
            onClicked: Ui.togglePopup("control")
        }
        Arrow {
            pointsLeft: true
            fill: Theme.accent
        }
        Rectangle {
            width: clockLabel.implicitWidth + 18
            height: root.height
            color: Ui.popup === "control" ? Qt.lighter(Theme.accent, 1.15) : Theme.accent

            SystemClock {
                id: clock

                precision: Settings.get("panel.clockSeconds", false) ? SystemClock.Seconds : SystemClock.Minutes
            }
            Mono {
                id: clockLabel

                anchors.centerIn: parent
                text: (Settings.get("panel.clockDate", false) ? Ui.pad(clock.date.getDate()) + "." + Ui.pad(clock.date.getMonth() + 1) + " " : "") + Ui.pad(clock.hours) + ":" + Ui.pad(clock.minutes) + (Settings.get("panel.clockSeconds", false) ? ":" + Ui.pad(clock.seconds) : "")
                font.bold: true
                color: Theme.accentText
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Ui.togglePopup("control")
            }
        }
    }
}
