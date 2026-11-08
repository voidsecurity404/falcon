import QtQuick
import Quickshell.Widgets
import qs.components
import qs.services

// The cover on a record that spins while music plays. Forms: wide, tall.
Item {
    id: root

    property string form: "wide"
    readonly property bool tall: form === "tall"
    readonly property var player: Media.player
    readonly property bool playing: !!player && player.isPlaying

    component Button: Rectangle {
        id: button

        property string icon: ""
        property bool main: false
        signal pressed

        width: main ? 42 : 34
        height: width
        radius: width / 2
        color: main ? Theme.accent : Qt.alpha(Theme.text, area.containsMouse ? 0.16 : 0.07)
        scale: area.pressed ? 0.9 : 1

        Behavior on scale {
            NumberAnimation {
                duration: 110
            }
        }

        Icon {
            anchors.centerIn: parent
            name: button.icon
            size: button.main ? 17 : 14
            color: button.main ? Theme.accentText : Theme.text
        }
        MouseArea {
            id: area

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.pressed()
        }
    }

    Item {
        id: deck

        readonly property real side: root.tall ? root.width - 44 : root.height - 28

        x: root.tall ? 22 : 14
        y: 14
        width: side
        height: side

        Item {
            id: disc

            anchors.fill: parent

            Canvas {
                anchors.fill: parent
                renderStrategy: Canvas.Cooperative
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const c = width / 2;
                    ctx.beginPath();
                    ctx.arc(c, c, c, 0, Math.PI * 2);
                    ctx.fillStyle = "#0c0c0f";
                    ctx.fill();
                    ctx.lineWidth = 1;
                    for (let r = c * 0.42; r < c - 2; r += 3.4) {
                        ctx.beginPath();
                        ctx.arc(c, c, r, 0, Math.PI * 2);
                        ctx.strokeStyle = "rgba(255, 255, 255, " + (Math.floor(r) % 3 === 0 ? 0.07 : 0.035) + ")";
                        ctx.stroke();
                    }
                    // The shine stays on two opposite sides of the grooves.
                    for (const a of [-0.8, 2.34]) {
                        ctx.beginPath();
                        ctx.moveTo(c, c);
                        ctx.arc(c, c, c - 1, a - 0.26, a + 0.26);
                        ctx.closePath();
                        ctx.fillStyle = "rgba(255, 255, 255, 0.05)";
                        ctx.fill();
                    }
                }
            }
            ClippingRectangle {
                anchors.centerIn: parent
                width: parent.width * 0.46
                height: width
                radius: width / 2
                color: Theme.accent

                Image {
                    anchors.fill: parent
                    source: Media.art
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 240
                    sourceSize.height: 240
                }
            }
            Rectangle {
                anchors.centerIn: parent
                width: 10
                height: 10
                radius: 5
                color: Theme.pill
                border.width: 1
                border.color: Qt.alpha("#ffffff", 0.3)
            }

            // Taken from the clock, so the two copies of this widget never differ.
            FrameAnimation {
                running: root.playing && root.visible
                onTriggered: disc.rotation = (Date.now() % 7200) / 20
            }
        }
        // The tonearm comes onto the record while it plays.
        Rectangle {
            x: deck.side * 0.93
            y: deck.side * 0.04
            width: 4
            height: deck.side * 0.56
            radius: 2
            color: "#d9d7d0"
            transformOrigin: Item.Top
            rotation: root.playing ? 24 : 6

            Behavior on rotation {
                NumberAnimation {
                    duration: 600
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: -5
                width: 11
                height: 11
                radius: 5.5
                color: "#d9d7d0"
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                width: 8
                height: 14
                radius: 2
                color: Theme.accent
            }
        }
    }
    Column {
        x: root.tall ? 18 : deck.x + deck.width + 24
        y: root.tall ? deck.y + deck.height + 14 : (parent.height - height) / 2
        width: parent.width - x - 18
        spacing: 10

        Column {
            width: parent.width
            spacing: 2

            Label {
                width: parent.width
                horizontalAlignment: root.tall ? Text.AlignHCenter : Text.AlignLeft
                text: root.player ? Media.title : Tr.t("No music")
                size: 15
                font.weight: Font.DemiBold
            }
            Label {
                width: parent.width
                horizontalAlignment: root.tall ? Text.AlignHCenter : Text.AlignLeft
                text: root.player ? root.player.trackArtist : Tr.t("Nothing is playing")
                color: Theme.muted
                size: 12
            }
        }
        // A plain x, not an anchor: an anchor reset to undefined keeps its last place, so after the
        // form changed from tall to wide the buttons stayed centered and ran off the plate.
        Row {
            x: root.tall ? (parent.width - width) / 2 : 0
            spacing: 8
            visible: !!root.player

            Button {
                anchors.verticalCenter: parent.verticalCenter
                icon: "previous"
                onPressed: root.player.previous()
            }
            Button {
                anchors.verticalCenter: parent.verticalCenter
                main: true
                icon: root.playing ? "pause" : "play"
                onPressed: root.player.togglePlaying()
            }
            Button {
                anchors.verticalCenter: parent.verticalCenter
                icon: "next"
                onPressed: root.player.next()
            }
        }
    }
}
