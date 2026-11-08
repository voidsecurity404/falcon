import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import qs.components
import qs.services

// An analog clock on a wavy Material "cookie" shape. Forms: cookie (12 soft waves
// and minute dots) and flower (8 deep waves and hour dots).
Item {
    id: root

    property string form: "cookie"
    readonly property bool flower: form === "flower"
    readonly property int waves: flower ? 8 : 12
    readonly property real depth: flower ? 0.085 : 0.045
    readonly property real cx: width / 2
    readonly property real cy: height / 2
    // Room is left at the edge for the shadow.
    readonly property real outer: Math.min(width, height) / 2 - 12
    readonly property real base: outer / (1 + depth)

    // A container in the accent's hue: deep in dark mode, pale in light mode.
    readonly property bool dark: Theme.surface.hslLightness < 0.5
    readonly property real hue: Theme.accent.hslHue < 0 ? 0.6 : Theme.accent.hslHue
    readonly property color fill: dark ? Qt.hsla(hue, 0.34, 0.26, 1) : Qt.hsla(hue, 0.55, 0.86, 1)
    readonly property color marks: Qt.alpha(Theme.text, 0.6)
    readonly property color hourColor: Theme.accent
    readonly property color minuteColor: Theme.text

    SystemClock {
        id: clock

        precision: SystemClock.Seconds
    }

    Item {
        id: cookie

        anchors.fill: parent
        visible: false
        layer.enabled: true

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: root.fill
                strokeColor: "transparent"

                PathPolyline {
                    path: {
                        const points = [];
                        const steps = 240;
                        for (let i = 0; i <= steps; i++) {
                            const a = i / steps * Math.PI * 2;
                            const r = root.base * (1 + root.depth * Math.cos(root.waves * a));
                            points.push(Qt.point(root.cx + Math.sin(a) * r, root.cy - Math.cos(a) * r));
                        }
                        return points;
                    }
                }
            }
        }
    }
    MultiEffect {
        anchors.fill: cookie
        source: cookie
        shadowEnabled: true
        shadowColor: Qt.alpha("#000000", 0.45)
        shadowBlur: 0.7
        shadowVerticalOffset: 3
        blurMax: 24
    }

    // Minute dots on the cookie, or one dot per hour on the flower.
    Repeater {
        model: root.flower ? 12 : 60

        delegate: Rectangle {
            required property int index
            readonly property bool major: root.flower || index % 5 === 0
            readonly property real angle: index / (root.flower ? 12 : 60) * Math.PI * 2
            readonly property real r: root.base * (root.flower ? 0.78 : 0.86)

            width: major ? 6 : 3
            height: width
            radius: width / 2
            x: root.cx + Math.sin(angle) * r - width / 2
            y: root.cy - Math.cos(angle) * r - height / 2
            color: major ? root.marks : Qt.alpha(Theme.text, 0.3)
        }
    }

    // The day of the month in a bubble at three o'clock.
    Rectangle {
        width: 36
        height: 36
        radius: 18
        x: root.cx + root.base * 0.42 - width / 2
        y: root.cy - height / 2
        color: Qt.alpha(Theme.pill, 0.35)

        Label {
            anchors.centerIn: parent
            text: clock.date.getDate()
            color: Theme.accent
            size: 14
            font.family: Theme.display
            font.weight: Font.Medium
        }
    }

    // Minute hand, under the hour hand.
    Rectangle {
        x: root.cx - width / 2
        y: root.cy - height + width / 2
        width: 12
        height: root.base * 0.8
        radius: width / 2
        color: root.minuteColor
        transform: Rotation {
            origin.x: 6
            origin.y: root.base * 0.8 - 6
            angle: clock.minutes * 6 + clock.seconds * 0.1
        }
    }
    Rectangle {
        x: root.cx - width / 2
        y: root.cy - height + width / 2
        width: 20
        height: root.base * 0.52
        radius: width / 2
        color: root.hourColor
        transform: Rotation {
            origin.x: 10
            origin.y: root.base * 0.52 - 10
            angle: (clock.hours % 12 + clock.minutes / 60) * 30
        }
    }
    Rectangle {
        x: root.cx - 4
        y: root.cy - 4
        width: 8
        height: 8
        radius: 4
        color: root.fill
    }

    // The second: a dot running around just inside the edge.
    Rectangle {
        id: second

        // On the flower it runs inside the valleys between the waves (1 - depth), past the hour dots.
        readonly property real r: root.base * (root.flower ? 0.86 : 0.72)

        width: 10
        height: 10
        radius: 5
        color: Theme.accent
        x: root.cx + Math.sin(turn.value * Math.PI / 180) * r - 5
        y: root.cy - Math.cos(turn.value * Math.PI / 180) * r - 5

        // Past 59 it keeps going forward instead of running back around the dial.
        QtObject {
            id: turn

            property real value: clock.seconds * 6

            Behavior on value {
                RotationAnimation {
                    duration: 260
                    direction: RotationAnimation.Clockwise
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
