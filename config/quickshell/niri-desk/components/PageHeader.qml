import QtQuick
import qs.services

// Control center sub-page header: back arrow, title and an on/off switch.
Item {
    id: root

    property string title: ""
    property bool on: false
    property bool switchEnabled: true

    signal back
    signal toggled

    width: parent.width
    height: 32

    Rectangle {
        id: backButton

        width: 32
        height: 32
        radius: 9
        color: Qt.alpha(Theme.text, backArea.containsMouse ? 0.13 : 0.06)

        Icon {
            anchors.centerIn: parent
            name: "back"
            size: 16
        }
        MouseArea {
            id: backArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.back()
        }
    }

    Label {
        anchors.left: backButton.right
        anchors.leftMargin: 11
        anchors.right: track.left
        anchors.rightMargin: 11
        anchors.verticalCenter: parent.verticalCenter
        text: root.title
        size: 15
        font.weight: Font.Medium
    }

    Rectangle {
        id: track

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 40
        height: 22
        radius: 11
        color: root.on ? Theme.accent : Qt.alpha(Theme.text, 0.15)
        opacity: root.switchEnabled ? 1 : 0.4

        Rectangle {
            x: root.on ? parent.width - width - 3 : 3
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            radius: 8
            color: root.on ? Theme.accentText : Theme.text

            Behavior on x {
                NumberAnimation {
                    duration: 140
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: root.switchEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                if (root.switchEnabled)
                    root.toggled();
            }
        }
    }
}
