import QtQuick
import qs.components
import qs.services

// How full the disk is. Forms: round, wide (a bar with the free space).
Item {
    id: root

    property string form: "round"
    readonly property bool wide: form === "wide"
    readonly property color tone: Sys.disk >= 90 ? Theme.error : Theme.accent

    Ring {
        visible: !root.wide
        anchors.horizontalCenter: parent.horizontalCenter
        y: 16
        width: 126
        height: 126
        thickness: 14
        color: root.tone
        value: Sys.disk / 100

        Label {
            anchors.centerIn: parent
            text: Sys.disk + "%"
            size: 26
            font.family: Theme.display
            font.weight: Font.Medium
        }
    }
    Label {
        visible: !root.wide
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
        text: Tr.t("{n} GB free").replace("{n}", Sys.diskFreeGb)
        color: Theme.muted
        size: 13
    }
    Column {
        visible: root.wide
        x: 20
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 40
        spacing: 10

        Item {
            width: parent.width
            height: 32

            Label {
                id: free

                anchors.bottom: parent.bottom
                text: Sys.diskFreeGb + " " + Tr.t("GB")
                size: 24
                font.family: Theme.display
                font.weight: Font.Medium
            }
            Label {
                anchors.left: free.right
                anchors.leftMargin: 8
                anchors.baseline: free.baseline
                text: Tr.t("free of {n}").replace("{n}", Sys.diskTotalGb)
                color: Theme.muted
                size: 12
            }
        }
        Rectangle {
            width: parent.width
            height: 14
            radius: 7
            color: Qt.alpha(Theme.text, 0.1)

            Rectangle {
                width: Math.max(height, parent.width * Sys.disk / 100)
                height: parent.height
                radius: 7
                color: root.tone
            }
        }
    }
}
