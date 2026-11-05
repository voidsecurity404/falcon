import QtQuick
import qs.services

// A row of icon and word buttons with one highlight sliding between them.
Item {
    id: root

    property var items: []
    property int current: 0

    signal chosen(int index)

    implicitWidth: row.implicitWidth
    implicitHeight: 44

    Rectangle {
        readonly property Item shownItem: repeater.count > root.current ? repeater.itemAt(root.current) : null

        x: shownItem ? shownItem.x : 0
        width: shownItem ? shownItem.width : 0
        height: parent.height
        radius: 22
        color: Theme.accent

        Behavior on x {
            NumberAnimation {
                duration: 240
                easing.type: Easing.OutCubic
            }
        }
        Behavior on width {
            NumberAnimation {
                duration: 240
                easing.type: Easing.OutCubic
            }
        }
    }

    Row {
        id: row

        height: parent.height

        Repeater {
            id: repeater

            model: root.items

            delegate: Item {
                id: segment

                required property var modelData
                required property int index
                readonly property bool active: root.current === index
                readonly property color tint: active ? Theme.accentText : segmentArea.containsMouse ? Theme.text : Theme.muted

                width: content.implicitWidth + 26
                height: row.height

                Row {
                    id: content

                    anchors.centerIn: parent
                    spacing: 7

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: segment.modelData.icon
                        size: 17
                        color: segment.tint
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: segment.modelData.name
                        color: segment.tint
                        size: 12
                    }
                }
                MouseArea {
                    id: segmentArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.chosen(segment.index)
                }
            }
        }
    }
}
