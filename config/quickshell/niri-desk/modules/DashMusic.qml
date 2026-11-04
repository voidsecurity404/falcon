import QtQuick
import Quickshell.Widgets
import qs.components
import qs.services

// Musiqa: pleer va eshitib yozilgan jonli subtitr.
Item {
    id: root

    readonly property var player: Media.player

    function clock(seconds) {
        const s = Math.max(0, Math.floor(seconds || 0));
        return Math.floor(s / 60) + ":" + Ui.pad(s % 60);
    }

    ListModel {
        id: lines
    }

    Connections {
        target: Lyrics
        function onLineAdded(text) {
            lines.append({
                words: text
            });
            if (lines.count > 6)
                lines.remove(0);
        }
        function onCleared() {
            lines.clear();
        }
    }

    // Pleer
    Column {
        id: deck

        width: 290
        anchors.verticalCenter: parent.verticalCenter
        spacing: 14

        ClippingRectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 200
            height: 200
            radius: 18
            color: Qt.alpha(Theme.text, 0.08)
            scale: root.player && root.player.isPlaying ? 1 : 0.94

            Behavior on scale {
                NumberAnimation {
                    duration: 520
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.3, 1.35, 0.4, 1, 1, 1]
                }
            }

            Icon {
                anchors.centerIn: parent
                name: "music"
                size: 44
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
            width: parent.width
            spacing: 2

            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: root.player ? root.player.trackTitle : Tr.t("No music")
                size: 15
                font.weight: Font.Medium
            }
            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: root.player ? root.player.trackArtist : Tr.t("Nothing is playing")
                color: Theme.muted
                size: 13
            }
        }

        Column {
            width: parent.width
            spacing: 4
            visible: !!root.player

            Rectangle {
                width: parent.width
                height: 4
                radius: 2
                color: Qt.alpha(Theme.text, 0.14)

                Rectangle {
                    width: Math.max(height, parent.width * Math.max(0, Math.min(1, Media.progress)))
                    height: parent.height
                    radius: 2
                    color: Theme.accent

                    Behavior on width {
                        NumberAnimation {
                            duration: 900
                        }
                    }
                }
            }
            Item {
                width: parent.width
                height: 14

                Label {
                    text: root.player ? root.clock(root.player.position) : ""
                    color: Theme.muted
                    size: 11
                }
                Label {
                    anchors.right: parent.right
                    text: root.player && root.player.lengthSupported ? root.clock(root.player.length) : ""
                    color: Theme.muted
                    size: 11
                }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 14
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

                    anchors.verticalCenter: parent.verticalCenter
                    width: modelData.main ? 48 : 38
                    height: width
                    radius: modelData.main ? (controlArea.containsMouse ? 16 : 24) : 19
                    color: modelData.main ? Theme.accent : Qt.alpha(Theme.text, controlArea.containsMouse ? 0.14 : 0.06)
                    scale: controlArea.pressed ? 0.9 : 1

                    Behavior on radius {
                        NumberAnimation {
                            duration: 240
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: 120
                        }
                    }

                    Icon {
                        anchors.centerIn: parent
                        name: control.modelData.icon
                        size: control.modelData.main ? 20 : 16
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

    // Subtitr
    Item {
        x: deck.width + 36
        width: parent.width - x
        height: parent.height
        clip: true

        Label {
            id: note

            anchors.left: parent.left
            anchors.bottom: parent.bottom
            width: parent.width
            text: Tr.t("Recognized on this computer, the audio is not sent anywhere")
            color: Qt.alpha(Theme.text, 0.4)
            size: 11
        }

        Label {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: lines.count === 0 && Lyrics.partial === ""
            horizontalAlignment: Text.AlignLeft
            wrapMode: Text.Wrap
            elide: Text.ElideNone
            size: 22
            font.weight: Font.Light
            color: Theme.muted
            text: {
                if (!root.player || !root.player.isPlaying)
                    return Tr.t("Turn on some music, the words will appear here");
                if (Lyrics.status === "missing")
                    return Tr.t("Speech recognition is not installed. Run install.sh again");
                if (Lyrics.status === "error")
                    return Tr.t("Could not load the speech model") + ": " + Lyrics.message;
                if (Lyrics.status === "loading")
                    return Tr.t("Preparing recognition…");
                return Tr.t("Listening…");
            }
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: note.top
            anchors.bottomMargin: 18
            spacing: 12

            move: Transition {
                NumberAnimation {
                    property: "y"
                    duration: 380
                    easing.type: Easing.OutCubic
                }
            }

            Repeater {
                model: lines

                delegate: Label {
                    required property string words
                    required property int index

                    readonly property int age: lines.count - 1 - index
                    property real appear: 0

                    Component.onCompleted: appear = 1

                    Behavior on appear {
                        NumberAnimation {
                            duration: 320
                        }
                    }

                    text: words
                    width: parent.width
                    wrapMode: Text.Wrap
                    elide: Text.ElideNone
                    size: 19
                    font.weight: Font.Light
                    opacity: appear * Math.max(0.12, 0.72 - age * 0.14)
                }
            }
            Label {
                width: parent.width
                visible: Lyrics.partial !== ""
                text: Lyrics.partial
                wrapMode: Text.Wrap
                elide: Text.ElideNone
                size: 27
                color: Theme.text
                font.weight: Font.Medium
            }
        }
    }
}
