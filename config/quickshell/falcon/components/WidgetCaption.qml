import QtQuick
import qs.services

// The small title line of a widget: an icon in a soft accent dot and a muted caption.
Row {
    id: cap

    property string icon: ""
    property string text: ""
    property color tint: Theme.accent

    spacing: 8

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 24
        height: 24
        radius: 12
        color: Qt.alpha(cap.tint, 0.18)
        visible: cap.icon !== ""

        Icon {
            anchors.centerIn: parent
            name: cap.icon
            size: 13
            color: cap.tint
        }
    }
    Label {
        anchors.verticalCenter: parent.verticalCenter
        text: cap.text
        size: 12
        font.weight: Font.DemiBold
        font.letterSpacing: 0.6
        font.capitalization: Font.AllUppercase
        color: Theme.muted
    }
}
