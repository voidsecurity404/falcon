import QtQuick
import qs.services

Rectangle {
    id: quick

    property string icon: ""
    property string title: ""
    property bool on: false

    signal clicked

    width: (parent.width - 16) / 3
    height: 52
    radius: on ? 16 : 26
    color: on ? Theme.accent : Qt.alpha(Theme.text, quickArea.containsMouse ? 0.13 : 0.07)
    scale: quickArea.pressed ? 0.95 : 1

    Behavior on radius {
        NumberAnimation {
            duration: 320
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.3, 1.35, 0.4, 1, 1, 1]
        }
    }
    Behavior on color {
        ColorAnimation {
            duration: 200
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: 120
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 7

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: quick.icon
            size: 16
            color: quick.on ? Theme.accentText : Theme.text
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: quick.title
            size: 12
            color: quick.on ? Theme.accentText : Theme.text
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
