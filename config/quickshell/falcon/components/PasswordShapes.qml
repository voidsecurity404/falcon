import QtQuick
import qs.services

// Hidden password characters shown as Material shapes, one per character, each popping in
// with a turn. Centered, and once the row is too long the newest shapes stay in view while
// those pushed past the left edge fade.
Item {
    id: root

    property int count: 0
    property color color: Theme.accent
    property bool dim: false
    property int shapeSize: 16

    clip: true

    Row {
        id: shapes

        x: Math.min((root.width - width) / 2, root.width - width)
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        opacity: root.dim ? 0.45 : 1

        Behavior on x {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }
        }

        Repeater {
            model: root.count

            delegate: MaterialShape {
                required property int index

                width: root.shapeSize
                height: root.shapeSize
                kind: kinds[index % kinds.length]
                color: root.color
                opacity: x + shapes.x < 0 ? 0 : 1
                scale: 0
                rotation: -50
                Component.onCompleted: {
                    scale = 1;
                    rotation = 0;
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: 260
                        easing.type: Easing.OutBack
                        easing.overshoot: 2.4
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: 160
                    }
                }
                Behavior on rotation {
                    NumberAnimation {
                        duration: 320
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }
}
