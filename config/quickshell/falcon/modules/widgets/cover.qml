import QtQuick
import Quickshell.Widgets
import qs.components
import qs.services

// The whole widget is the album cover, with the track over it. Forms: square, wide.
Item {
    id: root

    property string form: "square"
    readonly property var player: Media.player
    readonly property bool wide: form === "wide"

    ClippingRectangle {
        anchors.fill: parent
        radius: 22
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Theme.accent
                }
                GradientStop {
                    position: 1
                    color: Qt.darker(Theme.accent, 1.8)
                }
            }
        }

        Icon {
            anchors.centerIn: parent
            visible: Media.art === ""
            name: "music"
            size: root.wide ? 54 : 84
            color: Qt.alpha(Theme.accentText, 0.45)
        }
        Image {
            anchors.fill: parent
            source: Media.art
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 520
            sourceSize.height: 520
            asynchronous: true
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop {
                    position: root.wide ? 0 : 0.35
                    color: root.wide ? Qt.alpha("#000000", 0.3) : "transparent"
                }
                GradientStop {
                    position: 1
                    color: Qt.alpha("#000000", 0.8)
                }
            }
        }
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width * Math.max(0, Math.min(1, Media.progress))
            height: 4
            visible: !!root.player
            color: "white"
        }
    }
    Column {
        x: 18
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 18
        width: parent.width - x - 70
        spacing: 2

        Label {
            width: parent.width
            text: root.player ? Media.title : Tr.t("No music")
            color: "white"
            size: 16
            font.weight: Font.Bold
        }
        Label {
            width: parent.width
            text: root.player ? root.player.trackArtist : Tr.t("Nothing is playing")
            color: Qt.alpha("#ffffff", 0.78)
            size: 12
        }
    }
    Rectangle {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 14
        width: 44
        height: 44
        radius: 22
        visible: !!root.player
        color: Qt.alpha("#ffffff", toggle.containsMouse ? 1 : 0.9)
        scale: toggle.pressed ? 0.9 : 1

        Behavior on scale {
            NumberAnimation {
                duration: 110
            }
        }

        Icon {
            anchors.centerIn: parent
            name: root.player && root.player.isPlaying ? "pause" : "play"
            size: 18
            color: "#101014"
        }
        MouseArea {
            id: toggle

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.player.togglePlaying()
        }
    }
}
