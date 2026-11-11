import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.services

// The rail layout's dashboard, a drawer beside the rail: its own row of page icons down the
// left (Today, Music, System, Notifications) with a pill that stretches between them, and pages
// that slide up and down. Today greets and gives the week's weather, Music spins a record,
// System has dials, the load and the busiest programs.
Item {
    id: root

    property int page: Ui.dashTab
    readonly property bool open: Ui.popup === "dashboard" && visible
    readonly property int navWidth: 76
    readonly property var pages: [
        {
            icon: "clock",
            title: Tr.t("Today")
        },
        {
            icon: "music",
            title: Tr.t("Music")
        },
        {
            icon: "chip",
            title: Tr.t("System")
        },
        {
            icon: "bell",
            title: Tr.t("Notifications")
        }
    ]

    function select(i) {
        page = (i + pages.length) % pages.length;
        // The services follow the first three pages, the notifications need none.
        Ui.dashTab = page < 3 ? page : 0;
    }

    focus: true
    Keys.onEscapePressed: Ui.popup = ""
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
            select(page + 1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
            select(page - 1);
            event.accepted = true;
        } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_4) {
            select(event.key - Qt.Key_1);
            event.accepted = true;
        }
    }
    onVisibleChanged: {
        if (visible)
            focusLater.restart();
    }
    Timer {
        id: focusLater

        interval: 60
        onTriggered: root.forceActiveFocus()
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    // ------------------------------------------------ the page icons
    Item {
        id: nav

        width: root.navWidth
        height: parent.height

        Rectangle {
            anchors.right: parent.right
            width: 1
            height: parent.height
            color: Qt.alpha(Theme.text, 0.08)
        }

        readonly property int step: 72
        readonly property int firstY: (height - root.pages.length * step) / 2

        Rectangle {
            property real head: nav.firstY + root.page * nav.step
            property real tail: nav.firstY + root.page * nav.step

            x: 14
            y: Math.min(head, tail) + 6
            width: nav.width - 28
            height: Math.abs(head - tail) + 34
            radius: 17
            color: Qt.alpha(Theme.accent, 0.28)

            Behavior on head {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on tail {
                NumberAnimation {
                    duration: 460
                    easing.type: Easing.OutCubic
                }
            }
        }

        Repeater {
            model: root.pages

            delegate: Item {
                id: navItem

                required property var modelData
                required property int index

                y: nav.firstY + index * nav.step
                width: nav.width
                height: nav.step

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 14
                    name: navItem.modelData.icon
                    size: 20
                    color: root.page === navItem.index ? Theme.accent : navArea.containsMouse ? Theme.text : Theme.muted
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 46
                    width: parent.width - 6
                    horizontalAlignment: Text.AlignHCenter
                    text: navItem.modelData.title
                    size: 10
                    elide: Text.ElideRight
                    font.weight: root.page === navItem.index ? Font.DemiBold : Font.Normal
                    color: root.page === navItem.index ? Theme.text : Theme.muted
                }
                MouseArea {
                    id: navArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.select(navItem.index)
                }
            }
        }
    }

    // ------------------------------------------------ the pages, one above the other
    Item {
        id: pager

        x: root.navWidth + 26
        y: 24
        width: root.width - x - 26
        height: root.height - 48
        clip: true

        Item {
            y: -root.page * (pager.height + 30)
            width: pager.width
            height: pager.height

            Behavior on y {
                NumberAnimation {
                    id: slide

                    duration: 520
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.2, 1.05, 0.3, 1, 1, 1]
                }
            }

            // ---------------- today
            Item {
                width: pager.width
                height: pager.height
                visible: root.page === 0 || slide.running

                Column {
                    width: parent.width - 290
                    spacing: 2

                    Label {
                        text: {
                            const h = clock.hours;
                            return h < 5 ? Tr.t("Good night") : h < 12 ? Tr.t("Good morning") : h < 18 ? Tr.t("Good afternoon") : Tr.t("Good evening");
                        }
                        size: 16
                        color: Theme.accent
                        font.weight: Font.Medium
                    }
                    Label {
                        text: Ui.pad(clock.hours) + ":" + Ui.pad(clock.minutes)
                        font.family: Theme.display
                        size: 96
                        font.weight: Font.DemiBold
                    }
                    Label {
                        text: Tr.capitalized(clock.date.toLocaleDateString(Tr.locale, "dddd, d MMMM"))
                        size: 17
                        color: Theme.muted
                    }
                }
                Calendar {
                    anchors.right: parent.right
                    y: 8
                    cellWidth: 38
                    cellHeight: 28
                }
                // The week's weather as a row of cards.
                Row {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    spacing: 10
                    visible: Weather.hasData

                    Repeater {
                        model: Weather.daily.slice(0, 7)

                        delegate: Rectangle {
                            id: day

                            required property var modelData
                            required property int index

                            width: (pager.width - 10 * (Math.min(7, Weather.daily.length) - 1)) / Math.max(1, Math.min(7, Weather.daily.length))
                            height: 150
                            radius: 18
                            color: index === 0 ? Qt.alpha(Theme.accent, 0.2) : Qt.alpha(Theme.text, 0.05)

                            Column {
                                anchors.centerIn: parent
                                spacing: 10

                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: day.index === 0 ? Tr.t("Today") : Tr.capitalized(new Date(day.modelData.date).toLocaleDateString(Tr.locale, "ddd"))
                                    size: 12
                                    color: Theme.muted
                                }
                                Icon {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    name: Weather.icon(day.modelData.code, true)
                                    size: 28
                                    color: day.index === 0 ? Theme.accent : Theme.text
                                }
                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: day.modelData.max + "°"
                                    size: 17
                                    font.weight: Font.DemiBold
                                }
                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: day.modelData.min + "°"
                                    size: 12
                                    color: Theme.muted
                                }
                            }
                        }
                    }
                }
            }

            // ---------------- music
            Item {
                id: musicPage

                y: pager.height + 30
                width: pager.width
                height: pager.height
                visible: root.page === 1 || slide.running

                readonly property bool playing: !!Media.player && Media.player.isPlaying

                // A record that turns while the song plays, the cover on its label.
                Item {
                    id: record

                    anchors.verticalCenter: parent.verticalCenter
                    width: 330
                    height: 330

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "#111"
                        border.width: 1
                        border.color: Qt.alpha(Theme.text, 0.15)

                        Repeater {
                            model: 7

                            Rectangle {
                                required property int index

                                anchors.centerIn: parent
                                width: parent.width - 30 - index * 22
                                height: width
                                radius: width / 2
                                color: "transparent"
                                border.width: 1
                                border.color: Qt.alpha("white", 0.06)
                            }
                        }
                    }
                    ClippingRectangle {
                        anchors.centerIn: parent
                        width: 130
                        height: 130
                        radius: 65
                        color: Media.artAccent

                        Image {
                            anchors.fill: parent
                            source: Media.art
                            sourceSize: Qt.size(260, 260)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 12
                        height: 12
                        radius: 6
                        color: Theme.glassBase
                    }
                    RotationAnimator on rotation {
                        from: 0
                        to: 360
                        duration: 9000
                        loops: Animation.Infinite
                        running: musicPage.playing && root.open && root.page === 1
                    }
                }
                Column {
                    x: record.width + 40
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - x
                    spacing: 10

                    Label {
                        width: parent.width
                        text: Media.player ? Media.title : Tr.t("No music")
                        size: 26
                        font.weight: Font.DemiBold
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                    Label {
                        width: parent.width
                        text: Media.player ? Media.player.trackArtist : Tr.t("Play something and it shows here")
                        size: 15
                        color: Theme.muted
                        elide: Text.ElideRight
                    }
                    Item {
                        width: 1
                        height: 10
                    }
                    // The place in the song, a click jumps there.
                    Item {
                        width: parent.width
                        height: 16

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 6
                            radius: 3
                            color: Qt.alpha(Theme.text, 0.14)

                            Rectangle {
                                width: parent.width * Math.max(0, Math.min(1, Media.progress))
                                height: parent.height
                                radius: 3
                                color: Media.artAccent
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => {
                                const p = Media.player;
                                if (p && p.canSeek && p.lengthSupported)
                                    p.position = p.length * mouse.x / width;
                            }
                        }
                    }
                    Row {
                        spacing: 16

                        Repeater {
                            model: ["previous", "play", "next"]

                            delegate: Rectangle {
                                id: control

                                required property string modelData
                                readonly property bool main: modelData === "play"

                                anchors.verticalCenter: parent.verticalCenter
                                width: main ? 64 : 46
                                height: width
                                radius: main ? 22 : 16
                                color: main ? Media.artAccent : Qt.alpha(Theme.text, controlArea.containsMouse ? 0.14 : 0.07)

                                Icon {
                                    anchors.centerIn: parent
                                    name: control.main && musicPage.playing ? "pause" : control.modelData
                                    filled: !control.main || !musicPage.playing
                                    size: control.main ? 24 : 18
                                    color: control.main ? Media.artAccentText : Theme.text
                                }
                                MouseArea {
                                    id: controlArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        const p = Media.player;
                                        if (!p)
                                            return;
                                        if (control.modelData === "previous")
                                            p.previous();
                                        else if (control.modelData === "next")
                                            p.next();
                                        else
                                            p.togglePlaying();
                                    }
                                }
                            }
                        }
                    }
                    SpectrumBars {
                        width: parent.width
                        height: 70
                        active: root.open && root.page === 1
                        color: Media.artAccent
                        mirrored: false
                        gap: 3
                    }
                }
            }

            // ---------------- system
            Item {
                y: 2 * (pager.height + 30)
                width: pager.width
                height: pager.height
                visible: root.page === 2 || slide.running

                readonly property bool live: root.open && root.page === 2

                Row {
                    id: dials

                    spacing: 18

                    Repeater {
                        model: [
                            {
                                label: Tr.t("CPU"),
                                share: Sys.cpu / 100,
                                text: Sys.cpu + "%",
                                hot: Sys.cpu >= 85
                            },
                            {
                                label: Tr.t("Memory"),
                                share: Sys.ram / 100,
                                text: Sys.ramGb.toFixed(1) + " " + Tr.t("GB"),
                                hot: Sys.ram >= 90
                            },
                            {
                                label: Tr.t("Heat"),
                                share: Sys.temperature / 100,
                                text: Sys.temperature > 0 ? Sys.temperature + "°" : "—",
                                hot: Sys.temperature >= 90
                            },
                            {
                                label: Tr.t("Disk"),
                                share: Sys.disk / 100,
                                text: Sys.disk + "%",
                                hot: Sys.disk >= 90
                            }
                        ]

                        delegate: Rectangle {
                            id: dialCard

                            required property var modelData

                            width: (pager.width - 54) / 4
                            height: 170
                            radius: 20
                            color: Qt.alpha(Theme.text, 0.05)

                            TickGauge {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 12
                                width: 120
                                height: 120
                                live: root.open && root.page === 2
                                share: dialCard.modelData.share
                                hot: dialCard.modelData.hot
                                ticks: 32
                                tickLength: 9
                                tickWidth: 3

                                Label {
                                    anchors.centerIn: parent
                                    text: dialCard.modelData.text
                                    size: 17
                                    font.weight: Font.DemiBold
                                }
                            }
                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 138
                                text: dialCard.modelData.label
                                size: 12
                                color: Theme.muted
                            }
                        }
                    }
                }
                Rectangle {
                    y: dials.height + 16
                    width: parent.width * 0.5 - 8
                    height: parent.height - y
                    radius: 20
                    color: Qt.alpha(Theme.text, 0.05)

                    Label {
                        x: 18
                        y: 14
                        text: Tr.t("Load")
                        size: 13
                        color: Theme.muted
                    }
                    LoadChart {
                        x: 14
                        y: 40
                        width: parent.width - 28
                        height: parent.height - 54
                        values: Sys.history
                    }
                }
                // The busiest programs right now.
                Rectangle {
                    x: parent.width * 0.5 + 8
                    y: dials.height + 16
                    width: parent.width * 0.5 - 8
                    height: parent.height - y
                    radius: 20
                    color: Qt.alpha(Theme.text, 0.05)

                    Label {
                        x: 18
                        y: 14
                        text: Tr.t("Busiest")
                        size: 13
                        color: Theme.muted
                    }
                    Column {
                        x: 18
                        y: 40
                        width: parent.width - 36
                        spacing: 4

                        Repeater {
                            model: Processes.pids.map(pid => Processes.byPid[pid]).filter(p => !!p).sort((a, b) => b.cpu - a.cpu).slice(0, 6)

                            delegate: Item {
                                id: proc

                                required property var modelData

                                width: parent.width
                                height: 24

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width * Math.min(1, proc.modelData.cpu / Math.max(25, Processes.busiest))
                                    height: parent.height
                                    radius: 8
                                    color: Qt.alpha(Theme.accent, 0.16)
                                }
                                Label {
                                    x: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 80
                                    text: proc.modelData.name
                                    size: 12
                                    elide: Text.ElideRight
                                }
                                Label {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: proc.modelData.cpu.toFixed(1) + "%"
                                    size: 12
                                    font.features: {
                                        "tnum": 1
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ---------------- notifications
            NotificationList {
                clearMargin: 20
                y: 3 * (pager.height + 30)
                width: pager.width
                height: pager.height
                visible: root.page === 3 || slide.running
            }
        }
    }
}
