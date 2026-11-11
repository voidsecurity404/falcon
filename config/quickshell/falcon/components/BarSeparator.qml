import QtQuick
import qs.services

// The thin line between the groups of a glass island.
Rectangle {
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    width: 1
    height: 18
    color: Qt.alpha(Theme.text, 0.16)
}
