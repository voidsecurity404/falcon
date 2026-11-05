import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.components
import qs.services

// Musiqa: muqova va undan chiqib turadigan aylanuvchi plastinka, nom, vaqt chizig'i, boshqaruv.
Item {
    id: root

    readonly property var player: Media.player
    readonly property bool playing: !!player && player.isPlaying
    readonly property color tint: Media.artAccent
    readonly property int coverSize: Math.max(100, Math.min(height - 40, 370))
    property real dragShare: -1

    function clock(seconds) {
        const s = Math.max(0, Math.floor(seconds || 0));
        return Math.floor(s / 60) + ":" + Ui.pad(s % 60);
    }

    // Muqova va plastinka
    Item {
        id: deck

        anchors.verticalCenter: parent.verticalCenter
        x: 8
        width: root.coverSize + root.coverSize * 0.32
        height: root.coverSize

        Item {
            id: disc

            x: root.playing ? root.coverSize * 0.3 : root.coverSize * 0.06
            anchors.verticalCenter: parent.verticalCenter
            width: root.coverSize * 0.96
            height: width
            visible: !!root.player

            Behavior on x {
                NumberAnimation {
                    duration: 800
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.25, 1.15, 0.35, 1, 1, 1]
                }
            }

            Item {
                anchors.fill: parent

                RotationAnimator on rotation {
                    running: root.playing && root.visible
                    from: 0
                    to: 360
                    duration: 5000
                    loops: Animation.Infinite
                }

                Canvas {
                    anchors.fill: parent
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        const c = width / 2;
                        ctx.beginPath();
                        ctx.arc(c, c, c, 0, Math.PI * 2);
                        ctx.fillStyle = "#0b0c0f";
                        ctx.fill();
                        // Grooves
                        for (let r = c * 0.4; r < c - 3; r += 3) {
                            ctx.beginPath();
                            ctx.arc(c, c, r, 0, Math.PI * 2);
                            ctx.lineWidth = 1;
                            ctx.strokeStyle = Math.round(r) % 2 ? "rgba(255,255,255,0.045)" : "rgba(0,0,0,0.5)";
                            ctx.stroke();
                        }
                    }
                }
                ClippingRectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.38
                    height: width
                    radius: width / 2
                    color: root.tint

                    Image {
                        anchors.fill: parent
                        source: Media.art
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 256
                        sourceSize.height: 256
                        asynchronous: true
                    }
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 12
                    height: 12
                    radius: 6
                    color: "#0b0c0f"
                    border.width: 1
                    border.color: Qt.alpha("#ffffff", 0.3)
                }
            }

            // Light on the vinyl stays still while the record turns under it.
            Canvas {
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const c = width / 2;
                    const shine = ctx.createConicalGradient(c, c, Math.PI / 4);
                    for (const [at, alpha] of [[0, 0], [0.08, 0.16], [0.16, 0], [0.5, 0], [0.58, 0.11], [0.66, 0], [1, 0]])
                        shine.addColorStop(at, "rgba(255,255,255," + alpha + ")");
                    ctx.beginPath();
                    ctx.arc(c, c, c, 0, Math.PI * 2);
                    ctx.arc(c, c, c * 0.39, 0, Math.PI * 2, true);
                    ctx.fillStyle = shine;
                    ctx.fill();
                }
            }
        }

        Item {
            id: coverBox

            width: root.coverSize
            height: root.coverSize
            scale: root.playing || !root.player ? 1 : 0.95

            Behavior on scale {
                NumberAnimation {
                    duration: 600
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.3, 1.35, 0.4, 1, 1, 1]
                }
            }

            // The shadow takes the color of the cover.
            RectangularShadow {
                anchors.fill: parent
                offset.y: 14
                radius: 20
                blur: 46
                spread: 2
                color: Qt.alpha(Qt.darker(root.tint, 1.7), 0.85)
            }
            ClippingRectangle {
                anchors.fill: parent
                radius: 20
                color: Qt.alpha(Theme.text, 0.08)
                border.width: 1
                border.color: Qt.alpha(Theme.text, 0.14)

                Icon {
                    anchors.centerIn: parent
                    name: "music"
                    size: 64
                    color: Theme.muted
                }
                Image {
                    anchors.fill: parent
                    source: Media.art
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 800
                    sourceSize.height: 800
                    asynchronous: true
                }
            }
        }
    }

    // Nom, vaqt va boshqaruv
    Column {
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        width: parent.width - deck.x - deck.width - 44
        spacing: 26

        Column {
            width: parent.width
            spacing: 8

            Label {
                visible: !!root.player
                text: root.player ? root.player.identity.toUpperCase() : ""
                size: 12
                font.letterSpacing: 2.5
                font.weight: Font.Medium
                color: root.tint
            }
            Label {
                width: parent.width
                text: root.player ? Media.title : Tr.t("No music")
                size: 38
                font.weight: Font.DemiBold
                font.letterSpacing: -0.6
                wrapMode: Text.Wrap
                maximumLineCount: 2
                lineHeight: 1.05
            }
            Label {
                width: parent.width
                text: root.player ? root.player.trackArtist : Tr.t("Nothing is playing")
                size: 18
                color: Theme.muted
            }
        }

        // Vaqt chizig'i: bosib yoki surib o'tkazsa bo'ladi.
        Column {
            width: parent.width
            spacing: 8
            visible: !!root.player

            Item {
                id: seek

                readonly property bool enabledSeek: !!root.player && root.player.canSeek && root.player.lengthSupported && root.player.length > 0
                readonly property real share: root.dragShare >= 0 ? root.dragShare : Math.max(0, Math.min(1, Media.progress))

                width: parent.width
                height: 18

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: seekArea.containsMouse || seekArea.pressed ? 8 : 5
                    radius: height / 2
                    color: Qt.alpha(Theme.text, 0.18)

                    Behavior on height {
                        NumberAnimation {
                            duration: 140
                        }
                    }

                    Rectangle {
                        width: Math.max(parent.height, parent.width * seek.share)
                        height: parent.height
                        radius: height / 2
                        color: root.tint

                        Behavior on width {
                            enabled: !seekArea.pressed
                            NumberAnimation {
                                duration: 900
                            }
                        }
                    }
                }
                Rectangle {
                    x: seek.width * seek.share - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    height: 16
                    radius: 8
                    color: Theme.text
                    opacity: seekArea.containsMouse || seekArea.pressed ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 140
                        }
                    }
                }
                MouseArea {
                    id: seekArea

                    function shareAt(x) {
                        return Math.max(0, Math.min(1, x / width));
                    }

                    anchors.fill: parent
                    enabled: seek.enabledSeek
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
                height: 16

                Label {
                    text: root.player ? root.clock(root.dragShare >= 0 ? root.dragShare * root.player.length : root.player.position) : ""
                    color: Theme.muted
                    size: 12
                }
                Label {
                    anchors.right: parent.right
                    text: root.player && root.player.lengthSupported ? root.clock(root.player.length) : ""
                    color: Theme.muted
                    size: 12
                }
            }
        }

        Row {
            spacing: 18
            visible: !!root.player

            Repeater {
                model: [
                    {
                        icon: "previous",
                        main: false,
                        run: () => root.player.previous()
                    },
                    {
                        icon: root.playing ? "pause" : "play",
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
                    width: modelData.main ? 68 : 50
                    height: width
                    radius: modelData.main ? (controlArea.containsMouse ? 22 : 34) : 25
                    color: modelData.main ? root.tint : Qt.alpha(Theme.text, controlArea.containsMouse ? 0.18 : 0.08)
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
                        size: control.modelData.main ? 26 : 19
                        color: control.modelData.main ? Media.artAccentText : Theme.text
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
