import QtQuick
import qs.components
import qs.services

// The phone window's home screen: the phone's state on top and its "apps" below. Without a
// connected phone it walks through what is missing: KDE Connect, pairing, a connection.
Item {
    id: root

    readonly property var dev: Phone.device
    readonly property var apps: [
        {
            id: "ring",
            icon: "volume",
            name: Tr.t("Find"),
            plugin: "findmyphone"
        },
        {
            id: "ping",
            icon: "sparkle",
            name: Tr.t("Ping"),
            plugin: "ping"
        },
        {
            id: "files",
            icon: "folder",
            name: Tr.t("Files"),
            plugin: "share"
        },
        {
            id: "sms",
            icon: "message",
            name: Tr.t("Messages"),
            plugin: "sms"
        },
        {
            id: "notifications",
            icon: "bell",
            name: Tr.t("Alerts"),
            plugin: "notifications"
        },
        {
            id: "media",
            icon: "music",
            name: Tr.t("Media"),
            plugin: "mprisremote"
        },
        {
            id: "remote",
            icon: "touchpad",
            name: Tr.t("Remote"),
            plugin: "remotecontrol"
        },
        {
            id: "clipboard",
            icon: "copy",
            name: Tr.t("Clipboard"),
            plugin: "clipboard"
        },
        {
            id: "commands",
            icon: "terminal",
            name: Tr.t("Commands"),
            plugin: "runcommand"
        },
        {
            id: "settings",
            icon: "settings",
            name: Tr.t("Settings"),
            plugin: ""
        }
    ].filter(a => a.plugin === "" || Phone.has(a.plugin))

    function launch(app) {
        if (app.id === "ring")
            Phone.ring();
        else if (app.id === "ping")
            Phone.ping();
        else if (app.id === "clipboard")
            Phone.sendClipboard();
        else
            Ui.phonePage = app.id;
    }

    // ---- connected ----
    Column {
        anchors.fill: parent
        anchors.topMargin: 8
        spacing: 18
        visible: Phone.connected

        // The phone's name, how it is connected, battery and network.
        Item {
            width: parent.width
            height: 132

            Ring {
                id: batteryRing

                x: 6
                anchors.verticalCenter: parent.verticalCenter
                width: 112
                height: 112
                thickness: 9
                value: Phone.battery ? Phone.battery.charge / 100 : 0
                color: Phone.battery && Phone.battery.charge <= 15 && !Phone.battery.charging ? Theme.error : Theme.accent

                Column {
                    anchors.centerIn: parent
                    spacing: 0

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Phone.battery ? Phone.battery.charge : "–"
                        font.family: Theme.display
                        size: 28
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 3

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !!Phone.battery && Phone.battery.charging
                            name: "bolt"
                            size: 12
                            color: Theme.good
                        }
                        Label {
                            text: "%"
                            size: 12
                            color: Theme.muted
                        }
                    }
                }
            }

            Column {
                anchors.left: batteryRing.right
                anchors.leftMargin: 18
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Label {
                    width: parent.width
                    text: root.dev ? root.dev.name : ""
                    font.family: Theme.display
                    size: 17
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                }
                Row {
                    spacing: 6

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8
                        height: 8
                        radius: 4
                        color: Theme.good
                    }
                    Label {
                        text: root.dev && root.dev.usb ? Tr.t("Connected by USB") : Tr.t("Connected over Wi-Fi")
                        size: 12
                        color: Theme.muted
                    }
                }
                Row {
                    visible: !!(root.dev && root.dev.cell && root.dev.cell.type)
                    spacing: 6

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "signal"
                        size: 14
                        color: Theme.muted
                    }
                    Label {
                        text: root.dev && root.dev.cell ? root.dev.cell.type + " · " + "▂▄▆█".slice(0, Math.max(0, root.dev.cell.strength + 1)) : ""
                        size: 12
                        color: Theme.muted
                    }
                }
                Label {
                    visible: Phone.battery !== null
                    text: Phone.battery && Phone.battery.charging ? Tr.t("Charging") : Tr.t("On battery")
                    size: 12
                    color: Theme.muted
                }
            }
        }

        // What plays on the phone, one line; a click opens the media page.
        Rectangle {
            width: parent.width
            height: 56
            radius: 18
            visible: !!Phone.media && Phone.media.title !== ""
            color: Qt.alpha(Theme.text, mediaArea.containsMouse ? 0.1 : 0.06)

            Icon {
                id: mediaIcon

                x: 16
                anchors.verticalCenter: parent.verticalCenter
                name: "music"
                size: 18
                color: Theme.accent
            }
            Column {
                anchors.left: mediaIcon.right
                anchors.leftMargin: 12
                anchors.right: playButton.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter

                Label {
                    width: parent.width
                    text: Phone.media ? Phone.media.title : ""
                    size: 13
                    font.weight: Font.Medium
                }
                Label {
                    width: parent.width
                    text: Phone.media ? (Phone.media.artist || Phone.media.player) : ""
                    size: 11
                    color: Theme.muted
                }
            }
            MouseArea {
                id: mediaArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Ui.phonePage = "media"
            }
            Rectangle {
                id: playButton

                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 36
                height: 36
                radius: 18
                color: Theme.accent

                Icon {
                    anchors.centerIn: parent
                    name: Phone.media && Phone.media.playing ? "pause" : "play"
                    size: 15
                    filled: !(Phone.media && Phone.media.playing)
                    color: Theme.accentText
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Phone.mediaAction("PlayPause")
                }
            }
        }

        // The "apps", four in a row like a phone's home screen.
        Grid {
            id: grid

            width: parent.width
            columns: 4
            rowSpacing: 16
            columnSpacing: (width - 4 * 64) / 3

            Repeater {
                model: root.apps

                delegate: Item {
                    id: app

                    required property var modelData
                    required property int index

                    objectName: "phoneApp_" + modelData.id
                    width: 64
                    height: 86
                    opacity: 0
                    // The icons rise in one after another when the window opens.
                    Component.onCompleted: appear.start()

                    SequentialAnimation {
                        id: appear

                        PauseAnimation {
                            duration: 40 + app.index * 28
                        }
                        ParallelAnimation {
                            NumberAnimation {
                                target: app
                                property: "opacity"
                                to: 1
                                duration: 260
                            }
                            NumberAnimation {
                                target: tile
                                property: "y"
                                from: 14
                                to: 0
                                duration: 380
                                easing.type: Easing.OutBack
                            }
                        }
                    }

                    Rectangle {
                        id: tile

                        width: 64
                        height: 64
                        radius: 20
                        scale: tileArea.pressed ? 0.9 : tileArea.containsMouse ? 1.05 : 1
                        gradient: Gradient {
                            GradientStop {
                                position: 0
                                color: Qt.alpha(Theme.hueShift(Theme.accent, app.index * 0.035), tileArea.containsMouse ? 0.42 : 0.3)
                            }
                            GradientStop {
                                position: 1
                                color: Qt.alpha(Theme.hueShift(Theme.accent, app.index * 0.035), tileArea.containsMouse ? 0.24 : 0.14)
                            }
                        }
                        border.width: 1
                        border.color: Qt.alpha(Theme.text, 0.08)

                        Behavior on scale {
                            NumberAnimation {
                                duration: 160
                                easing.type: Easing.OutBack
                            }
                        }

                        Icon {
                            anchors.centerIn: parent
                            name: app.modelData.icon
                            size: 26
                            color: Theme.text
                        }
                        // Unread notifications on the Alerts icon, SMS count on Messages.
                        Rectangle {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: -4
                            readonly property int count: app.modelData.id === "notifications" ? Phone.notifications.length : 0
                            visible: count > 0
                            width: Math.max(20, badge.implicitWidth + 10)
                            height: 20
                            radius: 10
                            color: Theme.error

                            Label {
                                id: badge

                                anchors.centerIn: parent
                                text: parent.count > 99 ? "99+" : parent.count
                                size: 11
                                color: Theme.surface
                                font.weight: Font.Bold
                            }
                        }
                        MouseArea {
                            id: tileArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.launch(app.modelData)
                        }
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 70
                        width: 76
                        horizontalAlignment: Text.AlignHCenter
                        text: app.modelData.name
                        size: 11
                        color: Theme.muted
                    }
                }
            }
        }
    }

    // ---- not connected: what is missing ----
    Column {
        anchors.centerIn: parent
        width: parent.width - 20
        spacing: 14
        visible: !Phone.connected

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 92
            height: 92
            radius: 30
            color: Qt.alpha(Theme.accent, 0.16)

            Icon {
                anchors.centerIn: parent
                name: "phone"
                size: 42
                color: Theme.accent
            }
        }
        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            font.family: Theme.display
            size: 17
            text: !Phone.installed ? Tr.t("KDE Connect is missing") : Phone.pairRequests.length > 0 ? Tr.t("Pair request") : !Phone.running ? Tr.t("Starting KDE Connect…") : root.dev && root.dev.paired ? Tr.t("Phone is out of reach") : Tr.t("Connect your phone")
        }
        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            size: 12
            color: Theme.muted
            text: !Phone.installed ? Tr.t("Install it with: sudo pacman -S kdeconnect sshfs") : Phone.pairRequests.length > 0 ? Tr.t("{name} wants to pair. Check that the code matches the one on the phone: {code}").replace("{name}", Phone.pairRequests[0].name).replace("{code}", Phone.pairRequests[0].verificationKey) : root.dev && root.dev.paired ? Tr.t("Open KDE Connect on {name}, and keep both on the same Wi-Fi, or plug the phone in by USB with USB debugging on.").replace("{name}", root.dev.name) : Tr.t("Install KDE Connect on the phone, then pick it below. Same Wi-Fi, or USB with USB debugging on.")
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10
            visible: Phone.pairRequests.length > 0

            PhoneButton {
                text: Tr.t("Accept")
                primary: true
                onClicked: Phone.send("accept", {
                    device: Phone.pairRequests[0].id
                })
            }
            PhoneButton {
                text: Tr.t("Reject")
                onClicked: Phone.send("reject", {
                    device: Phone.pairRequests[0].id
                })
            }
        }

        // Phones in reach that are not paired yet.
        Repeater {
            model: Phone.pairRequests.length === 0 ? Phone.devices.filter(d => !d.paired && d.reachable) : []

            delegate: Rectangle {
                id: found

                required property var modelData

                width: parent.width
                height: 56
                radius: 18
                color: Qt.alpha(Theme.text, 0.06)

                Icon {
                    id: foundIcon

                    x: 16
                    anchors.verticalCenter: parent.verticalCenter
                    name: "phone"
                    size: 20
                }
                Label {
                    anchors.left: foundIcon.right
                    anchors.leftMargin: 12
                    anchors.right: pairButton.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: found.modelData.name
                    size: 13
                }
                PhoneButton {
                    id: pairButton

                    anchors.right: parent.right
                    anchors.rightMargin: 9
                    anchors.verticalCenter: parent.verticalCenter
                    text: found.modelData.pairRequested ? Tr.t("Waiting…") : Tr.t("Pair")
                    primary: !found.modelData.pairRequested
                    onClicked: Phone.send("pair", {
                        device: found.modelData.id
                    })
                }
            }
        }

        PhoneButton {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: Phone.installed && Phone.pairRequests.length === 0
            icon: "refresh"
            text: Tr.t("Search again")
            onClicked: Phone.send(Phone.running ? "discover" : "start")
        }
    }
}
