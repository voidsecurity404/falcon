import QtQuick
import qs.components
import qs.services

// System: dials on the left, the load over time and the busiest programs on the right.
// A program of this user can be ended with two presses.
Item {
    id: root

    property int armed: -1

    readonly property bool live: visible && Ui.popup === "dashboard"
    readonly property int rowCount: 7
    // Bars compare programs with each other, so a calm computer still shows who is on top.
    readonly property real barFull: Math.max(25, Processes.rows.length > 0 ? Processes.rows[0].cpu : 0)

    function press(row) {
        if (armed !== row.pid) {
            armed = row.pid;
            disarm.restart();
            return;
        }
        armed = -1;
        Processes.end(row.pid);
    }

    component Dial: TickGauge {
        id: dial

        property string value: ""
        property string unit: ""
        property string label: ""

        width: 116
        height: 116
        live: root.live
        ticks: 30
        tickLength: 8
        tickWidth: 3

        Column {
            anchors.centerIn: parent

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: dial.value
                color: dial.hot ? Theme.error : Theme.text
                size: 21
                font.weight: Font.Medium
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: dial.unit !== ""
                text: dial.unit
                color: Theme.muted
                size: 10
            }
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            text: dial.label
            color: Theme.muted
            size: 11
        }
    }

    Timer {
        id: disarm

        interval: 4000
        onTriggered: root.armed = -1
    }

    Item {
        id: dials

        width: 392
        height: parent.height

        TickGauge {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 340
            height: 340
            live: root.live
            share: Sys.cpu / 100
            hot: Sys.cpu >= 85
            ticks: 55
            tickLength: 24
            tickWidth: 4

            Row {
                anchors.centerIn: parent

                Label {
                    id: cpuNumber

                    text: Sys.cpu
                    color: Sys.cpu >= 85 ? Theme.error : Theme.text
                    size: 84
                    font.weight: Font.Light
                }
                Label {
                    anchors.baseline: cpuNumber.baseline
                    text: "%"
                    color: Theme.muted
                    size: 26
                }
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10
                text: Tr.t("Processor")
                color: Theme.muted
                size: 14
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            spacing: 12

            Dial {
                value: Sys.ramGb.toFixed(1)
                unit: Tr.t("GB")
                label: Tr.t("Memory")
                share: Sys.ram / 100
                hot: Sys.ram >= 90
            }
            Dial {
                value: Sys.temperature > 0 ? Sys.temperature + "°" : "—"
                label: Tr.t("Temperature")
                share: Sys.temperature / 100
                hot: Sys.temperature >= 90
            }
            Dial {
                value: Processes.gpuMhz > 0 ? Processes.gpuMhz : "—"
                unit: Processes.gpuMhz > 0 ? Tr.t("MHz") : ""
                label: Tr.t("GPU clock")
                share: Processes.gpuMhz / 1500
            }
        }
    }

    Item {
        id: side

        x: dials.width + 32
        width: parent.width - x
        height: parent.height

        Label {
            id: chartTitle

            text: Tr.t("Load, last 2 minutes")
            color: Theme.muted
            size: 12
        }

        Item {
            id: chartArea

            y: chartTitle.height + 8
            width: parent.width
            height: 140

            Repeater {
                model: 3

                delegate: Rectangle {
                    required property int index

                    y: (index + 1) * chartArea.height / 4
                    width: chartArea.width
                    height: 1
                    color: Qt.alpha(Theme.text, 0.06)
                }
            }
            LoadChart {
                anchors.fill: parent
                values: Sys.history
            }
        }

        Item {
            id: head

            y: chartArea.y + chartArea.height + 14
            width: parent.width
            height: 22

            Label {
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                text: Tr.t("Process")
                color: Theme.muted
                size: 12
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                x: parent.width - 182
                width: 78
                horizontalAlignment: Text.AlignRight
                text: Tr.t("Processor")
                color: Theme.muted
                size: 12
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                x: parent.width - 104
                width: 72
                horizontalAlignment: Text.AlignRight
                text: Tr.t("Memory")
                color: Theme.muted
                size: 12
            }
        }

        Column {
            anchors.top: head.bottom
            anchors.topMargin: 4
            width: parent.width
            spacing: 4

            // Fixed places instead of a model of the rows: the places stay, so bars glide to new values.
            Repeater {
                model: root.rowCount

                delegate: Rectangle {
                    id: row

                    required property int index

                    readonly property var info: Processes.rows[index] || null
                    // Ending these would close the whole session.
                    readonly property bool own: !!info && info.user === Processes.user && !["niri", "niri-session", "qs", "systemd", "dbus-broker", "dbus-broker-lau", "pipewire", "wireplumber"].includes(info.name)
                    readonly property bool armed: !!info && root.armed === info.pid

                    width: parent.width
                    height: 32
                    radius: 11
                    visible: !!info
                    color: armed ? Qt.alpha(Theme.error, 0.18) : rowHover.hovered ? Qt.alpha(Theme.text, 0.05) : "transparent"

                    HoverHandler {
                        id: rowHover
                    }
                    Rectangle {
                        visible: !row.armed && !!row.info && row.info.cpu >= 0.1
                        width: Math.max(22, row.width * (row.info ? row.info.cpu : 0) / root.barFull)
                        height: parent.height
                        radius: parent.radius
                        color: Qt.alpha(Theme.accent, 0.24)

                        Behavior on width {
                            NumberAnimation {
                                duration: 500
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                    Label {
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - (row.armed ? 330 : 200)
                        text: row.info ? row.info.name : ""
                        color: row.own ? Theme.text : Theme.muted
                        size: 13
                        elide: Text.ElideRight
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        anchors.rightMargin: 32
                        visible: row.armed
                        text: Tr.t("Press once more to proceed")
                        color: Theme.error
                        size: 12
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        x: parent.width - 182
                        width: 78
                        visible: !row.armed
                        horizontalAlignment: Text.AlignRight
                        text: row.info ? row.info.cpu.toFixed(1) + "%" : ""
                        size: 13
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        x: parent.width - 104
                        width: 72
                        visible: !row.armed
                        horizontalAlignment: Text.AlignRight
                        text: row.info ? row.info.mem.toFixed(1) + "%" : ""
                        color: Theme.muted
                        size: 13
                    }
                    Icon {
                        visible: row.own && (rowHover.hovered || row.armed)
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
                        onClicked: root.press(row.info)
                    }
                }
            }
        }
    }
}
