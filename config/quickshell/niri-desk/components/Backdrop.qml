import QtQuick
import QtQuick.Effects
import Quickshell
import qs.services

// Blurred picture behind the panel: the wallpaper, or the album art when one is given.
Item {
    id: root

    // 0 Today, 1 Music, 2 AI. Each page has its own scene over the wallpaper.
    property int page: 0
    property string art: ""
    property bool playing: false
    property real bottomRadius: 18
    property int fullWidth: 1160
    property int fullHeight: 580

    property int frontSlot: 0
    property string previousArt: ""
    property string shownArt: ""

    onArtChanged: {
        previousArt = shownArt;
        shownArt = art;
        frontSlot = 1 - frontSlot;
    }

    readonly property string wallpaper: "file://" + Quickshell.env("HOME") + "/.local/state/niri-desk/wallpaper"

    layer.enabled: true
    layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }

    Rectangle {
        id: mask

        anchors.fill: parent
        bottomLeftRadius: root.bottomRadius
        bottomRightRadius: root.bottomRadius
        visible: false
        layer.enabled: true
    }

    // One fixed size while the panel grows around it: nothing is painted or blurred again during the opening.
    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Settings.bottom ? parent.height - height : 0
        width: root.fullWidth
        height: root.fullHeight

        Image {
            id: wall

            anchors.fill: parent
            source: root.wallpaper
            cache: false
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 140
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: wall
            blurEnabled: true
            blur: 1
            blurMax: 64
            saturation: 0.25
        }
        // Darker for the wallpaper, lighter over a cover, which should stay visible.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.alpha(Theme.pill, 0.62)
                }
                GradientStop {
                    position: 1
                    color: Qt.alpha(Theme.pill, 0.86)
                }
            }
        }

        // Today: a dark room with a soft light where the time stands.
        Canvas {
            id: room

            anchors.fill: parent
            visible: opacity > 0
            opacity: root.page === 0 ? 1 : 0
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = Theme.pill;
                ctx.fillRect(0, 0, width, height);
                ctx.save();
                ctx.translate(width / 2, height * 0.4);
                ctx.scale(1, 0.57);
                const light = ctx.createRadialGradient(0, 0, 0, 0, 0, 700);
                light.addColorStop(0, Qt.tint(Theme.pill, Qt.alpha(Theme.accent, 0.17)));
                light.addColorStop(1, Qt.alpha(Theme.pill, 0));
                ctx.fillStyle = light;
                ctx.fillRect(-width, -height * 2, width * 2, height * 4);
                ctx.restore();
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 480
                }
            }
        }

        Aurora {
            anchors.fill: parent
            visible: opacity > 0
            opacity: root.page === 2 ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 480
                }
            }
        }

        // Two slots: a new cover fades in over the old one. Three turning copies make the colors flow.
        Repeater {
            model: 2

            delegate: Item {
                id: slot

                required property int index

                readonly property bool front: root.frontSlot === index
                readonly property string picture: front ? root.art : (root.previousArt || "")
                anchors.fill: parent
                visible: opacity > 0
                opacity: front && root.art !== "" && fieldA.ready ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 900
                        easing.type: Easing.InOutQuad
                    }
                }

                readonly property real side: Math.max(parent.width, parent.height) * 1.5

                ArtField {
                    id: fieldA

                    anchors.centerIn: parent
                    width: slot.side
                    height: slot.side
                    source: slot.picture
                    turnSeconds: 70
                    turning: root.playing
                }
                ArtField {
                    x: -slot.side * 0.3
                    y: -slot.side * 0.35
                    width: slot.side
                    height: slot.side
                    source: slot.picture
                    opacity: 0.65
                    turnSeconds: 110
                    reverse: true
                    turning: root.playing
                }
                ArtField {
                    x: parent.width - slot.side * 0.7
                    y: parent.height - slot.side * 0.65
                    width: slot.side
                    height: slot.side
                    source: slot.picture
                    opacity: 0.5
                    turnSeconds: 90
                    turning: root.playing
                }
                // Keeps the words readable on a bright cover without hiding it.
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: Qt.alpha(Theme.pill, 0.42)
                        }
                        GradientStop {
                            position: 0.55
                            color: Qt.alpha(Theme.pill, 0.34)
                        }
                        GradientStop {
                            position: 1
                            color: Qt.alpha(Theme.pill, 0.68)
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: Theme
        function onAccentChanged() {
            room.requestPaint();
            wall.source = "";
            wall.source = root.wallpaper;
        }
    }
}
