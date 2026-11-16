import QtQuick
import Quickshell.Io
import qs.components
import qs.services

// The processor's last two minutes as a graph, with memory, disk, temperature and the network beside it.
// Forms: wide, tall, compact.
Item {
    id: root

    readonly property bool widgetRoot: true
    property string widgetId: ""
    property string form: "wide"
    readonly property bool tall: form === "tall"
    readonly property bool compact: form === "compact"
    readonly property color memColor: Theme.hueShift(Theme.accent, 0.18)
    readonly property color diskColor: Theme.hueShift(Theme.accent, 0.36)
    readonly property color netColor: Theme.hueShift(Theme.accent, 0.82)
    readonly property color hot: Sys.temperature >= 80 ? Theme.error : Sys.temperature >= 65 ? Theme.hueShift(Theme.accent, 0.92) : Theme.good

    property real down: 0
    property real up: 0
    property var downHistory: []
    property var upHistory: []
    // Over this the frame glows red.
    readonly property bool overheat: Sys.temperature >= 85
    // A press on the processor shows what loads it. Shared, so the face shows it too.
    readonly property bool showTop: Widgets.sharedValue(widgetId, "top", false)

    onShowTopChanged: {
        Processes.watch(showTop ? 1 : -1);
        if (showTop)
            topClose.restart();
    }
    Component.onDestruction: {
        if (showTop)
            Processes.watch(-1);
    }
    Timer {
        id: topClose

        interval: 20000
        onTriggered: Widgets.share(root.widgetId, "top", false)
    }
    property var last: null
    property string uptime: ""

    function speed(bytes) {
        if (bytes >= 1048576)
            return (bytes / 1048576).toFixed(bytes >= 10485760 ? 0 : 1) + " " + Tr.t("MB/s");
        return Math.round(bytes / 1024) + " " + Tr.t("KB/s");
    }

    FileView {
        id: netFile

        path: "/proc/net/dev"
        printErrors: false
        onLoaded: {
            let rx = 0, tx = 0;
            for (const line of text().split("\n").slice(2)) {
                const parts = line.trim().split(/[:\s]+/);
                if (parts.length < 10 || parts[0] === "lo" || parts[0].startsWith("docker") || parts[0].startsWith("veth"))
                    continue;
                rx += Number(parts[1]);
                tx += Number(parts[9]);
            }
            const t = Date.now();
            if (root.last) {
                const dt = Math.max(0.5, (t - root.last.t) / 1000);
                root.down = Math.max(0, (rx - root.last.rx) / dt);
                root.up = Math.max(0, (tx - root.last.tx) / dt);
                root.downHistory = root.downHistory.concat([root.down]).slice(-40);
                root.upHistory = root.upHistory.concat([root.up]).slice(-40);
            }
            root.last = { t: t, rx: rx, tx: tx };
        }
    }
    FileView {
        id: upFile

        path: "/proc/uptime"
        printErrors: false
        onLoaded: {
            const s = Math.floor(Number(text().split(" ")[0]));
            const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
            root.uptime = (d > 0 ? d + Tr.t("d") + " " : "") + h + Tr.t("h") + " " + m + Tr.t("m");
        }
    }
    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            netFile.reload();
            upFile.reload();
        }
    }

    component Meter: Item {
        id: meter

        property string icon: ""
        property string title: ""
        property string value: ""
        property real share: 0
        property color tint: Theme.accent

        width: parent ? parent.width : 0
        height: 44

        Row {
            spacing: 6

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: meter.icon
                size: 13
                color: meter.tint
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: meter.title
                size: 12
                color: Theme.muted
            }
        }
        Label {
            anchors.right: parent.right
            text: meter.value
            size: 12
            font.weight: Font.DemiBold
        }
        Rectangle {
            y: 24
            width: parent.width
            height: 8
            radius: 4
            color: Qt.alpha(meter.tint, 0.15)

            Rectangle {
                width: Math.max(8, parent.width * Math.min(1, meter.share))
                height: parent.height
                radius: 4
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0
                        color: Qt.alpha(meter.tint, 0.6)
                    }
                    GradientStop {
                        position: 1
                        color: meter.tint
                    }
                }

                Behavior on width {
                    NumberAnimation {
                        duration: 600
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------------- compact: three rings
    Row {
        visible: root.compact
        anchors.centerIn: parent
        spacing: 22

        Repeater {
            model: [
                { title: Tr.t("CPU"), value: Sys.cpu / 100, text: Sys.cpu + "%", color: Theme.accent },
                { title: Tr.t("Memory"), value: Sys.ram / 100, text: Sys.ram + "%", color: root.memColor },
                { title: Tr.t("Temp"), value: Sys.temperature / 100, text: Sys.temperature + "°", color: root.hot }
            ]

            Column {
                required property var modelData

                spacing: 6

                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 76
                    height: 76

                    Ring {
                        anchors.fill: parent
                        thickness: 8
                        value: modelData.value
                        color: modelData.color
                    }
                    Label {
                        anchors.centerIn: parent
                        text: modelData.text
                        size: 15
                        font.weight: Font.Bold
                    }
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData.title
                    size: 11
                    color: Theme.muted
                }
            }
        }
    }

    // ---------------------------------------------------------------- processor with graph
    Item {
        id: cpu

        visible: !root.compact
        x: 20
        y: 18
        width: root.tall ? root.width - 40 : 230
        height: root.tall ? 150 : root.height - 36

        WidgetCaption {
            icon: "chip"
            text: Tr.t("Processor")
        }
        Row {
            y: 32
            spacing: 10

            Text {
                text: Sys.cpu
                font.family: Theme.display
                font.pixelSize: 44
                font.weight: Font.DemiBold
                color: Theme.text

                Text {
                    anchors.left: parent.right
                    anchors.leftMargin: 2
                    anchors.top: parent.top
                    anchors.topMargin: 8
                    text: "%"
                    font.family: Theme.display
                    font.pixelSize: 18
                    color: Theme.muted
                }
            }
        }
        Rectangle {
            anchors.right: parent.right
            y: 40
            width: tempRow.implicitWidth + 16
            height: 26
            radius: 13
            color: Qt.alpha(root.hot, 0.16)

            Row {
                id: tempRow

                anchors.centerIn: parent
                spacing: 4

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "thermo"
                    size: 13
                    color: root.hot
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Sys.temperature + "°"
                    size: 12
                    font.weight: Font.DemiBold
                    color: root.hot
                }
            }
        }
        WidgetSpark {
            y: 92
            width: parent.width
            height: parent.height - y
            visible: opacity > 0
            opacity: root.showTop ? 0 : 1
            values: Sys.history.length > 1 ? Sys.history : [Sys.cpu, Sys.cpu]
            max: 100

            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                }
            }
        }
        // The three busiest processes, in place of the graph while asked for.
        Column {
            y: 84
            width: parent.width
            spacing: 4
            visible: opacity > 0
            opacity: root.showTop ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                }
            }

            Label {
                visible: Processes.top3.length === 0
                text: Tr.t("Measuring…")
                size: 12
                color: Theme.muted
            }
            Repeater {
                model: Processes.top3

                Item {
                    id: proc

                    required property var modelData
                    required property int index

                    width: parent.width
                    height: 24

                    Rectangle {
                        anchors.fill: parent
                        radius: 8
                        color: Qt.alpha(Theme.accent, 0.06 + 0.1 * Math.min(1, proc.modelData.cpu / 100))
                    }
                    Rectangle {
                        width: Math.max(6, parent.width * Math.min(1, proc.modelData.cpu / 100))
                        height: parent.height
                        radius: 8
                        color: Qt.alpha(proc.index === 0 ? Theme.accent : Theme.text, 0.14)
                    }
                    Label {
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 70
                        text: proc.modelData.name
                        size: 12
                        font.weight: proc.index === 0 ? Font.DemiBold : Font.Normal
                        elide: Text.ElideRight
                    }
                    Label {
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(proc.modelData.cpu) + "%"
                        size: 12
                        font.weight: Font.DemiBold
                        color: proc.index === 0 ? Theme.accent : Theme.text
                    }
                }
            }
        }
        WidgetHot {
            anchors.fill: parent
            onClicked: Widgets.share(root.widgetId, "top", !root.showTop)
        }
    }

    // ---------------------------------------------------------------- memory, disk, network
    Column {
        visible: !root.compact
        x: root.tall ? 20 : cpu.x + cpu.width + 26
        y: root.tall ? cpu.y + cpu.height + 14 : 20
        width: root.width - x - 20
        spacing: 8

        Label {
            visible: !root.tall
            anchors.right: parent.right
            text: Tr.t("Up") + " " + root.uptime
            size: 11
            color: Theme.muted
        }
        Meter {
            icon: "memory"
            title: Tr.t("Memory")
            value: Sys.ramGb.toFixed(1) + " / " + Math.round(Sys.ramTotalGb) + " " + Tr.t("GB")
            share: Sys.ram / 100
            tint: root.memColor
        }
        Meter {
            icon: "folder"
            title: Tr.t("Disk")
            value: Sys.diskFreeGb + " " + Tr.t("GB free")
            share: Sys.disk / 100
            tint: root.diskColor
        }
        Item {
            width: parent.width
            height: 44

            // Download filled, upload as a line over it, on one scale.
            WidgetSpark {
                anchors.fill: parent
                values: root.downHistory.length > 1 ? root.downHistory : [0, 0]
                max: Math.max(65536, ...root.downHistory, ...root.upHistory) * 1.15
                color: root.netColor
                lineWidth: 1.6
                fillAlpha: 0.25
                dot: false
                opacity: 0.8
            }
            WidgetSpark {
                anchors.fill: parent
                values: root.upHistory.length > 1 ? root.upHistory : [0, 0]
                max: Math.max(65536, ...root.downHistory, ...root.upHistory) * 1.15
                color: Theme.hueShift(Theme.accent, 0.5)
                lineWidth: 1.4
                fillAlpha: 0
                dot: false
                opacity: 0.85
            }
            Row {
                y: 2
                spacing: 12

                Row {
                    spacing: 4

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "arrowDown"
                        size: 12
                        color: root.netColor
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.speed(root.down)
                        size: 12
                        font.weight: Font.DemiBold
                    }
                }
                Row {
                    spacing: 4

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "arrowUp"
                        size: 12
                        color: Theme.hueShift(Theme.accent, 0.5)
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.speed(root.up)
                        size: 12
                        color: Theme.muted
                    }
                }
            }
        }
    }

    // A red glow around the widget while the processor is too hot.
    Rectangle {
        anchors.fill: parent
        radius: 22
        color: "transparent"
        border.width: 2
        border.color: Theme.error
        visible: root.overheat
        opacity: 0.4 + 0.6 * pulse

        property real pulse: 0

        SequentialAnimation on pulse {
            running: root.overheat
            loops: Animation.Infinite

            NumberAnimation {
                to: 1
                duration: 900
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                to: 0
                duration: 900
                easing.type: Easing.InOutSine
            }
        }
    }
    Rectangle {
        visible: root.overheat && !root.compact
        anchors.horizontalCenter: parent.horizontalCenter
        y: -height / 2
        width: hotText.implicitWidth + 20
        height: 22
        radius: 11
        color: Theme.error

        Label {
            id: hotText

            anchors.centerIn: parent
            text: Tr.t("Too hot") + " · " + Sys.temperature + "°"
            size: 11
            font.weight: Font.DemiBold
            color: "white"
        }
    }
}
