import QtQuick
import Quickshell.Io
import qs.components
import qs.services

// Download and upload speed of all network devices. Forms: wide (with a graph), compact.
Item {
    id: root

    property string form: "wide"
    readonly property bool compact: form === "compact"
    readonly property color downColor: Theme.accent
    readonly property color upColor: Theme.hueShift(Theme.accent, 0.45)
    property real down: 0
    property real up: 0
    property var downHistory: []
    property var upHistory: []
    property var before: null

    function speed(bytes) {
        if (bytes >= 1048576)
            return (bytes / 1048576).toFixed(1) + " " + Tr.t("MB/s");
        return Math.round(bytes / 1024) + " " + Tr.t("KB/s");
    }

    function read(content) {
        let rx = 0;
        let tx = 0;
        for (const line of content.split("\n").slice(2)) {
            const parts = line.trim().split(/[:\s]+/);
            if (parts.length < 10 || parts[0] === "lo")
                continue;
            rx += Number(parts[1]);
            tx += Number(parts[9]);
        }
        const now = Date.now();
        if (before && now > before.at) {
            const seconds = (now - before.at) / 1000;
            down = Math.max(0, (rx - before.rx) / seconds);
            up = Math.max(0, (tx - before.tx) / seconds);
            downHistory = downHistory.concat([down]).slice(-40);
            upHistory = upHistory.concat([up]).slice(-40);
            graph.requestPaint();
        }
        before = {
            rx: rx,
            tx: tx,
            at: now
        };
    }

    FileView {
        id: dev

        path: "/proc/net/dev"
        printErrors: false
        onLoaded: root.read(text())
    }
    Timer {
        interval: 1500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: dev.reload()
    }

    Canvas {
        id: graph

        visible: !root.compact
        x: 16
        y: 78
        width: parent.width - 32
        height: parent.height - y - 14
        renderStrategy: Canvas.Cooperative
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const top = Math.max(1024 * 64, ...root.downHistory, ...root.upHistory);
            const draw = (values, color) => {
                if (values.length < 2)
                    return;
                ctx.beginPath();
                values.forEach((v, i) => {
                    const x = width - (values.length - 1 - i) * width / 39;
                    const y = height - 2 - Math.sqrt(v / top) * (height - 4);
                    if (i === 0)
                        ctx.moveTo(x, y);
                    else
                        ctx.lineTo(x, y);
                });
                ctx.lineWidth = 2.2;
                ctx.lineJoin = "round";
                ctx.strokeStyle = color;
                ctx.stroke();
            };
            draw(root.upHistory, root.upColor);
            draw(root.downHistory, root.downColor);
        }
    }
    Row {
        x: 20
        y: root.compact ? (parent.height - height) / 2 : 16
        spacing: 20

        Repeater {
            model: [
                { icon: "arrowDown", tint: root.downColor, value: root.down },
                { icon: "arrowUp", tint: root.upColor, value: root.up }
            ]

            delegate: Row {
                id: figure

                required property var modelData

                spacing: 8

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    height: 32
                    radius: 16
                    color: Qt.alpha(figure.modelData.tint, 0.2)

                    Icon {
                        anchors.centerIn: parent
                        name: figure.modelData.icon
                        size: 16
                        color: figure.modelData.tint
                    }
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.compact ? 76 : 112
                    text: root.speed(figure.modelData.value)
                    size: root.compact ? 14 : 18
                    font.weight: Font.DemiBold
                }
            }
        }
    }
}
