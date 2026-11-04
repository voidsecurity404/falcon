import QtQuick
import qs.services

// Ingichka slider. value 0..1 oralig'ida, foydalanuvchi siljitganda moved(value) chiqadi.
Item {
    id: root

    property real value: 0
    property bool handle: false

    signal moved(real value)

    implicitHeight: 20

    function fromMouse(x) {
        root.moved(Math.max(0, Math.min(1, x / width)));
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: area.containsMouse || area.pressed ? 8 : 6
        radius: height / 2
        color: Qt.alpha(Theme.text, 0.12)

        Behavior on height {
            NumberAnimation {
                duration: 140
            }
        }

        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, root.value))
            height: parent.height
            radius: parent.radius
            color: Theme.accent

            Behavior on width {
                enabled: !area.pressed

                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    Rectangle {
        x: parent.width * Math.max(0, Math.min(1, root.value)) - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: 14
        height: 14
        radius: 7
        color: Theme.text
        opacity: handle || area.containsMouse || area.pressed ? 1 : 0
        scale: area.pressed ? 1.25 : handle || area.containsMouse ? 1 : 0.5

        Behavior on opacity {
            NumberAnimation {
                duration: 120
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 200
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.3, 1.5, 0.4, 1, 1, 1]
            }
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => root.fromMouse(mouse.x)
        onPositionChanged: mouse => {
            if (pressed)
                root.fromMouse(mouse.x);
        }
    }
}
