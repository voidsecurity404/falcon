import QtQuick
import qs.services

// One network or device in a list. actions: [{label, run}], shown at the right edge.
Rectangle {
    id: root

    property string icon: "wifi"
    property real iconOpacity: 1
    property string title: ""
    property string sub: ""
    property string note: ""
    property bool current: false
    property bool locked: false
    property var actions: []

    signal clicked

    width: parent.width
    height: sub !== "" ? 48 : 40
    radius: 10
    color: current ? Qt.alpha(Theme.accent, 0.16) : Qt.alpha(Theme.text, area.containsMouse ? 0.08 : 0)

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Icon {
        id: mark

        anchors.left: parent.left
        anchors.leftMargin: 11
        anchors.verticalCenter: parent.verticalCenter
        name: root.icon
        size: 16
        opacity: root.iconOpacity
        color: root.current ? Theme.accent : Theme.text
    }

    Column {
        anchors.left: mark.right
        anchors.leftMargin: 11
        anchors.right: side.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Label {
            width: parent.width
            text: root.title
            size: 13
            color: root.current ? Theme.accent : Theme.text
        }
        Label {
            width: parent.width
            visible: root.sub !== ""
            text: root.sub
            size: 11
            color: Theme.muted
        }
    }

    Row {
        id: side

        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 9

        Repeater {
            model: root.actions

            delegate: Label {
                id: action

                required property var modelData

                anchors.verticalCenter: parent.verticalCenter
                text: modelData.label
                size: 12
                color: actionArea.containsMouse ? Theme.text : Theme.muted

                MouseArea {
                    id: actionArea

                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: action.modelData.run()
                }
            }
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.actions.length === 0 && root.note !== ""
            text: root.note
            size: 12
            color: Theme.muted
        }
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.locked
            name: "lock"
            size: 13
            color: Theme.muted
        }
    }
}
