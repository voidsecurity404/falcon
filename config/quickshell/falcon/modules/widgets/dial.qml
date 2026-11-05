import QtQuick
import Quickshell
import qs.components
import qs.services

// A clock with hands and a second hand that ticks.
Item {
    id: root

    readonly property real cx: width / 2
    readonly property real cy: height / 2

    SystemClock {
        id: clock

        precision: SystemClock.Seconds
    }

    Repeater {
        model: 60

        delegate: Rectangle {
            required property int index
            readonly property bool major: index % 5 === 0

            x: root.cx - width / 2
            y: root.cy - 102
            width: major ? 3 : 1.5
            height: major ? 11 : 6
            radius: width / 2
            color: Qt.alpha(Theme.text, major ? 0.85 : 0.28)
            transform: Rotation {
                origin.x: width / 2
                origin.y: 102
                angle: index * 6
            }
        }
    }
    Repeater {
        model: [
            { n: "12", a: 0 },
            { n: "3", a: 90 },
            { n: "6", a: 180 },
            { n: "9", a: 270 }
        ]

        delegate: Label {
            required property var modelData

            x: root.cx + Math.sin(modelData.a * Math.PI / 180) * 72 - width / 2
            y: root.cy - Math.cos(modelData.a * Math.PI / 180) * 72 - height / 2
            text: modelData.n
            size: 15
            font.family: Theme.display
            font.weight: Font.Medium
        }
    }
    Label {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.cy + 26
        text: clock.date.getDate()
        color: Theme.accent
        size: 13
        font.weight: Font.DemiBold
    }

    Rectangle {
        x: root.cx - width / 2
        y: root.cy - height
        width: 7
        height: 56
        radius: 3.5
        color: Theme.text
        transformOrigin: Item.Bottom
        rotation: (clock.hours % 12 + clock.minutes / 60) * 30
    }
    Rectangle {
        x: root.cx - width / 2
        y: root.cy - height
        width: 5
        height: 84
        radius: 2.5
        color: Theme.text
        transformOrigin: Item.Bottom
        rotation: clock.minutes * 6 + clock.seconds * 0.1
    }
    Rectangle {
        property real turns: clock.seconds * 6

        x: root.cx - width / 2
        y: root.cy - 92
        width: 2
        height: 112
        radius: 1
        color: Theme.accent
        transform: Rotation {
            origin.x: 1
            origin.y: 92
            angle: secondAngle.value
        }

        // Past 59 it keeps going forward instead of running back around the dial.
        QtObject {
            id: secondAngle

            property real value: clock.seconds * 6

            Behavior on value {
                RotationAnimation {
                    duration: 220
                    direction: RotationAnimation.Clockwise
                    easing.type: Easing.OutBack
                    easing.overshoot: 2.2
                }
            }
        }
    }
    Rectangle {
        x: root.cx - 6
        y: root.cy - 6
        width: 12
        height: 12
        radius: 6
        color: Theme.accent
        border.width: 3
        border.color: Theme.pill
    }
}
