import QtQuick
import Quickshell
import qs.components
import qs.services

// The menu of a network or security part of the bar (NetTools): the reading as a table under the
// part. A click on a row copies its first cell, a right click the whole row. In the devices list
// each row also checks the device's common ports, shown under the table.
Flyout {
    id: root

    readonly property string tool: NetTools.open
    readonly property var info: NetTools.data[tool] || null
    readonly property var columns: info && info.columns ? info.columns : []
    readonly property var rows: info && info.rows ? info.rows : []
    readonly property bool busy: !!NetTools.busy[tool]
    property string copied: ""

    // Widths of the columns by their longest text, so addresses never get cut.
    readonly property var widths: {
        const n = columns.length;
        if (n === 0)
            return [];
        const longest = columns.map((c, i) => {
            let m = String(c).length;
            for (const r of rows)
                m = Math.max(m, String(r[i] === undefined ? "" : r[i]).length);
            return Math.max(3, Math.min(30, m));
        });
        const sum = longest.reduce((a, b) => a + b, 0);
        const room = panelWidth - padding * 2 - (tool === "lan" ? 54 : 0) - 8 * (n - 1);
        return longest.map(m => Math.floor(room * m / sum));
    }

    panelWidth: tool === "lan" || tool === "conns" || tool === "ports" || tool === "aps" || tool === "bt" || tool === "iface" ? 640 : 480

    onToolChanged: copied = ""

    Timer {
        id: copiedTimer

        interval: 1800
        onTriggered: root.copied = ""
    }

    function copyText(text) {
        NetTools.copy(text);
        copied = text;
        copiedTimer.restart();
    }

    Column {
        width: parent.width
        spacing: 10

        // Heading: icon, title, refresh.
        Item {
            width: parent.width
            height: 34

            Rectangle {
                id: badgeCircle

                width: 34
                height: 34
                radius: 17
                color: Qt.alpha(NetTools.colorOf(root.tool), 0.16)

                Icon {
                    anchors.centerIn: parent
                    name: NetTools.iconOf(root.tool)
                    size: 18
                    color: NetTools.colorOf(root.tool)
                }
            }
            Column {
                x: badgeCircle.width + 12
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x - 44

                Label {
                    width: parent.width
                    text: root.info && root.info.title ? root.info.title : Tr.t((NetTools.byId[root.tool] || {}).title || "")
                    font.family: Theme.display
                    size: 15
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Label {
                    width: parent.width
                    visible: text !== ""
                    text: root.info ? root.info.summary || "" : ""
                    size: 11
                    color: Theme.muted
                    elide: Text.ElideRight
                }
            }
            BarButton {
                objectName: "netRefresh"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                icon: "refresh"
                onClicked: NetTools.refresh(root.tool)

                RotationAnimation on rotation {
                    running: root.busy
                    loops: Animation.Infinite
                    from: 0
                    to: 360
                    duration: 900
                    onStopped: parent.rotation = 0
                }
            }
        }

        Label {
            width: parent.width
            visible: !!root.info && !!root.info.error
            text: root.info ? root.info.error || "" : ""
            color: Theme.error
            size: 13
            wrapMode: Text.Wrap
        }
        Label {
            width: parent.width
            visible: !root.info && root.busy
            text: root.tool === "lan" ? Tr.t("Looking for devices…") : root.tool === "bt" ? Tr.t("Scanning for 6 seconds…") : Tr.t("Reading…")
            color: Theme.muted
            size: 13
        }

        // The table.
        Column {
            width: parent.width
            visible: root.rows.length > 0
            spacing: 2

            Row {
                spacing: 8
                leftPadding: 8

                Repeater {
                    model: root.columns

                    delegate: Label {
                        required property string modelData
                        required property int index

                        width: (root.widths[index] || 40) - (index === 0 ? 8 : 0)
                        text: modelData
                        size: 10
                        font.weight: Font.DemiBold
                        font.capitalization: Font.AllUppercase
                        color: Theme.muted
                        elide: Text.ElideRight
                    }
                }
            }

            Flickable {
                width: parent.width
                height: Math.min(contentHeight, 420)
                contentHeight: table.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: table

                    width: parent.width
                    spacing: 2

                    Repeater {
                        model: root.rows

                        delegate: Rectangle {
                            id: rowItem

                            required property var modelData
                            required property int index

                            width: table.width
                            height: 28
                            radius: 9
                            color: rowArea.containsMouse ? Qt.alpha(Theme.text, 0.09) : index % 2 ? Qt.alpha(Theme.text, 0.03) : "transparent"

                            MouseArea {
                                id: rowArea

                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => root.copyText(mouse.button === Qt.RightButton ? rowItem.modelData.join("  ") : rowItem.modelData[0])
                            }
                            Row {
                                x: 8
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8

                                Repeater {
                                    model: rowItem.modelData

                                    delegate: Label {
                                        required property var modelData
                                        required property int index

                                        width: (root.widths[index] || 40) - (index === 0 ? 8 : 0)
                                        text: String(modelData)
                                        size: 12
                                        font.family: index === 0 || /^([0-9a-f]{2}:){5}[0-9a-f]{2}$/i.test(String(modelData)) ? Theme.mono : Theme.sans
                                        font.weight: index === 0 ? Font.DemiBold : Font.Normal
                                        color: index === 0 ? Theme.text : Qt.alpha(Theme.text, 0.82)
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                            // Devices: check this one's ports.
                            Rectangle {
                                visible: root.tool === "lan"
                                anchors.right: parent.right
                                anchors.rightMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                width: 46
                                height: 22
                                radius: 11
                                color: portsArea.containsMouse ? Qt.alpha(Theme.accent, 0.35) : Qt.alpha(Theme.accent, 0.16)

                                Label {
                                    anchors.centerIn: parent
                                    text: NetTools.probing && NetTools.probeIp === rowItem.modelData[0] ? "…" : Tr.t("Ports")
                                    size: 10
                                    font.weight: Font.DemiBold
                                }
                                MouseArea {
                                    id: portsArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: NetTools.probeHost(rowItem.modelData[0])
                                }
                            }
                        }
                    }
                }
            }
        }

        // The port check of one device.
        Rectangle {
            width: parent.width
            visible: root.tool === "lan" && (NetTools.probing || !!NetTools.probe)
            height: probeColumn.implicitHeight + 20
            radius: 12
            color: Qt.alpha(Theme.accent, 0.08)

            Column {
                id: probeColumn

                x: 12
                y: 10
                width: parent.width - 24
                spacing: 6

                Label {
                    text: NetTools.probing ? Tr.t("Checking the ports of {ip}…").replace("{ip}", NetTools.probeIp) : NetTools.probe ? (NetTools.probe.error || NetTools.probe.summary) : ""
                    size: 12
                    font.weight: Font.DemiBold
                }
                Flow {
                    width: parent.width
                    spacing: 6
                    visible: !NetTools.probing && !!NetTools.probe

                    Repeater {
                        model: NetTools.probe ? NetTools.probe.rows : []

                        delegate: Rectangle {
                            required property var modelData

                            width: portLabel.implicitWidth + 16
                            height: 22
                            radius: 11
                            color: Qt.alpha(Theme.text, 0.08)

                            Label {
                                id: portLabel

                                anchors.centerIn: parent
                                text: modelData[0] + " · " + modelData[1]
                                size: 11
                                font.family: Theme.mono
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.copyText(NetTools.probeIp + ":" + modelData[0])
                            }
                        }
                    }
                }
            }
        }

        Label {
            width: parent.width
            text: root.copied !== "" ? Tr.t("Copied: {text}").replace("{text}", root.copied) : Tr.t("Click copies the first value, right click the whole row")
            size: 10
            color: root.copied !== "" ? Theme.accent : Qt.alpha(Theme.muted, 0.8)
            elide: Text.ElideRight
        }
    }
}
