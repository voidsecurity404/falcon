import QtQuick
import qs.services

// A round icon button with its name shown above it on hover.
Rectangle {
    id: root

    property string icon: ""
    property string tip: ""
    property bool active: false

    signal clicked

    width: 40
    height: 40
    radius: 20
    color: active ? Theme.accent : area.containsMouse ? Qt.alpha(Theme.text, 0.12) : Qt.alpha(Theme.text, 0.05)
    opacity: enabled ? 1 : 0.35

    Behavior on color {
        ColorAnimation {
            duration: 140
        }
    }

    Icon {
        anchors.centerIn: parent
        name: root.icon
        size: 18
        color: root.active ? Theme.accentText : Theme.text
    }
    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
    Rectangle {
        visible: area.containsMouse && root.enabled
        anchors.bottom: parent.top
        anchors.bottomMargin: 6
        anchors.right: parent.right
        width: tipText.implicitWidth + 16
        height: 26
        radius: 13
        color: Theme.pill

        Label {
            id: tipText

            anchors.centerIn: parent
            text: root.tip
            size: 11
        }
    }
}
