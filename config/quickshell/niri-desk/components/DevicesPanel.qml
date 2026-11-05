import QtQuick
import qs.services

// Settings page of other devices: what is installed, the phone, sending, camera, tablet, mirror.
Column {
    id: root

    spacing: 12

    onVisibleChanged: Devices.watching = visible
    Component.onCompleted: Devices.watching = visible
    Component.onDestruction: Devices.watching = false

    Rectangle {
        width: parent.width
        height: note.implicitHeight + 28
        radius: 18
        color: Qt.alpha(Theme.accent, 0.16)
        visible: !Devices.allInstalled

        Label {
            id: note

            x: 16
            y: 14
            width: parent.width - 32 - install.width - 14
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
            size: 13
            text: Tr.t("These features need a few programs and local network ports. Installing asks for your password once.")
        }
        PillButton {
            id: install

            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: Tr.t("Install")
            accent: true
            onClicked: Devices.setup()
        }
    }

    Repeater {
        model: [
            {
                title: Tr.t("Phone"),
                icon: "phone",
                hint: Devices.phones.length > 0 ? Devices.phones.map(p => p.name).join(", ") : Tr.t("KDE Connect app on the phone: shared clipboard, notifications, files"),
                ready: !!Devices.extras.kdeconnect,
                button: Tr.t("Pair"),
                run: () => Devices.openPairing(),
                second: Devices.phones.length > 0 ? Tr.t("Ring") : "",
                secondRun: () => Devices.ring(Devices.phones[0].id)
            },
            {
                title: "LocalSend",
                icon: "share",
                hint: Tr.t("Send files to any nearby device, like AirDrop"),
                ready: !!Devices.extras.localsend,
                button: Tr.t("Open"),
                run: () => Devices.openLocalSend()
            },
            {
                title: Tr.t("Phone as a camera"),
                icon: "camera",
                hint: Devices.camera.on ? Tr.t("On") : Tr.t("Android 12 or newer, by USB with USB debugging on"),
                ready: !!Devices.extras.scrcpy,
                button: Devices.camera.on ? Tr.t("Stop") : Tr.t("Start"),
                run: () => Devices.toggleTool("niri-desk-phonecam")
            },
            {
                title: Tr.t("Tablet screen"),
                icon: "monitor",
                hint: Devices.sidecar.on ? Tr.t("In a VNC app on the tablet, connect to 127.0.0.1:5900") : Tr.t("Shows this screen on an Android tablet by USB, touch included. It is the same picture, niri cannot add a virtual display"),
                ready: !!Devices.extras.wayvnc,
                button: Devices.sidecar.on ? Tr.t("Stop") : Tr.t("Start"),
                run: () => Devices.toggleTool("niri-desk-sidecar")
            },
            {
                title: Tr.t("Mirror to another display"),
                icon: "copy",
                hint: Devices.mirror.on ? Tr.t("On") : Tr.t("Displays connected: {n}").replace("{n}", Devices.mirror.outputs || 0),
                ready: !!Devices.extras.mirror,
                button: Devices.mirror.on ? Tr.t("Stop") : Tr.t("Start"),
                run: () => Devices.toggleTool("niri-desk-mirror")
            }
        ]

        delegate: Rectangle {
            id: card

            required property var modelData

            width: root.width
            height: Math.max(62, words.implicitHeight + 24)
            radius: 18
            color: Qt.alpha(Theme.text, 0.045)
            border.width: 1
            border.color: Qt.alpha(Theme.text, 0.06)

            Icon {
                x: 16
                anchors.verticalCenter: parent.verticalCenter
                name: card.modelData.icon
                size: 20
                color: card.modelData.ready ? Theme.accent : Theme.muted
            }
            Column {
                id: words

                x: 50
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x - actions.width - 26

                Label {
                    text: card.modelData.title
                    size: 14
                }
                Label {
                    width: parent.width
                    text: card.modelData.ready ? card.modelData.hint : Tr.t("Not installed")
                    color: Theme.muted
                    size: 12
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                }
            }
            Row {
                id: actions

                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                visible: card.modelData.ready

                PillButton {
                    visible: !!card.modelData.second
                    text: card.modelData.second || ""
                    onClicked: card.modelData.secondRun()
                }
                PillButton {
                    text: card.modelData.button
                    onClicked: card.modelData.run()
                }
            }
        }
    }
}
