import QtQuick
import qs.services

// A network card. The round button switches it, and the rest of the card opens its list.
Rectangle {
    id: tile

    property string icon: "wifi"
    property string title: ""
    property string sub: ""
    property bool on: false
    property bool active: false

    signal open
    signal toggled

    width: (parent.width - 10) / 2
    height: 104
    radius: 24
    color: Qt.alpha(on ? Theme.accent : Theme.text, tileArea.containsMouse ? (on ? 0.26 : 0.12) : on ? 0.18 : 0.06)
    border.width: 1
    border.color: on ? Qt.alpha(Theme.accent, 0.3) : "transparent"
    scale: tileArea.pressed ? 0.97 : 1

    Behavior on color {
        ColorAnimation {
            duration: 180
        }
    }
    Behavior on border.color {
        ColorAnimation {
            duration: 180
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutBack
            easing.overshoot: 2
        }
    }

    MouseArea {
        id: tileArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: tile.open()
    }
    Rectangle {
        id: orb

        x: 12
        y: 12
        width: 42
        height: 42
        radius: tile.active ? 14 : 21
        color: tile.on ? Theme.accent : Qt.alpha(Theme.text, orbArea.containsMouse ? 0.18 : 0.1)
        scale: orbArea.pressed ? 0.88 : orbArea.containsMouse ? 1.06 : 1

        Behavior on radius {
            NumberAnimation {
                duration: 340
                easing.type: Easing.OutBack
                easing.overshoot: 1.6
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: 180
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutBack
                easing.overshoot: 2.4
            }
        }

        Icon {
            anchors.centerIn: parent
            name: tile.icon
            size: 19
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
    Icon {
        id: chevron

        anchors.right: parent.right
        anchors.rightMargin: tileArea.containsMouse ? 12 : 15
        y: 26
        name: "forward"
        size: 14
        color: Theme.muted

        Behavior on anchors.rightMargin {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutBack
                easing.overshoot: 2
            }
        }
    }
    Column {
        x: 14
        y: 62
        width: parent.width - 28
        spacing: 1

        Label {
            width: parent.width
            text: tile.title
            size: 14
            font.weight: Font.DemiBold
        }
        Label {
            width: parent.width
            text: tile.sub
            size: 12
            color: Theme.muted
        }
    }
}
