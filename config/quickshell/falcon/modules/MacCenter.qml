import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.services

// The macos layout's dashboard is a notification center, after macOS: a glass column that
// slides in from the right edge under the menu bar. The notifications on top, then widgets: a
// calendar, an analog clock, the weather, the battery, and the song playing. The widgets follow
// the sheet in, each a moment later.
Rectangle {
    id: root

    property bool shown: false
    property real t: 0
    property real topGap: 38
    readonly property int pad: 14
    readonly property int small: (width - pad * 2 - 12) / 2

    onShownChanged: {
        slide.stop();
        slide.to = shown ? 1 : 0;
        slide.duration = shown ? 520 : 220;
        slide.easing.bezierCurve = shown ? [0.16, 1, 0.3, 1, 1, 1] : [0.5, 0, 0.9, 0.4, 1, 1];
        slide.start();
    }

    NumberAnimation {
        id: slide

        target: root
        property: "t"
        easing.type: Easing.BezierSpline
    }

    width: 380
    height: Math.min(column.implicitHeight + pad * 2, (parent ? parent.height : 1080) - topGap - 10)
    x: (parent ? parent.width : 0) - width - 8 + (1 - t) * (width + 30)
    y: topGap
    radius: 20
    visible: t > 0.001
    clip: true
    color: Qt.alpha(Theme.glassBase, Math.max(0.55, Theme.glassOpacity * 0.85))
    border.width: 1
    border.color: Qt.alpha(Theme.text, 0.18)

    SystemClock {
        id: clock

        precision: SystemClock.Seconds
    }

    MouseArea {
        anchors.fill: parent
    }

    // A widget comes in after the sheet, by its place.
    component Widget: Rectangle {
        id: widget

        property int order: 0
        readonly property real p: Math.max(0, Math.min(1, root.t * 1.6 - 0.12 * order))

        radius: 20
        color: Qt.alpha(Theme.text, 0.08)
        border.width: 1
        border.color: Qt.alpha(Theme.text, 0.07)
        clip: true
        opacity: p
        transform: Translate {
            x: (1 - widget.p) * 40
        }
    }

    Column {
        id: column

        x: root.pad
        y: root.pad
        width: root.width - root.pad * 2
        spacing: 12

        Widget {
            order: 0
            width: parent.width
            height: Math.min(330, 96 + Math.max(1, Toasts.history.length) * 72)

            NotificationList {
                clearMargin: 20
                anchors.fill: parent
                color: "transparent"
            }
        }

        Row {
            spacing: 12

            // Calendar: the day name in the accent, the date big, the month in small.
            Widget {
                order: 1
                width: root.small
                height: root.small

                Label {
                    x: 16
                    y: 12
                    text: Tr.capitalized(clock.date.toLocaleDateString(Tr.locale, "dddd")).toUpperCase()
                    size: 11
                    font.weight: Font.Bold
                    color: Theme.error
                }
                Label {
                    x: 14
                    y: 26
                    text: clock.date.getDate()
                    font.family: Theme.display
                    size: 44
                    font.weight: Font.DemiBold
                }
                Grid {
                    x: 16
                    y: 92
                    columns: 7
                    columnSpacing: 2
                    rowSpacing: 1

                    Repeater {
                        // This week and the next, so the widget stays small.
                        model: 14

                        delegate: Label {
                            required property int index
                            readonly property var day: {
                                const now = clock.date;
                                const monday = new Date(now.getFullYear(), now.getMonth(), now.getDate() - (now.getDay() + 6) % 7);
                                return new Date(monday.getFullYear(), monday.getMonth(), monday.getDate() + index);
                            }
                            readonly property bool today: day.toDateString() === clock.date.toDateString()

                            width: (root.small - 32 - 12) / 7
                            horizontalAlignment: Text.AlignHCenter
                            text: day.getDate()
                            size: 11
                            font.weight: today ? Font.Bold : Font.Normal
                            color: today ? Theme.error : Theme.text
                        }
                    }
                }
            }
            // An analog clock.
            Widget {
                order: 2
                width: root.small
                height: root.small

                Rectangle {
                    id: face

                    anchors.centerIn: parent
                    width: parent.width - 28
                    height: width
                    radius: width / 2
                    color: Qt.alpha(Theme.text, 0.92)

                    Repeater {
                        model: 12

                        delegate: Item {
                            required property int index

                            anchors.fill: parent
                            rotation: index * 30

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 6
                                width: index % 3 === 0 ? 3 : 2
                                height: index % 3 === 0 ? 9 : 5
                                radius: 1
                                color: Qt.alpha(Theme.glassBase, 0.8)
                            }
                        }
                    }
                    Repeater {
                        model: [
                            {
                                turn: (clock.hours % 12 + clock.minutes / 60) * 30,
                                length: 0.26,
                                width: 4,
                                color: Theme.glassBase
                            },
                            {
                                turn: (clock.minutes + clock.seconds / 60) * 6,
                                length: 0.38,
                                width: 3,
                                color: Theme.glassBase
                            },
                            {
                                turn: clock.seconds * 6,
                                length: 0.42,
                                width: 1.5,
                                color: Theme.error
                            }
                        ]

                        delegate: Item {
                            required property var modelData

                            anchors.fill: parent
                            rotation: modelData.turn

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: parent.height / 2 - height + 4
                                width: modelData.width
                                height: face.width * modelData.length
                                radius: width / 2
                                color: modelData.color
                            }
                        }
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 7
                        height: 7
                        radius: 3.5
                        color: Theme.error
                    }
                }
            }
        }

        Row {
            spacing: 12

            // Weather on a sky of the accent's hue.
            Widget {
                order: 3
                width: root.small
                height: root.small
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Qt.alpha(Theme.hueShift(Theme.accent, 0.05), 0.55)
                    }
                    GradientStop {
                        position: 1
                        color: Qt.alpha(Theme.accent, 0.18)
                    }
                }

                Column {
                    x: 16
                    y: 14
                    width: parent.width - 32
                    spacing: 0

                    Label {
                        text: Tr.t("Weather")
                        size: 12
                        font.weight: Font.DemiBold
                    }
                    Label {
                        text: Weather.hasData ? Weather.temperature + "°" : "—"
                        font.family: Theme.display
                        size: 38
                        font.weight: Font.Medium
                    }
                }
                Column {
                    x: 16
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 14
                    width: parent.width - 32
                    spacing: 2

                    Icon {
                        name: Weather.hasData ? Weather.icon(Weather.code, Weather.isDay) : "cloud"
                        size: 18
                    }
                    Label {
                        width: parent.width
                        text: Weather.hasData ? Weather.describe(Weather.code) : Tr.t("No weather yet")
                        size: 12
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Label {
                        visible: Weather.hasData && Weather.daily.length > 0
                        text: Weather.daily.length > 0 ? "↑" + Weather.daily[0].max + "°  ↓" + Weather.daily[0].min + "°" : ""
                        size: 11
                    }
                }
            }
            // Battery, or the processor where there is none.
            Widget {
                order: 4
                width: root.small
                height: root.small

                Ring {
                    anchors.centerIn: parent
                    width: parent.width - 52
                    height: width
                    thickness: 9
                    value: root.shown ? (Sys.hasBattery ? Sys.batteryPercent : 100 - Sys.cpu) / 100 : 0
                    color: Sys.hasBattery && Sys.charging ? Theme.good : Sys.hasBattery && Sys.batteryPercent <= 15 ? Theme.error : Theme.good

                    Column {
                        anchors.centerIn: parent

                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: Sys.hasBattery ? (Sys.charging ? "charging" : "battery") : "chip"
                            size: 20
                        }
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Sys.hasBattery ? Sys.batteryPercent + "%" : Sys.cpu + "%"
                            size: 15
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }
        }

        // The song playing, wide.
        Widget {
            order: 5
            width: parent.width
            height: 96

            ClippingRectangle {
                id: art

                x: 14
                anchors.verticalCenter: parent.verticalCenter
                width: 68
                height: 68
                radius: 12
                color: Qt.alpha(Theme.text, 0.1)

                Image {
                    anchors.fill: parent
                    source: Media.art
                    sourceSize: Qt.size(136, 136)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                Icon {
                    anchors.centerIn: parent
                    visible: Media.art === ""
                    name: "music"
                    size: 24
                    color: Theme.muted
                }
            }
            Column {
                x: 96
                y: 18
                width: parent.width - 96 - 14
                spacing: 2

                Label {
                    width: parent.width
                    text: Media.player ? Media.title : Tr.t("No music")
                    size: 13
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Label {
                    width: parent.width
                    text: Media.player ? Media.player.trackArtist : ""
                    size: 12
                    color: Theme.muted
                    elide: Text.ElideRight
                }
                Row {
                    spacing: 18
                    topPadding: 4

                    Repeater {
                        model: ["previous", "play", "next"]

                        delegate: Item {
                            id: control

                            required property string modelData

                            width: 22
                            height: 22

                            Icon {
                                anchors.centerIn: parent
                                name: control.modelData === "play" && Media.player && Media.player.isPlaying ? "pause" : control.modelData
                                filled: control.modelData !== "play" || !(Media.player && Media.player.isPlaying)
                                size: 16
                                opacity: Media.player ? 1 : 0.4
                            }
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -6
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
        }
    }
}
