import QtQuick
import Quickshell.Widgets
import qs.components
import qs.services

// The music's menu: cover, title, artist, a seek bar and the player controls.
Flyout {
    id: root

    readonly property var player: Media.player
    readonly property bool playing: !!player && player.isPlaying
    property real dragShare: -1

    function clock(seconds) {
        const s = Math.max(0, Math.floor(seconds || 0));
        return Math.floor(s / 60) + ":" + Ui.pad(s % 60);
    }

    panelWidth: 340

    Column {
        width: parent.width
        spacing: 12

        Row {
            width: parent.width
            spacing: 14

            ClippingRectangle {
                width: 72
                height: 72
                radius: 14
                color: Qt.alpha(Theme.accent, 0.25)

                Icon {
                    anchors.centerIn: parent
                    visible: cover.status !== Image.Ready
                    name: "music"
                    size: 28
                    color: Theme.accent
                }
                Image {
                    id: cover

                    anchors.fill: parent
                    source: Media.art
                    sourceSize: Qt.size(144, 144)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 86
                spacing: 4

                Label {
                    width: parent.width
                    text: root.player ? Media.title : Tr.t("Nothing is playing")
                    size: 15
                    font.weight: Font.DemiBold
                }
                Label {
                    width: parent.width
                    visible: !!root.player && root.player.trackArtist !== ""
                    text: root.player ? root.player.trackArtist : ""
                    size: 13
                    color: Theme.muted
                }
                Label {
                    width: parent.width
                    visible: !!root.player && root.player.identity !== ""
                    text: root.player ? root.player.identity : ""
                    size: 11
                    color: Qt.alpha(Theme.muted, 0.8)
                }
            }
        }

        // Seek bar: a click or a drag moves the song.
        Item {
            id: seek

            readonly property bool canSeek: !!root.player && root.player.canSeek && root.player.lengthSupported && root.player.length > 0
            readonly property real share: root.dragShare >= 0 ? root.dragShare : Media.progress

            objectName: "seek"
            width: parent.width
            height: 14
            visible: !!root.player

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 4
                radius: 2
                color: Qt.alpha(Theme.text, 0.14)

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, seek.share))
                    height: parent.height
                    radius: 2
                    color: Theme.accent
                }
            }
            Rectangle {
                x: seek.width * Math.max(0, Math.min(1, seek.share)) - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 12
                height: 12
                radius: 6
                color: Theme.text
                opacity: seekArea.containsMouse || seekArea.pressed ? 1 : 0
            }
            MouseArea {
                id: seekArea

                function shareAt(x) {
                    return Math.max(0, Math.min(1, x / width));
                }

                anchors.fill: parent
                enabled: seek.canSeek
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse => root.dragShare = shareAt(mouse.x)
                onPositionChanged: mouse => {
                    if (pressed)
                        root.dragShare = shareAt(mouse.x);
                }
                onReleased: mouse => {
                    root.player.position = shareAt(mouse.x) * root.player.length;
                    root.dragShare = -1;
                }
            }
        }
        Item {
            width: parent.width
            height: 14
            visible: !!root.player

            Label {
                text: root.player ? root.clock(root.dragShare >= 0 ? root.dragShare * root.player.length : root.player.position) : ""
                size: 11
                color: Theme.muted
            }
            Label {
                anchors.right: parent.right
                text: root.player && root.player.lengthSupported ? root.clock(root.player.length) : ""
                size: 11
                color: Theme.muted
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 22
            visible: !!root.player

            BarButton {
                objectName: "prev"
                anchors.verticalCenter: parent.verticalCenter
                icon: "previous"
                iconSize: 20
                implicitHeight: 40
                onClicked: root.player.previous()
            }
            Rectangle {
                objectName: "playBig"
                anchors.verticalCenter: parent.verticalCenter
                width: 48
                height: 48
                radius: 24
                color: bigArea.containsMouse ? Qt.lighter(Theme.accent, 1.1) : Theme.accent

                Icon {
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: root.playing ? 0 : 1.5
                    name: root.playing ? "pause" : "play"
                    filled: true
                    size: 20
                    color: Theme.accentText
                }
                MouseArea {
                    id: bigArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.player.canTogglePlaying)
                            root.player.togglePlaying();
                    }
                }
            }
            BarButton {
                objectName: "next"
                anchors.verticalCenter: parent.verticalCenter
                icon: "next"
                iconSize: 20
                implicitHeight: 40
                onClicked: root.player.next()
            }
        }
    }
}
