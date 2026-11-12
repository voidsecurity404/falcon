import QtQuick
import qs.components
import qs.services

// One screen of the phone window: a back arrow and the title, then its content.
Item {
    id: root

    property string title: ""
    property string subtitle: ""
    default property alias content: holder.data
    property alias actions: actionsRow.data

    Item {
        id: header

        width: parent.width
        height: 52

        Rectangle {
            id: back

            objectName: "phoneBack"
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 36
            height: 36
            radius: 18
            color: Qt.alpha(Theme.text, backArea.containsMouse ? 0.1 : 0)

            Icon {
                anchors.centerIn: parent
                name: "back"
                size: 18
            }
            MouseArea {
                id: backArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Ui.phonePage = ""
            }
        }
        Column {
            anchors.left: back.right
            anchors.leftMargin: 8
            anchors.right: actionsRow.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter

            Label {
                width: parent.width
                text: root.title
                size: 17
                font.weight: Font.DemiBold
            }
            Label {
                width: parent.width
                visible: root.subtitle !== ""
                text: root.subtitle
                size: 11
                color: Theme.muted
            }
        }
        Row {
            id: actionsRow

            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
        }
    }

    Item {
        id: holder

        y: header.height + 4
        width: parent.width
        height: parent.height - y
    }
}
