import QtQuick
import Quickshell
import qs.components
import qs.services

// The network and security menu (NetTools), on glass like the control center and dropping the same
// way: it grows its own height and the last 28 px of its width, its pages keep a fixed width inside.
// The hub's page shows every reading as a tile with its value; a tile, or a part of the bar for
// one reading, shows that reading's table. A click on a row copies its first cell, a right click
// the row; in the devices table a row's Ports button checks that device's common ports.
Rectangle {
    id: root

    property bool shown: false
    property real reveal: 0
    readonly property string tool: NetTools.open
    readonly property var info: NetTools.data[tool] || null
    readonly property var columns: info && info.columns ? info.columns : []
    readonly property var rows: info && info.rows ? info.rows : []
    readonly property bool busy: !!NetTools.busy[tool]
    readonly property int panelWidth: 640
    readonly property int padding: 16
    readonly property real pageHeight: (tool === "" ? home.implicitHeight : detail.implicitHeight) + padding * 2
    property real shownHeight: pageHeight
    property string copied: ""

    // Widths of the columns by their longest text. When they do not fit, only the widest ones
    // give way (all cut to one cap), so addresses and MACs are never cut.
    readonly property var widths: {
        const n = columns.length;
        if (n === 0)
            return [];
        const need = columns.map((c, i) => {
            let m = String(c).length;
            for (const r of rows)
                m = Math.max(m, String(r[i] === undefined ? "" : r[i]).length);
            return Math.max(3, m) * (i === 0 ? 7.8 : 7.3) + 6;
        });
        const room = panelWidth - padding * 2 - 8 - (tool === "lan" ? 54 : 0) - 8 * (n - 1);
        let cap = Math.max(...need);
        let sum = need.reduce((a, w) => a + w, 0);
        while (sum > room && cap > 40) {
            cap -= 2;
            sum = need.reduce((a, w) => a + Math.min(w, cap), 0);
        }
        const fitted = need.map(w => Math.min(w, cap));
        // What is left goes to the last column.
        fitted[n - 1] += Math.max(0, room - sum);
        return fitted.map(Math.floor);
    }

    function copyText(text) {
        NetTools.copy(text);
        copied = text;
        copiedTimer.restart();
    }

    onToolChanged: copied = ""
    onShownChanged: {
        revealAnimation.stop();
        revealAnimation.to = shown ? 1 : 0;
        revealAnimation.duration = shown ? 420 : 220;
        revealAnimation.easing.bezierCurve = shown ? [0.2, 0, 0, 1, 1, 1] : [0.3, 0, 0.8, 0.15, 1, 1];
        revealAnimation.start();
    }

    width: panelWidth - 28 * (1 - reveal)
    height: shownHeight * reveal
    clip: true
    radius: 28
    border.width: 1
    border.color: Theme.panelEdge
    color: "transparent"
    gradient: Gradient {
        GradientStop {
            position: 0
            color: Qt.alpha(Theme.glassBase, Math.max(0.7, Theme.glassOpacity))
        }
        GradientStop {
            position: 1
            color: Qt.alpha(Theme.glassBase, Math.max(0.58, Theme.glassOpacity))
        }
    }
    opacity: Math.min(1, reveal * 2.5)
    visible: reveal > 0

    NumberAnimation {
        id: revealAnimation

        target: root
        property: "reveal"
        easing.type: Easing.BezierSpline
    }

    Behavior on shownHeight {
        enabled: root.reveal >= 1

        NumberAnimation {
            duration: 380
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.25, 1.1, 0.35, 1, 1, 1]
        }
    }

    Timer {
        id: copiedTimer

        interval: 1800
        onTriggered: root.copied = ""
    }

    // A click inside must not reach the catcher behind it, which closes the menu.
    MouseArea {
        anchors.fill: parent
    }

    component Tile: Rectangle {
        id: tile

        required property var modelData
        required property int index
        readonly property var reading: NetTools.data[modelData.id] || null
        readonly property string state: reading ? reading.state || "" : ""
        readonly property color tone: NetTools.stateColor(state)

        // A tile left alone in the last row takes the whole row.
        readonly property bool alone: index === NetTools.tools.length - 1 && NetTools.tools.length % 4 === 1

        width: alone ? home.width : (home.width - 10 * 3) / 4
        height: 86
        radius: 22
        color: state === "bad" || state === "warn" ? Qt.alpha(tone, tileArea.containsMouse ? 0.2 : 0.12) : Qt.alpha(Theme.text, tileArea.containsMouse ? 0.12 : 0.06)
        scale: tileArea.pressed ? 0.95 : 1
        opacity: 0
        transform: Translate {
            id: tileShift
        }

        Behavior on color {
            ColorAnimation {
                duration: 200
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutBack
                easing.overshoot: 2.2
            }
        }

        function play() {
            rise.stop();
            opacity = 0;
            tileShift.y = 8;
            rise.start();
        }
        Component.onCompleted: {
            if (root.shown)
                play();
        }
        Connections {
            target: root

            function onShownChanged() {
                if (root.shown)
                    tile.play();
            }
        }
        SequentialAnimation {
            id: rise

            PauseAnimation {
                duration: 90 + tile.index * 14
            }
            ParallelAnimation {
                NumberAnimation {
                    target: tile
                    property: "opacity"
                    to: 1
                    duration: 260
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: tileShift
                    property: "y"
                    to: 0
                    duration: 360
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]
                }
            }
        }

        Rectangle {
            x: 12
            y: 12
            width: 30
            height: 30
            radius: 15
            color: Qt.alpha(tile.state !== "" ? tile.tone : Theme.text, 0.14)

            Icon {
                anchors.centerIn: parent
                name: tile.modelData.icon
                size: 16
                color: tile.state !== "" ? tile.tone : Theme.text
            }
        }
        // A reading still on its way.
        Rectangle {
            x: parent.width - 18
            y: 14
            width: 6
            height: 6
            radius: 3
            color: Theme.accent
            visible: !!NetTools.busy[tile.modelData.id]

            SequentialAnimation on opacity {
                running: parent.visible
                loops: Animation.Infinite
                NumberAnimation {
                    to: 0.2
                    duration: 450
                }
                NumberAnimation {
                    to: 1
                    duration: 450
                }
            }
        }
        Label {
            x: 12
            y: 48
            width: parent.width - 24
            text: Tr.t(tile.modelData.title)
            size: 11
            color: Theme.muted
            elide: Text.ElideRight
        }
        Label {
            x: 12
            y: 63
            width: parent.width - 24
            // Bluetooth and the clipboard are read only when their table opens.
            text: tile.reading ? (tile.reading.error ? "—" : tile.reading.badge || "→") : tile.modelData.every > 0 ? "…" : Tr.t("open")
            size: 12
            font.family: Theme.mono
            font.weight: Font.DemiBold
            color: tile.state !== "" ? tile.tone : Theme.text
            elide: Text.ElideRight
        }
        MouseArea {
            id: tileArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: NetTools.show(tile.modelData.id)
        }
    }

    // Keeps its size while the menu grows, so nothing inside reflows.
    Item {
        x: (root.width - width) / 2
        width: root.panelWidth
        height: root.pageHeight

        // The hub: every reading as a tile.
        Column {
            id: home

            x: root.padding
            y: root.padding
            width: parent.width - root.padding * 2
            spacing: 14
            visible: opacity > 0
            opacity: root.tool === "" ? 1 : 0
            transform: Translate {
                x: root.tool === "" ? 0 : -28

                Behavior on x {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                }
            }

            Reveal {
                shown: root.shown
                calm: true
                delay: 40

                Item {
                    width: parent.width
                    height: 40

                    Rectangle {
                        id: hubMark

                        width: 40
                        height: 40
                        radius: 20
                        color: NetTools.alert !== "" ? Qt.alpha(NetTools.stateColor(NetTools.alert), 0.18) : Qt.alpha(Theme.accent, 0.18)

                        Icon {
                            anchors.centerIn: parent
                            name: "radar"
                            size: 20
                            color: NetTools.alert !== "" ? NetTools.stateColor(NetTools.alert) : Theme.accent
                        }
                    }
                    Column {
                        x: hubMark.width + 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - x

                        Label {
                            text: Tr.t("Network and security")
                            font.family: Theme.display
                            size: 15
                            font.weight: Font.DemiBold
                        }
                        Label {
                            width: parent.width
                            text: NetTools.alert === "bad" ? Tr.t("Something needs a look: it is marked red") : NetTools.alert === "warn" ? Tr.t("Worth a look: marked yellow") : Tr.t("All quiet")
                            size: 11
                            color: NetTools.alert !== "" ? NetTools.stateColor(NetTools.alert) : Theme.muted
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Flow {
                width: parent.width
                spacing: 10

                Repeater {
                    model: NetTools.tools

                    delegate: Tile {}
                }
            }

            Label {
                width: parent.width
                text: Tr.t("A tile opens its table")
                size: 10
                color: Qt.alpha(Theme.muted, 0.8)
            }
        }

        // One reading's table.
        Column {
            id: detail

            x: root.padding
            y: root.padding
            width: parent.width - root.padding * 2
            spacing: 10
            visible: opacity > 0
            opacity: root.tool !== "" ? 1 : 0
            transform: Translate {
                x: root.tool !== "" ? 0 : 28

                Behavior on x {
                    NumberAnimation {
                        duration: 360
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.25, 1.2, 0.35, 1, 1, 1]
                    }
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                }
            }

            Item {
                width: parent.width
                height: 32

                PageHeader {
                    width: parent.width - 40
                    title: root.info && root.info.title ? root.info.title : Tr.t((NetTools.byId[root.tool] || {}).title || "")
                    hasSwitch: false
                    onBack: NetTools.show("")
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

            // The reading in brief: icon in its color and the summary.
            Rectangle {
                width: parent.width
                height: 50
                radius: 18
                color: Qt.alpha(NetTools.colorOf(root.tool), root.info && root.info.state ? 0.12 : 0.05)

                Icon {
                    x: 16
                    anchors.verticalCenter: parent.verticalCenter
                    name: NetTools.iconOf(root.tool)
                    size: 18
                    color: NetTools.colorOf(root.tool)
                }
                Label {
                    x: 46
                    width: parent.width - x - 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: !root.info ? (root.tool === "lan" ? Tr.t("Looking for devices…") : root.tool === "bt" ? Tr.t("Scanning for 6 seconds…") : Tr.t("Reading…")) : root.info.error || root.info.summary || ""
                    size: 13
                    font.weight: Font.Medium
                    color: root.info && root.info.error ? Theme.error : Theme.text
                    elide: Text.ElideRight
                }
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

                            width: (root.widths[index] || 40)
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

                                            width: (root.widths[index] || 40)
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
}
