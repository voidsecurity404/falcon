import QtQuick
import qs.services

// A dial made of separate ticks, open at the bottom. Put its text inside as children.
Item {
    id: root

    property real share: 0
    property bool hot: false
    // Off sends the dial back to zero, so it sweeps up again when it next appears.
    property bool live: true
    property int ticks: 48
    property real tickLength: 18
    property real tickWidth: 4
    property real sweep: 270

    property real level: live ? Math.max(0, Math.min(1, share)) : 0

    // How many ticks are lit. The ticks read only this, so they change when a tick turns on or off,
    // not on every frame of the sweep.
    readonly property int lit: level > 0.002 ? Math.floor(level * (ticks - 1) + 1e-6) + 1 : 0
    readonly property color litColor: hot ? Theme.error : Theme.accent
    readonly property color offColor: Qt.alpha(Theme.text, 0.13)

    Behavior on level {
        NumberAnimation {
            duration: 650
            easing.type: Easing.OutCubic
        }
    }

    Repeater {
        model: root.ticks

        delegate: Rectangle {
            required property int index

            readonly property real at: index / (root.ticks - 1)
            readonly property bool on: index < root.lit

            x: (root.width - width) / 2
            width: root.tickWidth
            height: root.tickLength
            radius: width / 2
            antialiasing: true
            color: on ? root.litColor : root.offColor
            transform: Rotation {
                origin.x: root.tickWidth / 2
                origin.y: root.height / 2
                angle: (at - 0.5) * root.sweep
            }

            Behavior on color {
                ColorAnimation {
                    duration: 140
                }
            }
        }
    }
}
