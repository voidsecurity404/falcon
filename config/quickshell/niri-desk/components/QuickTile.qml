import QtQuick
import qs.services

// A switch with the icon above its name. It fills with the accent color while on.
Rectangle {
    id: quick

    property string icon: ""
    property string title: ""
    property bool on: false

    signal clicked

    width: (parent.width - 20) / 3
    height: 80
    radius: on ? 18 : 24
    color: on ? Theme.accent : Qt.alpha(Theme.text, quickArea.containsMouse ? 0.12 : 0.06)
    scale: quickArea.pressed ? 0.94 : 1

    onOnChanged: pop.restart()

    Behavior on radius {
        NumberAnimation {
            duration: 340
            easing.type: Easing.OutBack
            easing.overshoot: 1.6
        }
    }
    Behavior on color {
        ColorAnimation {
            duration: 200
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutBack
            easing.overshoot: 2.2
        }
    }

    Icon {
        id: mark

        anchors.horizontalCenter: parent.horizontalCenter
        y: 15
        name: quick.icon
        size: 22
        color: quick.on ? Theme.accentText : Theme.text

        Behavior on color {
            ColorAnimation {
                duration: 200
            }
        }
        SequentialAnimation {
            id: pop

            NumberAnimation {
                target: mark
                property: "scale"
                to: 1.3
                duration: 130
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: mark
                property: "scale"
                to: 1
                duration: 320
                easing.type: Easing.OutBack
                easing.overshoot: 2.4
            }
        }
    }
    Label {
        x: 6
        width: parent.width - 12
        y: 48
        horizontalAlignment: Text.AlignHCenter
        text: quick.title
        size: 12
        font.weight: Font.Medium
        color: quick.on ? Theme.accentText : Theme.text

        Behavior on color {
            ColorAnimation {
                duration: 200
            }
        }
    }
    MouseArea {
        id: quickArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: quick.clicked()
    }
}
