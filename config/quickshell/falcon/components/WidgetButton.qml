import QtQuick
import qs.services

// A round or pill button of a widget, lit when on.
Rectangle {
    id: btn

    property string icon: ""
    property string text: ""
    property bool on: false
    property bool main: false
    property real iconSize: Math.round(height * 0.42)
    property color onColor: Theme.accent
    property color onText: Theme.accentText
    readonly property alias hovered: hot.hovered
    signal clicked

    implicitWidth: text !== "" ? row.implicitWidth + 28 : height
    height: 36
    radius: height / 2
    color: main || on ? (hot.hovered ? Qt.lighter(onColor, 1.08) : onColor) : Qt.alpha(Theme.text, hot.hovered ? 0.15 : 0.07)
    scale: hot.down ? 0.92 : 1
    border.width: main || on ? 0 : 1
    border.color: Qt.alpha(Theme.text, 0.06)

    Behavior on color {
        ColorAnimation {
            duration: 160
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: 140
            easing.type: Easing.OutBack
        }
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 7

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: btn.icon !== ""
            name: btn.icon
            size: btn.iconSize
            color: btn.main || btn.on ? btn.onText : Theme.text
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            visible: btn.text !== ""
            text: btn.text
            size: 13
            font.weight: Font.DemiBold
            color: btn.main || btn.on ? btn.onText : Theme.text
        }
    }
    WidgetHot {
        id: hot

        anchors.fill: parent
        onClicked: btn.clicked()
    }
}
