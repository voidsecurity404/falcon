import QtQuick
import Quickshell.Widgets
import qs.services

Column {
    id: root

    property int artSize: 82
    property bool showControls: true

    readonly property var player: Media.player

    spacing: 12

    Row {
        width: parent.width
        spacing: 14

        ClippingRectangle {
            width: root.artSize
            height: root.artSize
            radius: 11
            color: Qt.alpha(Theme.accent, 0.22)

            Image {
                anchors.fill: parent
                source: root.player ? root.player.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 180
                sourceSize.height: 180
                asynchronous: true
            }

            Icon {
                anchors.centerIn: parent
                visible: !root.player || root.player.trackArtUrl === ""
                name: "play"
                size: 22
                color: Theme.accent
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - root.artSize - 14
            spacing: 3

            Label {
                width: parent.width
                text: root.player ? (root.player.trackTitle || root.player.identity) : Tr.t("No music")
                font.weight: Font.Medium
            }
            Label {
                width: parent.width
                text: root.player ? root.player.trackArtist : Tr.t("Nothing is playing")
                color: Theme.muted
                size: 13
            }
        }
    }

    Rectangle {
        visible: !!root.player
        width: parent.width
        height: 3
        radius: 2
        color: Qt.alpha(Theme.text, 0.14)

        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, Media.progress))
            height: parent.height
            radius: 2
            color: Theme.accent
        }
    }

    Row {
        visible: root.showControls && !!root.player
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 22

        Repeater {
            model: [
                {
                    icon: "previous",
                    run: () => root.player.previous()
                },
                {
                    icon: root.player && root.player.isPlaying ? "pause" : "play",
                    run: () => root.player.togglePlaying()
                },
                {
                    icon: "next",
                    run: () => root.player.next()
                }
            ]

            delegate: Item {
                required property var modelData

                width: 22
                height: 22

                Icon {
                    anchors.centerIn: parent
                    name: parent.modelData.icon
                    size: 18
                    opacity: controlArea.containsMouse ? 1 : 0.8
                }

                MouseArea {
                    id: controlArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: parent.modelData.run()
                }
            }
        }
    }
}
