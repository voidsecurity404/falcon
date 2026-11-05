import QtQuick
import Quickshell.Widgets
import qs.components
import qs.services

// Forms: wide, tall (cover on top), compact (small cover and one button).
Item {
    id: root

    property string form: "wide"
    readonly property var player: Media.player
    readonly property bool tall: form === "tall"
    readonly property bool compact: form === "compact"

    component ControlButton: Rectangle {
        id: control

        property string icon: ""
        property bool main: false
        signal pressed

        width: main ? 38 : 32
        height: width
        radius: width / 2
        color: main ? Theme.accent : Qt.alpha(Theme.text, controlArea.containsMouse ? 0.14 : 0.06)
        scale: controlArea.pressed ? 0.9 : 1

        Behavior on scale {
            NumberAnimation {
                duration: 110
            }
        }

        Icon {
            anchors.centerIn: parent
            name: control.icon
            size: control.main ? 16 : 14
            color: control.main ? Theme.accentText : Theme.text
        }
        MouseArea {
            id: controlArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: control.pressed()
        }
    }

    ClippingRectangle {
        id: art

        x: root.compact ? 12 : 16
        y: root.tall ? 16 : (parent.height - height) / 2
        width: root.tall ? parent.width - 32 : root.compact ? 60 : 118
        height: width
        radius: root.compact ? 10 : 14
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
            sourceSize.width: 400
            sourceSize.height: 400
        }
    }
    Column {
        x: root.tall ? 16 : art.x + art.width + (root.compact ? 12 : 14)
        y: root.tall ? art.y + art.height + 14 : (parent.height - height) / 2
        width: root.tall ? parent.width - 32 : parent.width - x - (root.compact && root.player ? 62 : 16)
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
            visible: !!root.player && !root.compact
            color: Qt.alpha(Theme.text, 0.14)

            Rectangle {
                width: Math.max(height, parent.width * Math.max(0, Math.min(1, Media.progress)))
                height: parent.height
                radius: 2
                color: Theme.accent
            }
        }
        Row {
            anchors.horizontalCenter: root.tall ? parent.horizontalCenter : undefined
            spacing: 10
            visible: !!root.player && !root.compact

            ControlButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "previous"
                onPressed: root.player.previous()
            }
            ControlButton {
                anchors.verticalCenter: parent.verticalCenter
                main: true
                icon: root.player && root.player.isPlaying ? "pause" : "play"
                onPressed: root.player.togglePlaying()
            }
            ControlButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "next"
                onPressed: root.player.next()
            }
        }
    }
    ControlButton {
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        visible: !!root.player && root.compact
        main: true
        icon: root.player && root.player.isPlaying ? "pause" : "play"
        onPressed: root.player.togglePlaying()
    }
}
