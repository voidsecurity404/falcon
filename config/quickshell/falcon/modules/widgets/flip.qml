import QtQuick
import Quickshell
import qs.components
import qs.services

// Two cards that turn over when their number changes. Forms: wide, small.
Item {
    id: root

    property string form: "wide"
    readonly property int digits: form === "small" ? 66 : 96

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    component Half: Item {
        id: half

        property bool upper: true
        property string text: ""

        width: parent.width
        height: parent.height / 2
        clip: true

        Rectangle {
            y: half.upper ? 0 : -half.height
            width: half.width
            height: half.height * 2
            radius: 20
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.tint(Theme.pill, Qt.alpha(Theme.accent, 0.2))
                }
                GradientStop {
                    position: 1
                    color: Qt.tint(Theme.pill, Qt.alpha(Theme.accent, 0.08))
                }
            }

            Label {
                anchors.centerIn: parent
                text: half.text
                size: root.digits
                font.family: Theme.display
                font.weight: Font.Bold
            }
        }
    }

    component Card: Item {
        id: card

        property string value: ""
        property string shown: ""
        property string previous: ""
        property real angle: 0

        Component.onCompleted: {
            shown = value;
            previous = value;
        }
        onValueChanged: {
            if (shown === "" || value === shown)
                return;
            previous = shown;
            shown = value;
            turn.restart();
        }

        SequentialAnimation {
            id: turn

            NumberAnimation {
                target: card
                property: "angle"
                from: 0
                to: 180
                duration: 620
                easing.type: Easing.InOutCubic
            }
            ScriptAction {
                script: {
                    card.previous = card.shown;
                    card.angle = 0;
                }
            }
        }

        Half {
            text: card.shown
        }
        Half {
            y: parent.height / 2
            upper: false
            text: card.previous
        }
        Half {
            visible: card.angle < 90
            text: card.previous
            transform: Rotation {
                origin.y: card.height / 2
                axis.x: 1
                axis.y: 0
                axis.z: 0
                angle: card.angle
            }
        }
        Half {
            y: parent.height / 2
            visible: card.angle >= 90
            upper: false
            text: card.shown
            transform: Rotation {
                origin.y: 0
                axis.x: 1
                axis.y: 0
                axis.z: 0
                angle: card.angle - 180
            }
        }
        Rectangle {
            y: parent.height / 2 - 1
            width: parent.width
            height: 2
            color: Qt.alpha("#000000", 0.55)
        }
    }

    Row {
        anchors.fill: parent
        spacing: 10

        Card {
            width: (parent.width - 10) / 2
            height: parent.height
            value: Ui.pad(clock.hours)
        }
        Card {
            width: (parent.width - 10) / 2
            height: parent.height
            value: Ui.pad(clock.minutes)
        }
    }
}
