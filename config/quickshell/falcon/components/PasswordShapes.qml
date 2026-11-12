import QtQuick
import qs.services

// Hidden password characters shown as Material shapes, one per character. The row stays
// centered, but its width follows the count through a spring, so on each key the shapes
// already there glide aside smoothly while the new one grows in at its own place; a removed
// one shrinks away before its slot goes. Once the row is too long the newest shapes stay in
// view and those pushed past the left edge fade.
Item {
    id: root

    property int count: 0
    property color color: Theme.accent
    property bool dim: false
    property int shapeSize: 16
    property int spacing: 7

    readonly property real stride: shapeSize + spacing
    // Slots kept for shapes still shrinking away after a removal.
    property int slots: 0
    // The count the row is laid out for, eased toward `count`.
    property real shown: 0

    readonly property real rowWidth: Math.max(0, shown * stride - spacing)
    readonly property real rowX: Math.min((width - rowWidth) / 2, width - rowWidth)

    clip: true

    // A Repeater with a number as its model rebuilds every delegate when the number
    // changes, which made all shapes pop in again on each key. A ListModel grown and
    // shrunk at its end keeps the shapes already there.
    onSlotsChanged: {
        while (cells.count < slots)
            cells.append({ n: cells.count });
        if (cells.count > slots)
            cells.remove(slots, cells.count - slots);
    }

    ListModel {
        id: cells
    }

    onCountChanged: {
        if (count >= slots)
            slots = count;
        else
            trim.restart();
        shown = count;
    }
    Component.onCompleted: {
        slots = count;
        shownAnimation.enabled = false;
        shown = count;
        shownAnimation.enabled = true;
    }

    Behavior on shown {
        id: shownAnimation

        SpringAnimation {
            spring: 5
            damping: 0.42
            mass: 1
            epsilon: 0.002
        }
    }

    Timer {
        id: trim

        interval: 260
        onTriggered: root.slots = root.count
    }

    Item {
        id: shapes

        anchors.fill: parent
        opacity: root.dim ? 0.45 : 1

        Behavior on opacity {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }

        Repeater {
            model: cells

            delegate: MaterialShape {
                id: shape

                required property int n
                readonly property bool alive: n < root.count
                readonly property real place: root.rowX + n * root.stride

                width: root.shapeSize
                height: root.shapeSize
                x: place
                y: (root.height - height) / 2
                kind: shape.kinds[n % shape.kinds.length]
                color: root.color
                transformOrigin: Item.Center
                scale: 0.2
                rotation: -70
                opacity: 0

                states: State {
                    name: "in"
                    when: shape.alive

                    PropertyChanges {
                        shape.scale: 1
                        shape.rotation: 0
                        shape.opacity: Math.max(0, Math.min(1, (shape.place + 2) / root.stride))
                    }
                }
                transitions: [
                    Transition {
                        to: "in"

                        NumberAnimation {
                            property: "scale"
                            duration: 340
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.3
                        }
                        NumberAnimation {
                            property: "rotation"
                            duration: 420
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            property: "opacity"
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                    },
                    Transition {
                        from: "in"

                        NumberAnimation {
                            properties: "scale,opacity"
                            duration: 200
                            easing.type: Easing.InCubic
                        }
                        NumberAnimation {
                            property: "rotation"
                            to: 60
                            duration: 220
                            easing.type: Easing.InCubic
                        }
                    }
                ]

                Behavior on color {
                    ColorAnimation {
                        duration: 200
                    }
                }
            }
        }
    }
}
