import QtQuick
import qs.components
import qs.services

// System: the main figures and the busiest processes. A process of this user can be ended with two presses.
Item {
    id: root

    property int armed: -1

    function press(row) {
        if (armed !== row.pid) {
            armed = row.pid;
            disarm.restart();
            return;
        }
        armed = -1;
        Processes.end(row.pid);
    }

    Timer {
        id: disarm

        interval: 4000
        onTriggered: root.armed = -1
    }

    Row {
        id: figures

        width: parent.width
        spacing: 16

        Stat {
            label: Tr.t("Processor")
            value: Sys.cpu + "%"
            share: Sys.cpu / 100
            hot: Sys.cpu >= 85
        }
        Stat {
            label: Tr.t("Memory")
            value: Sys.ramGb.toFixed(1) + " " + Tr.t("GB")
            share: Sys.ram / 100
            hot: Sys.ram >= 90
        }
        Stat {
            label: Tr.t("Temperature")
            value: Sys.temperature > 0 ? Sys.temperature + "°" : "—"
            share: Sys.temperature / 100
            hot: Sys.temperature >= 90
        }
        Stat {
            label: Tr.t("GPU clock")
            value: Processes.gpuMhz > 0 ? Processes.gpuMhz + " " + Tr.t("MHz") : "—"
            share: Processes.gpuMhz / 1500
        }
    }

    Rectangle {
        anchors.top: figures.bottom
        anchors.topMargin: 18
        anchors.bottom: parent.bottom
        width: parent.width
        radius: 22
        color: Qt.alpha(Theme.text, 0.05)

        Item {
            id: head

            x: 18
            width: parent.width - 36
            height: 36

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: Tr.t("Process")
                color: Theme.muted
                size: 12
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                x: parent.width - 220
                width: 70
                horizontalAlignment: Text.AlignRight
                text: Tr.t("Processor")
                color: Theme.muted
                size: 12
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                x: parent.width - 140
                width: 70
                horizontalAlignment: Text.AlignRight
                text: Tr.t("Memory")
                color: Theme.muted
                size: 12
            }
        }

        Column {
            anchors.top: head.bottom
            x: 10
            width: parent.width - 20
            clip: true

            Repeater {
                model: Processes.rows

                delegate: Rectangle {
                    id: row

                    required property var modelData

                    readonly property bool own: modelData.user === Processes.user
                    readonly property bool armed: root.armed === modelData.pid

                    width: parent.width
                    height: 30
                    radius: 9
                    color: armed ? Qt.alpha(Theme.error, 0.18) : rowHover.hovered ? Qt.alpha(Theme.text, 0.05) : "transparent"

                    HoverHandler {
                        id: rowHover
                    }
                    Label {
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 240
                        text: row.armed ? Tr.t("Press once more to proceed") : row.modelData.name
                        color: row.armed ? Theme.error : row.own ? Theme.text : Theme.muted
                        size: 13
                        elide: Text.ElideRight
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        x: parent.width - 212
                        width: 70
                        horizontalAlignment: Text.AlignRight
                        text: row.modelData.cpu.toFixed(1) + "%"
                        size: 13
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        x: parent.width - 132
                        width: 70
                        horizontalAlignment: Text.AlignRight
                        text: row.modelData.mem.toFixed(1) + "%"
                        size: 13
                    }
                    Icon {
                        visible: row.own
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        name: "close"
                        size: 13
                        color: endArea.containsMouse || row.armed ? Theme.error : Theme.muted
                    }
                    MouseArea {
                        id: endArea

                        visible: row.own
                        anchors.right: parent.right
                        width: 32
                        height: parent.height
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.press(row.modelData)
                    }
                }
            }
        }
    }
}
