import QtQuick
import qs.services

Column {
    id: tool

    property string icon: ""
    property string title: ""
    // A switch that is on: the circle is filled with the accent.
    property bool on: false

    property int columns: 4

    signal clicked

    width: parent.width / columns
    spacing: 5

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 46
        height: 46
        radius: toolArea.containsMouse ? 23 : 16
        color: tool.on ? Theme.accent : toolArea.containsMouse ? Qt.alpha(Theme.accent, 0.24) : Qt.alpha(Theme.text, 0.06)
        scale: toolArea.pressed ? 0.9 : toolArea.containsMouse ? 1.06 : 1

        Behavior on radius {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: 160
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 180
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.3, 1.5, 0.4, 1, 1, 1]
            }
        }

        Icon {
            anchors.centerIn: parent
            name: tool.icon
            size: 19
            color: tool.on ? Theme.accentText : toolArea.containsMouse ? Theme.accent : Theme.text
        }
        MouseArea {
            id: toolArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tool.clicked()
        }
    }
    Label {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: tool.title
        color: Theme.muted
        size: 11
    }
}
