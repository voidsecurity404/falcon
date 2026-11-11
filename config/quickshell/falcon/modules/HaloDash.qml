import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.services

// The halo layout's dashboard: everything on one bento board, no tabs. The clock, the weather,
// the song, four rings for the system, the month and the notifications, each a tile of its own.
// When the capsule opens the tiles pop out of its middle one after another.
Item {
    id: root

    readonly property int gap: 12
    readonly property bool open: Ui.popup === "dashboard" && visible
    readonly property bool clock24: Settings.get("panel.clock24", true)

    onOpenChanged: Spectrum.setWatching("halo-dash", open)
    Component.onDestruction: Spectrum.setWatching("halo-dash", false)

    SystemClock {
        id: clock

        precision: SystemClock.Seconds
    }

    // A tile pops in from the board's middle, later the farther it is.
    component Tile: Rectangle {
        id: tile

        property real delay: 0

        radius: 24
        color: Qt.alpha(Theme.text, 0.06)
        border.width: 1
        border.color: Qt.alpha(Theme.text, 0.07)
        clip: true
        transformOrigin: Item.Center
        scale: root.open ? 1 : 0.82
        opacity: root.open ? 1 : 0

        Behavior on scale {
            SequentialAnimation {
                PauseAnimation {
                    duration: root.open ? tile.delay : 0
                }
                NumberAnimation {
                    duration: root.open ? 520 : 120
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.6
                }
            }
        }
        Behavior on opacity {
            SequentialAnimation {
                PauseAnimation {
                    duration: root.open ? tile.delay : 0
                }
                NumberAnimation {
                    duration: root.open ? 260 : 100
                }
            }
        }
    }

    Item {
        id: board

        x: 18
        y: 18
        width: parent.width - 36
        height: parent.height - 36

        readonly property int colA: 292
        readonly property int colC: 300
        readonly property int colB: width - colA - colC - root.gap * 2

        // ------------------------------------------------ clock
        Tile {
            id: clockTile

            delay: 140
            width: board.colA
            height: 196

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Qt.alpha(Theme.accent, 0.32)
                    }
                    GradientStop {
                        position: 1
                        color: Qt.alpha(Theme.accent, 0.04)
                    }
                }
            }
            Label {
                x: 22
                y: 20
                text: Ui.pad(root.clock24 ? clock.hours : clock.hours % 12 || 12) + ":" + Ui.pad(clock.minutes)
                font.family: Theme.display
                size: 62
                font.weight: Font.DemiBold
            }
            // Seconds run along the bottom as a thin line.
            Rectangle {
                x: 22
                y: 112
                width: (parent.width - 44) * clock.seconds / 59
                height: 3
                radius: 1.5
                color: Theme.accent

                Behavior on width {
                    NumberAnimation {
                        duration: 300
                    }
                }
            }
            Label {
                x: 22
                y: 128
                width: parent.width - 44
                text: clock.date.toLocaleDateString(Tr.locale, "dddd")
                size: 18
                font.weight: Font.DemiBold
                font.capitalization: Font.Capitalize
            }
            Label {
                x: 22
                y: 154
                text: clock.date.toLocaleDateString(Tr.locale, "d MMMM yyyy")
                size: 13
                color: Theme.muted
            }
        }

        // ------------------------------------------------ weather
        Tile {
            delay: 220
            y: clockTile.height + root.gap
            width: board.colA
            height: board.height - y

            Column {
                x: 22
                y: 20
                width: parent.width - 44
                spacing: 4

                Row {
                    spacing: 12

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: Weather.hasData ? Weather.icon(Weather.code, Weather.isDay) : "cloud"
                        size: 40
                        color: Theme.accent
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Weather.hasData ? Weather.temperature + "°" : "—"
                        font.family: Theme.display
                        size: 40
                        font.weight: Font.DemiBold
                    }
                }
                Label {
                    width: parent.width
                    text: Weather.hasData ? Weather.describe(Weather.code) : Tr.t("No weather yet")
                    size: 14
                    font.weight: Font.Medium
                }
                Label {
                    width: parent.width
                    visible: Weather.hasData
                    text: Tr.t("Feels like") + " " + Weather.feels + "° · " + Weather.humidity + "%"
                    size: 12
                    color: Theme.muted
                }
            }
            // Sunrise, sunset and wind in the middle.
            Column {
                x: 22
                y: 150
                width: parent.width - 44
                spacing: 8
                visible: Weather.hasData

                Repeater {
                    model: [
                        ["sun", Tr.t("Sunrise"), Qt.formatTime(new Date(Weather.sunrise), "hh:mm")],
                        ["moon", Tr.t("Sunset"), Qt.formatTime(new Date(Weather.sunset), "hh:mm")],
                        ["cloud", Tr.t("Wind"), Weather.wind + " " + Tr.t("km/h")]
                    ]

                    delegate: Item {
                        required property var modelData

                        width: parent.width
                        height: 20

                        Row {
                            spacing: 8

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: modelData[0]
                                size: 14
                                color: Theme.muted
                            }
                            Label {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData[1]
                                size: 12
                                color: Theme.muted
                            }
                        }
                        Label {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData[2]
                            size: 13
                            font.weight: Font.Medium
                        }
                    }
                }
            }
            // The next hours as small columns.
            Row {
                x: 16
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 16
                width: parent.width - 32

                Repeater {
                    model: Weather.hourly.slice(1, 6)

                    delegate: Column {
                        id: hour

                        required property var modelData

                        width: (board.colA - 32) / 5
                        spacing: 6

                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Ui.pad(new Date(hour.modelData.time).getHours())
                            size: 11
                            color: Theme.muted
                        }
                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: Weather.icon(hour.modelData.code, true)
                            size: 18
                        }
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: hour.modelData.temp + "°"
                            size: 13
                            font.weight: Font.Medium
                        }
                    }
                }
            }
        }

        // ------------------------------------------------ music
        Tile {
            id: musicTile

            delay: 0
            x: board.colA + root.gap
            width: board.colB
            height: 268

            ClippingRectangle {
                anchors.fill: parent
                radius: 24
                color: "transparent"

                Image {
                    anchors.fill: parent
                    source: Media.art
                    sourceSize: Qt.size(400, 400)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    opacity: 0.3
                }
                SpectrumBars {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 90
                    active: root.open
                    color: Media.artAccent
                    gap: 3
                }
            }
            ClippingRectangle {
                id: cover

                x: 20
                y: 20
                width: 112
                height: 112
                radius: 18
                color: Qt.alpha(Theme.text, 0.1)

                Image {
                    anchors.fill: parent
                    source: Media.art
                    sourceSize: Qt.size(224, 224)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                Icon {
                    anchors.centerIn: parent
                    visible: Media.art === ""
                    name: "music"
                    size: 34
                    color: Theme.muted
                }
            }
            Column {
                x: cover.x + cover.width + 18
                y: 30
                width: parent.width - x - 20
                spacing: 4

                Label {
                    width: parent.width
                    text: Media.player ? Media.title : Tr.t("No music")
                    size: 18
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                }
                Label {
                    width: parent.width
                    text: Media.player ? Media.player.trackArtist : Tr.t("Play something and it shows here")
                    size: 13
                    color: Theme.muted
                    elide: Text.ElideRight
                }
            }
            // The place in the song.
            Rectangle {
                x: 20
                y: 152
                width: parent.width - 40
                height: 4
                radius: 2
                color: Qt.alpha(Theme.text, 0.15)

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, Media.progress))
                    height: parent.height
                    radius: 2
                    color: Media.artAccent
                }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 176
                spacing: 22

                Repeater {
                    model: ["previous", "play", "next"]

                    delegate: Rectangle {
                        id: control

                        required property string modelData
                        readonly property bool main: modelData === "play"

                        width: main ? 52 : 40
                        height: width
                        radius: width / 2
                        color: main ? Media.artAccent : Qt.alpha(Theme.text, controlArea.containsMouse ? 0.12 : 0)
                        anchors.verticalCenter: parent.verticalCenter

                        Icon {
                            anchors.centerIn: parent
                            name: control.main && Media.player && Media.player.isPlaying ? "pause" : control.modelData
                            filled: !control.main || !(Media.player && Media.player.isPlaying)
                            size: control.main ? 20 : 17
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
        }

        // ------------------------------------------------ system rings
        Tile {
            delay: 160
            x: board.colA + root.gap
            y: musicTile.height + root.gap
            width: board.colB
            height: board.height - y

            Row {
                anchors.centerIn: parent
                spacing: (board.colB - 4 * 74 - 32) / 3

                Repeater {
                    model: [
                        {
                            label: Tr.t("CPU"),
                            value: Sys.cpu / 100,
                            text: Sys.cpu + "%"
                        },
                        {
                            label: Tr.t("Memory"),
                            value: Sys.ram / 100,
                            text: Sys.ram + "%"
                        },
                        {
                            label: Tr.t("Heat"),
                            value: Sys.temperature / 100,
                            text: Sys.temperature > 0 ? Sys.temperature + "°" : "—"
                        },
                        {
                            label: Sys.hasBattery ? Tr.t("Battery") : Tr.t("Disk"),
                            value: (Sys.hasBattery ? Sys.batteryPercent : Sys.disk) / 100,
                            text: (Sys.hasBattery ? Sys.batteryPercent : Sys.disk) + "%"
                        }
                    ]

                    delegate: Column {
                        id: meter

                        required property var modelData
                        required property int index

                        spacing: 8

                        Item {
                            width: 74
                            height: 74

                            Ring {
                                anchors.fill: parent
                                value: root.open ? meter.modelData.value : 0
                                thickness: 8
                                color: Theme.hueShift(Theme.accent, meter.index * 0.07)
                            }
                            Label {
                                anchors.centerIn: parent
                                text: meter.modelData.text
                                size: 15
                                font.weight: Font.DemiBold
                            }
                        }
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: meter.modelData.label
                            size: 12
                            color: Theme.muted
                        }
                    }
                }
            }
        }

        // ------------------------------------------------ month
        Tile {
            id: monthTile

            delay: 120
            x: board.width - board.colC
            width: board.colC
            height: 236

            Calendar {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 18
                cellWidth: 36
                cellHeight: 26
            }
        }

        // ------------------------------------------------ notifications
        Tile {
            delay: 200
            x: board.width - board.colC
            y: monthTile.height + root.gap
            width: board.colC
            height: board.height - y

            NotificationList {
                clearMargin: 20
                anchors.fill: parent
                color: "transparent"
            }
        }
    }
}
