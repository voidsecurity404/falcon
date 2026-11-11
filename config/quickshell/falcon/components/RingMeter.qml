import QtQuick
import qs.services

// A small ring with an icon inside, for the resources on the bar. Red from 90%.
Item {
    id: root

    property string icon: ""
    property real value: 0

    width: 26
    height: 26

    Ring {
        anchors.fill: parent
        value: root.value
        thickness: 2.6
        color: root.value >= 0.9 ? Theme.error : Theme.accent
        trackColor: Qt.alpha(Theme.text, 0.16)
    }
    Icon {
        anchors.centerIn: parent
        name: root.icon
        size: 12
    }
}
