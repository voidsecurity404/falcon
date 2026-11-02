import QtQuick
import qs.services

// Ingichka slider. value 0..1 oralig'ida, foydalanuvchi siljitganda moved(value) chiqadi.
Item {
    id: root

    property real value: 0

    signal moved(real value)

    implicitHeight: 20

    function fromMouse(x) {
        root.moved(Math.max(0, Math.min(1, x / width)));
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 4
        radius: 2
        color: Qt.alpha(Theme.text, 0.14)

        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, root.value))
            height: parent.height
            radius: 2
            color: Theme.accent
        }
    }

    Rectangle {
        x: parent.width * Math.max(0, Math.min(1, root.value)) - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: 13
        height: 13
        radius: 6.5
        color: Theme.text
        opacity: area.containsMouse || area.pressed ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 120
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
