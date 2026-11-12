import QtQuick
import qs.components
import qs.services

// A rounded button of the phone window: accent when `primary`, red when `danger`.
Rectangle {
    id: root

    property string text: ""
    property string icon: ""
    property bool primary: false
    property bool danger: false
    property bool enabledButton: true

    signal clicked

    implicitWidth: row.implicitWidth + 28
    implicitHeight: 38
    radius: height / 2
    opacity: enabledButton ? 1 : 0.4
    color: primary ? (area.pressed ? Qt.darker(Theme.accent, 1.15) : Theme.accent) : danger ? Qt.alpha(Theme.error, area.containsMouse ? 0.28 : 0.18) : Qt.alpha(Theme.text, area.pressed ? 0.16 : area.containsMouse ? 0.11 : 0.07)
    scale: area.pressed ? 0.96 : 1

    Behavior on scale {
        NumberAnimation {
            duration: 120
        }
    }
    Behavior on color {
        ColorAnimation {
            duration: 140
        }
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 7

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            name: root.icon
            size: 15
            color: root.primary ? Theme.accentText : root.danger ? Theme.error : Theme.text
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.text !== ""
            text: root.text
            size: 13
            font.weight: Font.Medium
            color: root.primary ? Theme.accentText : root.danger ? Theme.error : Theme.text
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabledButton
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
