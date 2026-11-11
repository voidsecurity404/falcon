import QtQuick
import Quickshell
import Quickshell.Io
import qs.components
import qs.services

// The terminal layout's dashboard: a console that drops from under the bar across the screen,
// as in old shooters, then types its lines in. Three columns of text: who and where (user, host,
// kernel, uptime, date, weather), what the machine does (bars of block characters, a load
// line, the busiest programs) and what plays (the song, its place, its levels, the last
// notifications). A prompt with a blinking cursor ends it.
Rectangle {
    id: root

    property bool shown: false
    property real t: 0
    property real typed: 0
    readonly property int fullHeight: 500
    readonly property int bars: 24
    readonly property string user: Quickshell.env("USER") || "user"
    readonly property string host: hostFile.text().trim() || "falcon"
    readonly property var busiest: Processes.pids.map(pid => Processes.byPid[pid]).filter(p => !!p).sort((a, b) => b.cpu - a.cpu).slice(0, 6)

    onShownChanged: {
        drop.stop();
        type.stop();
        drop.to = shown ? 1 : 0;
        drop.duration = shown ? 260 : 180;
        drop.easing.type = shown ? Easing.OutCubic : Easing.InCubic;
        drop.start();
        if (shown) {
            Ui.dashTab = 2;
            uptimeFile.reload();
            typed = 0;
            type.start();
        }
        Spectrum.setWatching("term-dash", shown);
    }

    NumberAnimation {
        id: drop

        target: root
        property: "t"
    }
    NumberAnimation {
        id: type

        target: root
        property: "typed"
        from: 0
        to: 1
        duration: 1100
    }

    FileView {
        id: hostFile

        path: "/proc/sys/kernel/hostname"
    }
    FileView {
        id: kernelFile

        path: "/proc/sys/kernel/osrelease"
    }
    FileView {
        id: uptimeFile

        path: "/proc/uptime"
    }
    Timer {
        interval: 30000
        repeat: true
        running: root.shown
        onTriggered: uptimeFile.reload()
    }
    SystemClock {
        id: clock

        precision: SystemClock.Seconds
    }

    function bar(share, width) {
        const n = Math.round(Math.max(0, Math.min(1, share)) * width);
        return "[" + "|".repeat(n) + " ".repeat(width - n) + "]";
    }
    function spark(values, count) {
        const blocks = "▁▂▃▄▅▆▇█";
        return values.slice(-count).map(v => blocks[Math.max(0, Math.min(7, Math.floor(v / 12.5)))]).join("");
    }
    function uptime() {
        const s = Number((uptimeFile.text() || "0").split(" ")[0]);
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
        return (d > 0 ? d + "d " : "") + h + "h " + m + "m";
    }
    function time(seconds) {
        const s = Math.max(0, Math.floor(seconds));
        return Math.floor(s / 60) + ":" + Ui.pad(s % 60);
    }

    height: fullHeight * t
    visible: t > 0.001
    clip: true
    color: Qt.alpha(Theme.glassBase, Math.max(0.93, Theme.glassOpacity))
    bottomLeftRadius: 8
    bottomRightRadius: 8
    border.width: 1
    border.color: Qt.alpha(Theme.accent, 0.5)

    MouseArea {
        anchors.fill: parent
    }

    component Mono: Text {
        font.family: Theme.mono
        font.pixelSize: 13
        color: Theme.text
        textFormat: Text.PlainText
    }

    // A line that types itself in, after the lines before it.
    component TypeLine: Mono {
        id: line

        property string full: ""
        property int order: 0
        readonly property real share: Math.max(0, Math.min(1, root.typed * 34 - order))

        text: share >= 1 ? full : full.slice(0, Math.floor(full.length * share))
        visible: share > 0
    }

    component Heading: TypeLine {
        color: Theme.accent
        font.bold: true
    }

    // The content keeps its size and hangs from the bottom edge, so it slides down with it.
    Item {
        y: root.height - root.fullHeight
        width: parent.width
        height: root.fullHeight

        // A header strip like a program's title line.
        Rectangle {
            width: parent.width
            height: 26
            color: Qt.alpha(Theme.accent, 0.16)

            Mono {
                x: 16
                anchors.verticalCenter: parent.verticalCenter
                text: root.user + "@" + root.host + ": ~/dashboard"
                color: Theme.accent
                font.bold: true
            }
            Mono {
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: "tab: next · esc: close"
                color: Theme.muted
            }
        }

        Row {
            x: 24
            y: 44
            width: parent.width - 48
            height: parent.height - 44 - 52
            spacing: 36

            // ---------------- who and where
            Column {
                width: (parent.width - 72) * 0.28
                spacing: 3

                Heading {
                    order: 0
                    full: root.user + "@" + root.host
                }
                TypeLine {
                    order: 1
                    full: "-".repeat((root.user + "@" + root.host).length)
                    color: Theme.muted
                }
                Repeater {
                    model: [
                        ["kernel", kernelFile.text().trim()],
                        ["uptime", root.uptime()],
                        ["wm", "niri"],
                        ["shell", (Quickshell.env("SHELL") || "").split("/").pop()],
                        ["date", Qt.formatDate(clock.date, "yyyy-MM-dd")],
                        ["time", Ui.pad(clock.hours) + ":" + Ui.pad(clock.minutes) + ":" + Ui.pad(clock.seconds)],
                        ["weather", Weather.hasData ? Weather.temperature + "°C " + Weather.describe(Weather.code).toLowerCase() : "n/a"],
                        ["battery", Sys.hasBattery ? Sys.batteryPercent + "%" + (Sys.charging ? " (charging)" : "") : "n/a"]
                    ]

                    delegate: Row {
                        required property var modelData
                        required property int index

                        TypeLine {
                            order: 2 + index
                            full: (modelData[0] + "          ").slice(0, 9)
                            color: Theme.accent
                        }
                        TypeLine {
                            order: 2 + index
                            full: modelData[1]
                        }
                    }
                }
                Item {
                    width: 1
                    height: 10
                }
                // The palette, like a fetch program ends with.
                Row {
                    opacity: root.typed > 0.4 ? 1 : 0

                    Repeater {
                        model: [Theme.error, Theme.good, Theme.accent, Theme.hueShift(Theme.accent, 0.2), Theme.hueShift(Theme.accent, 0.4), Theme.text, Theme.muted]

                        delegate: Rectangle {
                            required property color modelData

                            width: 22
                            height: 14
                            color: modelData
                        }
                    }
                }
            }

            // ---------------- the machine
            Column {
                width: (parent.width - 72) * 0.38
                spacing: 3

                Heading {
                    order: 3
                    full: "top"
                }
                Repeater {
                    model: [
                        ["cpu ", Sys.cpu / 100, Sys.cpu + "%"],
                        ["mem ", Sys.ram / 100, Sys.ramGb.toFixed(1) + "/" + Sys.ramTotalGb.toFixed(0) + "G"],
                        ["temp", Sys.temperature / 100, Sys.temperature > 0 ? Sys.temperature + "°C" : "n/a"],
                        ["disk", Sys.disk / 100, Sys.diskFreeGb.toFixed(0) + "G free"]
                    ]

                    delegate: Row {
                        required property var modelData
                        required property int index

                        spacing: 8

                        TypeLine {
                            order: 4 + index
                            full: modelData[0]
                            color: Theme.accent
                        }
                        TypeLine {
                            order: 4 + index
                            full: root.bar(modelData[1], root.bars)
                            color: modelData[1] >= 0.85 ? Theme.error : Theme.good
                        }
                        TypeLine {
                            order: 4 + index
                            full: modelData[2]
                        }
                    }
                }
                Row {
                    spacing: 8

                    TypeLine {
                        order: 8
                        full: "load"
                        color: Theme.accent
                    }
                    TypeLine {
                        order: 8
                        full: root.spark(Sys.history, 36)
                        color: Theme.accent
                    }
                }
                Item {
                    width: 1
                    height: 8
                }
                TypeLine {
                    order: 9
                    full: "  PID  CPU%  NAME"
                    color: Theme.muted
                    font.bold: true
                }
                Repeater {
                    model: root.busiest

                    delegate: TypeLine {
                        required property var modelData
                        required property int index

                        order: 10 + index
                        full: String(modelData.pid || "").padStart(5, " ") + String(modelData.cpu.toFixed(1)).padStart(6, " ") + "  " + modelData.name
                        color: index === 0 ? Theme.text : Qt.alpha(Theme.text, 0.8)
                    }
                }
            }

            // ---------------- what plays, what came
            Column {
                width: (parent.width - 72) * 0.34
                spacing: 3

                Heading {
                    order: 5
                    full: "now playing"
                }
                TypeLine {
                    order: 6
                    width: parent.width
                    elide: Text.ElideRight
                    full: Media.player ? "♪ " + Media.title : "♪ nothing"
                }
                TypeLine {
                    order: 7
                    width: parent.width
                    elide: Text.ElideRight
                    visible: !!Media.player && share > 0
                    full: Media.player ? "  " + Media.player.trackArtist : ""
                    color: Theme.muted
                }
                TypeLine {
                    order: 8
                    visible: !!Media.player && share > 0
                    full: {
                        const p = Media.player;
                        if (!p)
                            return "";
                        const n = Math.round(Math.max(0, Math.min(1, Media.progress)) * 22);
                        return "[" + "=".repeat(Math.max(0, n - 1)) + (n > 0 ? ">" : "") + "-".repeat(22 - n) + "] " + root.time(p.position) + "/" + root.time(p.length);
                    }
                }
                // Levels of the sound as block characters.
                Mono {
                    visible: !!Media.player && root.typed > 0.3
                    text: Spectrum.levels.length > 0 ? root.spark(Spectrum.levels, 36) : ""
                    color: Media.artAccent
                    font.pixelSize: 16
                }
                Row {
                    spacing: 10
                    visible: root.typed > 0.3

                    Repeater {
                        model: [["prev", "previous"], [Media.player && Media.player.isPlaying ? "pause" : "play", "play"], ["next", "next"]]

                        delegate: Mono {
                            id: control

                            required property var modelData

                            text: "[" + modelData[0] + "]"
                            color: controlArea.containsMouse ? Theme.accent : Theme.text
                            opacity: Media.player ? 1 : 0.4

                            MouseArea {
                                id: controlArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const p = Media.player;
                                    if (!p)
                                        return;
                                    if (control.modelData[1] === "previous")
                                        p.previous();
                                    else if (control.modelData[1] === "next")
                                        p.next();
                                    else
                                        p.togglePlaying();
                                }
                            }
                        }
                    }
                }
                Item {
                    width: 1
                    height: 10
                }
                Heading {
                    order: 11
                    full: "journal"
                }
                TypeLine {
                    order: 12
                    visible: Toasts.history.length === 0 && share > 0
                    full: "-- no entries --"
                    color: Theme.muted
                }
                Repeater {
                    model: Toasts.history.slice(0, 7)

                    delegate: TypeLine {
                        required property var modelData
                        required property int index

                        order: 12 + index
                        width: parent.width
                        elide: Text.ElideRight
                        full: modelData.time + " " + (modelData.app ? modelData.app.toLowerCase().replace(/ /g, "-") : "system") + ": " + modelData.title + (modelData.sub ? " — " + modelData.sub : "")
                        color: index === 0 ? Theme.text : Qt.alpha(Theme.text, 0.75)

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Toasts.forget([modelData.id])
                        }
                    }
                }
            }
        }

        // The prompt.
        Row {
            x: 24
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18
            spacing: 0
            visible: root.typed > 0.6

            Mono {
                text: root.user + "@" + root.host
                color: Theme.good
                font.bold: true
            }
            Mono {
                text: " ~ "
                color: Theme.accent
                font.bold: true
            }
            Mono {
                text: "$ "
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 8
                height: 16
                color: Theme.text

                SequentialAnimation on opacity {
                    running: root.shown
                    loops: Animation.Infinite

                    NumberAnimation {
                        to: 0
                        duration: 1
                    }
                    PauseAnimation {
                        duration: 530
                    }
                    NumberAnimation {
                        to: 1
                        duration: 1
                    }
                    PauseAnimation {
                        duration: 530
                    }
                }
            }
        }
    }
}
