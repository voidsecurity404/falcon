import QtQuick
import qs.services

// A small drawn battery that fills with the charge, with a bolt while charging.
Item {
    id: root

    property real value: 0
    property bool charging: false
    property color color: Theme.text

    implicitWidth: 25
    implicitHeight: 12

    Rectangle {
        width: 22
        height: 12
        radius: 3.5
        color: "transparent"
        border.width: 1.6
        border.color: root.color

        Rectangle {
            x: 2.5
            y: 2.5
            width: Math.max(0, (parent.width - 5) * Math.max(0, Math.min(1, root.value)))
            height: parent.height - 5
            radius: 1.5
            color: root.color

            Behavior on width {
                NumberAnimation {
                    duration: 400
                }
            }
        }
    }
    Rectangle {
        x: 22.5
        y: 4
        width: 2
        height: 4
        radius: 1
        color: root.color
    }
    Icon {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: -1.5
        visible: root.charging
        name: "bolt"
        filled: true
        size: 10
        color: Theme.pill
    }
}
