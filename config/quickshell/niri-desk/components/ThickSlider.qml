import QtQuick
import qs.services

// Thick slider: the icon and value sit inside the bar. value is 0 to 1.
Rectangle {
    id: root

    property real value: 0
    property string icon: "volume"
    property string text: ""
    // The icon works as its own button, such as mute.
    property bool iconButton: false

    signal moved(real value)
    signal iconClicked

    readonly property real shown: Math.max(0, Math.min(1, value))

    function fromMouse(x) {
        root.moved(Math.max(0, Math.min(1, x / width)));
    }

    height: 34
    radius: 17
    color: Qt.alpha(Theme.text, area.containsMouse ? 0.11 : 0.08)
    clip: true

    Behavior on color {
        ColorAnimation {
            duration: 140
        }
    }

    Rectangle {
        width: Math.max(root.height, root.width * root.shown)
        height: parent.height
        radius: root.radius
        color: Theme.accent

        Behavior on width {
            enabled: !area.pressed

            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => root.fromMouse(mouse.x)
        onPositionChanged: mouse => {
            if (pressed)
                root.fromMouse(mouse.x);
        }
    }

    MouseArea {
        visible: root.iconButton
        width: root.height
        height: root.height
        cursorShape: Qt.PointingHandCursor
        onClicked: root.iconClicked()
    }

    Icon {
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        name: root.icon
        size: 15
        color: Theme.accentText
    }
    Label {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        size: 12
        color: root.shown > 0.9 ? Theme.accentText : Theme.text
    }
}
