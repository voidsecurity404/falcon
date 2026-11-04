import QtQuick
import Quickshell.Widgets
import qs.components
import qs.services

Item {
    id: root

    readonly property var player: Media.player

    ClippingRectangle {
        id: art

        x: 16
        anchors.verticalCenter: parent.verticalCenter
        width: 118
        height: 118
        radius: 14
        color: Qt.alpha(Theme.text, 0.08)

        Icon {
            anchors.centerIn: parent
            name: "music"
            size: 30
            color: Theme.muted
        }
        Image {
            anchors.fill: parent
            source: root.player ? root.player.trackArtUrl : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 240
            sourceSize.height: 240
        }
    }
    Column {
        anchors.left: art.right
        anchors.leftMargin: 14
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Column {
            width: parent.width
            spacing: 1

            Label {
                width: parent.width
                text: root.player ? root.player.trackTitle : Tr.t("No music")
                size: 14
                font.weight: Font.Medium
            }
            Label {
                width: parent.width
                text: root.player ? root.player.trackArtist : Tr.t("Nothing is playing")
                color: Theme.muted
                size: 12
            }
        }
        Rectangle {
            width: parent.width
            height: 4
            radius: 2
            visible: !!root.player
            color: Qt.alpha(Theme.text, 0.14)

            Rectangle {
                width: Math.max(height, parent.width * Math.max(0, Math.min(1, Media.progress)))
                height: parent.height
                radius: 2
                color: Theme.accent
            }
        }
        Row {
            spacing: 10
            visible: !!root.player

            Repeater {
                model: [
                    {
                        icon: "previous",
                        main: false,
                        run: () => root.player.previous()
                    },
                    {
                        icon: root.player && root.player.isPlaying ? "pause" : "play",
                        main: true,
                        run: () => root.player.togglePlaying()
                    },
                    {
                        icon: "next",
                        main: false,
                        run: () => root.player.next()
                    }
                ]

                delegate: Rectangle {
                    id: control

                    required property var modelData

                    width: modelData.main ? 38 : 32
                    height: width
                    anchors.verticalCenter: parent.verticalCenter
                    radius: width / 2
                    color: modelData.main ? Theme.accent : Qt.alpha(Theme.text, controlArea.containsMouse ? 0.14 : 0.06)
                    scale: controlArea.pressed ? 0.9 : 1

                    Behavior on scale {
                        NumberAnimation {
                            duration: 110
                        }
                    }

                    Icon {
                        anchors.centerIn: parent
                        name: control.modelData.icon
                        size: control.modelData.main ? 16 : 14
                        color: control.modelData.main ? Theme.accentText : Theme.text
                    }
                    MouseArea {
                        id: controlArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: control.modelData.run()
                    }
                }
            }
        }
    }
}
