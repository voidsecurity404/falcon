import QtQuick
import qs.services

// Soft colored lights drifting behind the AI chat. Each one is painted once and then only moved.
Item {
    id: root

    property bool moving: visible

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Qt.tint(Theme.pill, "#100b2e"), 0.25)
    }

    Blob {
        x: -130
        y: -150
        width: 680
        height: 560
        shade: "#2e7cf6"
        seconds: 16
    }
    Blob {
        x: parent.width - 580
        y: -100
        width: 680
        height: 580
        shade: "#c23cf0"
        seconds: 19
    }
    Blob {
        x: 300
        y: parent.height - 170
        width: 760
        height: 460
        shade: "#10d6b8"
        seconds: 23
    }

    component Blob: Canvas {
        id: blob

        property color shade
        property int seconds: 16

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.save();
            ctx.translate(width / 2, height / 2);
            ctx.scale(1, height / width);
            const glow = ctx.createRadialGradient(0, 0, 0, 0, 0, width / 2);
            glow.addColorStop(0, shade);
            glow.addColorStop(0.45, Qt.alpha(shade, 0.8));
            glow.addColorStop(1, Qt.alpha(shade, 0));
            ctx.fillStyle = glow;
            ctx.beginPath();
            ctx.arc(0, 0, width / 2, 0, 6.283, false);
            ctx.fill();
            ctx.restore();
        }

        transform: Translate {
            id: drift
        }

        SequentialAnimation {
            running: root.moving
            loops: Animation.Infinite

            ParallelAnimation {
                NumberAnimation {
                    target: drift
                    property: "x"
                    to: 70
                    duration: blob.seconds * 1000
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    target: drift
                    property: "y"
                    to: 50
                    duration: blob.seconds * 1000
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    target: blob
                    property: "scale"
                    to: 1.2
                    duration: blob.seconds * 1000
                    easing.type: Easing.InOutSine
                }
            }
            ParallelAnimation {
                NumberAnimation {
                    target: drift
                    property: "x"
                    to: 0
                    duration: blob.seconds * 1000
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    target: drift
                    property: "y"
                    to: 0
                    duration: blob.seconds * 1000
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    target: blob
                    property: "scale"
                    to: 1
                    duration: blob.seconds * 1000
                    easing.type: Easing.InOutSine
                }
            }
        }
    }
}
