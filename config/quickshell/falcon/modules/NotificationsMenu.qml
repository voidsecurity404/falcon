import QtQuick
import qs.components
import qs.services

// The bell's menu: the notification history, with Clear and a button to the notification settings.
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

        BarButton {
            objectName: "notifySettings"
            anchors.right: parent.right
            anchors.rightMargin: 12
            y: 12
            icon: "settings"
            iconSize: 17
            onClicked: {
                Ui.popup = "";
                Ui.settingsPage = 3;
                Ui.settingsOpen = true;
            }
        }
    }
}
