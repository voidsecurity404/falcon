import QtQuick
import qs.services

// A small button with an optional icon. `accent` fills it with the theme color.
Rectangle {
    id: root

    property string text: ""
    property string icon: ""
    property bool accent: false
    property bool enabledLook: true

    signal clicked

    implicitWidth: content.implicitWidth + 26
    implicitHeight: 34
    radius: 17
    opacity: enabledLook ? 1 : 0.5
    color: accent ? Theme.accent : Qt.alpha(Theme.text, area.containsMouse ? 0.14 : 0.08)
    scale: area.pressed ? 0.95 : 1

    Behavior on color {
        ColorAnimation {
            duration: 140
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: 110
        }
    }

    Row {
        id: content

        anchors.centerIn: parent
        spacing: 7

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            name: root.icon
            size: 15
            color: root.accent ? Theme.accentText : Theme.text
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.text !== ""
            text: root.text
            size: 13
            color: root.accent ? Theme.accentText : Theme.text
        }
    }
    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
