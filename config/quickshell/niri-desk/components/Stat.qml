import QtQuick
import qs.services

Column {
    id: stat

    property string label: ""
    property string value: ""
    property real share: 0
    property bool hot: false

    width: (parent.width - 16 * 3) / 4
    spacing: 6

    Label {
        text: stat.value
        size: 19
        font.weight: Font.Medium
    }
    Rectangle {
        width: parent.width
        height: 4
        radius: 2
        color: Qt.alpha(Theme.text, 0.12)

        Rectangle {
            width: Math.max(height, parent.width * Math.max(0, Math.min(1, stat.share)))
            height: parent.height
            radius: 2
            color: stat.hot ? Theme.error : Theme.accent

            Behavior on width {
                NumberAnimation {
                    duration: 500
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
    Row {
        spacing: 4

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: stat.hot
            name: "alert"
            size: 11
            color: Theme.error
        }
        Label {
            text: stat.label
            color: Theme.muted
            size: 11
        }
    }
}
