import QtQuick
import qs.services

Rectangle {
    id: tile

    property string icon: "wifi"
    property string title: ""
    property string sub: ""
    property bool on: false
    property bool active: false

    signal open
    signal toggled

    width: (parent.width - 8) / 2
    height: 60
    radius: on ? 18 : 22
    color: Qt.alpha(on ? Theme.accent : Theme.text, tileArea.containsMouse ? 0.2 : on ? 0.14 : 0.07)
    scale: tileArea.pressed ? 0.97 : 1

    Behavior on radius {
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutCubic
        }
    }
    Behavior on color {
        ColorAnimation {
            duration: 180
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: 120
        }
    }

    MouseArea {
        id: tileArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: tile.open()
    }
    // Doira yoqib-o'chiradi, qolgan joy ro'yxatni ochadi.
    Rectangle {
        id: orb

        x: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 40
        height: 40
        radius: tile.active ? 13 : 20
        color: tile.on ? Theme.accent : Qt.alpha(Theme.text, orbArea.containsMouse ? 0.18 : 0.1)
        scale: orbArea.pressed ? 0.9 : 1

        Behavior on radius {
            NumberAnimation {
                duration: 300
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.3, 1.4, 0.4, 1, 1, 1]
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: 180
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 120
            }
        }

        Icon {
            anchors.centerIn: parent
            name: tile.icon
            size: 18
            color: tile.on ? Theme.accentText : Theme.text
        }
        MouseArea {
            id: orbArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.toggled()
        }
    }
    Column {
        anchors.left: orb.right
        anchors.leftMargin: 10
        anchors.right: chevron.left
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Label {
            width: parent.width
            text: tile.title
            size: 13
            font.weight: Font.Medium
        }
        Label {
            width: parent.width
            text: tile.sub
            size: 11
            color: Theme.muted
        }
    }
    Icon {
        id: chevron

        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        name: "forward"
        size: 13
        color: Theme.muted
    }
}
