import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.components
import qs.services

// What is playing: the cover over its own blurred light, the seek bar and the controls.
// Forms: wide, square.
Item {
    id: root

    readonly property bool widgetRoot: true
    property string widgetId: ""
    property string form: "wide"
    readonly property bool square: form === "square"
    readonly property var player: Media.player
    readonly property bool playing: !!player && player.isPlaying
    readonly property bool hasLength: !!player && player.lengthSupported && player.length > 0
    readonly property real share: hasLength ? Math.min(1, player.position / player.length) : 0
    readonly property color tint: Media.art !== "" ? Media.artAccent : Theme.accent

    function clock(seconds) {
        const s = Math.max(0, Math.floor(seconds));
        return Math.floor(s / 60) + ":" + (s % 60 < 10 ? "0" : "") + s % 60;
    }

    // The cover's light behind everything.
    ClippingRectangle {
        anchors.fill: parent
        radius: 22
        color: "transparent"

        Image {
            id: glow

            anchors.fill: parent
            anchors.margins: -40
            source: Media.art
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 96
            asynchronous: true
            visible: false
        }
        MultiEffect {
            anchors.fill: glow
            source: glow
            blurEnabled: true
            blur: 1
            blurMax: 64
            saturation: 0.3
            opacity: Media.art !== "" ? 0.55 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 500
                }
            }
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: root.square ? Gradient.Vertical : Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: Qt.alpha(Theme.pill, 0.05)
                }
                GradientStop {
                    position: 1
                    color: Qt.alpha(Theme.pill, 0.45)
                }
            }
        }
    }

    Column {
        anchors.centerIn: parent
        visible: !root.player
        spacing: 10

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 64
            height: 64
            radius: 32
            color: Qt.alpha(Theme.accent, 0.16)

            Icon {
                anchors.centerIn: parent
                name: "music"
                size: 28
                color: Theme.accent
            }
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Tr.t("Nothing is playing")
            size: 15
            font.weight: Font.DemiBold
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Tr.t("Start music or a video and it shows here")
            size: 12
            color: Theme.muted
        }
    }

    // Cover
    Item {
        id: cover

        visible: !!root.player
        readonly property real side: root.square ? 176 : root.height - 40

        x: root.square ? (root.width - side) / 2 : 20
        y: 20
        width: side
        height: side

        RectangularShadow {
            anchors.fill: parent
            radius: 18
            blur: 26
            spread: 0
            offset.y: 8
            color: Qt.alpha("#000000", 0.45)
        }
        ClippingRectangle {
            anchors.fill: parent
            radius: 18
            color: Qt.alpha(root.tint, 0.25)

            Icon {
                anchors.centerIn: parent
                visible: Media.art === ""
                name: "music"
                size: parent.width * 0.36
                color: Qt.alpha(Theme.text, 0.5)
            }
            Image {
                anchors.fill: parent
                source: Media.art
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 360
                asynchronous: true
                scale: root.playing ? 1 : 0.96
                opacity: status === Image.Ready ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 300
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 500
                        easing.type: Easing.OutBack
                    }
                }
            }
        }
        // Small bars that move while music plays.
        Row {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 10
            spacing: 3
            visible: root.playing

            Repeater {
                model: 4

                Rectangle {
                    required property int index

                    anchors.bottom: parent.bottom
                    width: 4
                    height: 6
                    radius: 2
                    color: "white"
                    opacity: 0.9

                    SequentialAnimation on height {
                        running: root.playing
                        loops: Animation.Infinite

                        NumberAnimation {
                            to: 8 + (index * 7) % 13
                            duration: 260 + index * 90
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            to: 4
                            duration: 300 + index * 70
                            easing.type: Easing.InOutSine
                        }
                    }
                }
            }
        }
    }

    Item {
        id: info

        visible: !!root.player
        x: root.square ? 22 : cover.x + cover.width + 20
        y: root.square ? cover.y + cover.height + 16 : 20
        width: root.width - x - 22
        height: root.height - y - 18

        Row {
            id: source

            visible: !root.square
            spacing: 6

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "music"
                size: 12
                color: root.tint
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: root.player ? root.player.identity : ""
                size: 11
                font.weight: Font.DemiBold
                font.letterSpacing: 0.6
                font.capitalization: Font.AllUppercase
                color: Theme.muted
            }
        }
        Label {
            id: title

            y: root.square ? 0 : 22
            width: parent.width
            text: Media.title || Tr.t("Unknown track")
            size: root.square ? 17 : 18
            font.weight: Font.Bold
            horizontalAlignment: root.square ? Text.AlignHCenter : Text.AlignLeft
            maximumLineCount: root.square ? 1 : 2
            wrapMode: Text.Wrap
        }
        Label {
            y: title.y + title.height + 2
            width: parent.width
            text: root.player ? (root.player.trackArtist || root.player.trackAlbum || "") : ""
            size: 13
            color: Theme.muted
            horizontalAlignment: root.square ? Text.AlignHCenter : Text.AlignLeft
        }

        // Seek bar
        Item {
            id: seek

            y: parent.height - 76
            width: parent.width
            height: 30
            visible: root.hasLength

            Item {
                id: bar

                y: 4
                width: parent.width
                height: 14

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: seekHot.hovered ? 7 : 5
                    radius: height / 2
                    color: Qt.alpha(Theme.text, 0.16)

                    Behavior on height {
                        NumberAnimation {
                            duration: 120
                        }
                    }

                    Rectangle {
                        width: Math.max(parent.height, parent.width * root.share)
                        height: parent.height
                        radius: height / 2
                        color: root.tint
                    }
                }
                Rectangle {
                    x: parent.width * root.share - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: seekHot.hovered || seekHot.down ? 14 : 0
                    height: width
                    radius: width / 2
                    color: "white"

                    Behavior on width {
                        NumberAnimation {
                            duration: 120
                        }
                    }
                }
                WidgetHot {
                    id: seekHot

                    anchors.fill: parent
                    anchors.topMargin: -6
                    anchors.bottomMargin: -6
                    slider: true
                    onSlid: share => {
                        if (root.player && root.player.canSeek)
                            root.player.position = share * root.player.length;
                    }
                }
            }
            Label {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                text: root.player ? root.clock(root.player.position) : ""
                size: 11
                color: Theme.muted
            }
            Label {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                text: root.player ? "-" + root.clock(root.player.length - root.player.position) : ""
                size: 11
                color: Theme.muted
            }
        }

        Row {
            anchors.bottom: parent.bottom
            x: root.square ? (parent.width - width) / 2 : -4
            spacing: 10

            WidgetButton {
                anchors.verticalCenter: parent.verticalCenter
                height: 38
                icon: "previous"
                visible: !!root.player && root.player.canGoPrevious
                onClicked: root.player.previous()
            }
            WidgetButton {
                anchors.verticalCenter: parent.verticalCenter
                height: 50
                main: true
                onColor: root.tint
                onText: Media.art !== "" ? Media.artAccentText : Theme.accentText
                icon: root.playing ? "pause" : "play"
                onClicked: root.player.togglePlaying()
            }
            WidgetButton {
                anchors.verticalCenter: parent.verticalCenter
                height: 38
                icon: "next"
                visible: !!root.player && root.player.canGoNext
                onClicked: root.player.next()
            }
        }
    }
}
