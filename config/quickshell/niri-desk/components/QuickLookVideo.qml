import QtQuick
import QtMultimedia
import qs.components
import qs.services

// Plays a video or a sound inside Quick Look. Loaded by a Loader, so a missing multimedia
// module costs only this part: the poster stays on screen.
Item {
    id: root

    property string path: ""
    property bool active: false
    property bool showVideo: true

    function toggle() {
        if (player.playbackState === MediaPlayer.PlayingState)
            player.pause();
        else
            player.play();
    }

    MediaPlayer {
        id: player

        source: root.active && root.path !== "" ? "file://" + encodeURI(root.path).replace(/#/g, "%23").replace(/\?/g, "%3F") : ""
        audioOutput: AudioOutput {}
        videoOutput: output
        onSourceChanged: {
            if (source != "")
                play();
        }
    }
    VideoOutput {
        id: output

        anchors.fill: parent
        visible: root.showVideo && player.position > 0
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggle()
    }
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 14
        height: 40
        radius: 20
        color: Qt.alpha("black", 0.55)

        Icon {
            id: mark

            x: 14
            anchors.verticalCenter: parent.verticalCenter
            name: player.playbackState === MediaPlayer.PlayingState ? "pause" : "play"
            size: 16
            color: "white"
        }
        Rectangle {
            id: track

            anchors.left: mark.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            height: 4
            radius: 2
            color: Qt.alpha("white", 0.25)

            Rectangle {
                width: player.duration > 0 ? parent.width * player.position / player.duration : 0
                height: parent.height
                radius: 2
                color: "white"
            }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -12
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    if (player.seekable)
                        player.position = player.duration * Math.max(0, Math.min(1, (mouse.x - 12) / track.width));
                }
            }
        }
    }
}
