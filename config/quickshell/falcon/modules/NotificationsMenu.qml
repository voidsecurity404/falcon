import QtQuick
import qs.components
import qs.services

// The bell's menu: the notification history, with Clear.
Flyout {
    id: root

    panelWidth: 380
    padding: 6

    Item {
        width: parent.width
        height: 440

        NotificationList {
            anchors.fill: parent
        }
    }
}
