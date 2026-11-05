import QtQuick
import qs.services

// A level: icon, slim slider and percent in one row. value is 0 to 1.
Item {
    id: root

    property real value: 0
    property string icon: "volume"
    property string text: ""
    property bool dimmed: false
    // The icon works as its own button, such as mute.
    property bool iconButton: false

    signal moved(real value)
    signal iconClicked

    height: 38

    Rectangle {
        id: badge

        anchors.verticalCenter: parent.verticalCenter
        width: 34
        height: 34
        radius: root.iconButton && iconArea.containsMouse ? 12 : 17
        color: root.iconButton && iconArea.containsMouse ? Qt.alpha(Theme.text, 0.12) : "transparent"
        scale: iconArea.pressed ? 0.88 : 1

        Behavior on radius {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: 140
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 120
            }
        }

        Icon {
            anchors.centerIn: parent
            name: root.icon
            size: 17
            color: root.dimmed ? Theme.muted : Theme.text
        }
        MouseArea {
            id: iconArea

            anchors.fill: parent
            enabled: root.iconButton
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.iconClicked()
        }
    }
    SliderBar {
        anchors.left: badge.right
        anchors.leftMargin: 8
        anchors.right: percent.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        handle: true
        value: root.value
        onMoved: value => root.moved(value)
    }
    Label {
        id: percent

        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        width: 38
        horizontalAlignment: Text.AlignRight
        text: root.text
        size: 12
        color: Theme.muted
    }
}
