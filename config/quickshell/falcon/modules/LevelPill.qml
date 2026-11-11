import QtQuick
import qs.components
import qs.services

// Volume and brightness levels: a small pill under the bar's middle island while a level changes.
Rectangle {
    id: root

    // The last level stays while the pill fades out.
    property var shown: null
    readonly property var level: Toasts.osd
    property real reveal: level ? 1 : 0
    property real restY: 0

    onLevelChanged: {
        if (level)
            shown = level;
    }

    Behavior on reveal {
        NumberAnimation {
            duration: root.level ? 200 : 260
            easing.type: Easing.OutCubic
        }
    }

    visible: reveal > 0.01
    opacity: reveal
    y: restY - (1 - reveal) * 10
    width: 250
    height: 40
    radius: 14
    border.width: 1
    border.color: Theme.panelEdge
    color: Qt.alpha(Theme.glassBase, Math.max(0.72, Theme.glassOpacity))

    Row {
        anchors.centerIn: parent
        spacing: 12

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: root.shown ? root.shown.icon : "volume"
            size: 17
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 150
            height: 6
            radius: 3
            color: Qt.alpha(Theme.text, 0.15)

            Rectangle {
                width: parent.width * (root.shown ? Math.max(0, Math.min(1, root.shown.value)) : 0)
                height: parent.height
                radius: 3
                color: Theme.accent

                Behavior on width {
                    NumberAnimation {
                        duration: 120
                    }
                }
            }
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            width: 36
            text: root.shown ? Math.round(root.shown.value * 100) + "%" : ""
            size: 12
            font.weight: Font.DemiBold
        }
    }
}
