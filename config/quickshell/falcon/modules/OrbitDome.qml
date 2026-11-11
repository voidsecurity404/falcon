import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.services

// The orbit layout's dashboard: a glass dome that inflates out of the pill. In its middle a
// round clock whose ring is the minute and whose rim moves with the music; around its top, on
// an orbit, bubbles for the weather and the machine that spiral out when the dome opens. The
// song on the bottom left, the latest notifications on the bottom right.
Rectangle {
    id: root

    property bool shown: false
    property real t: 0
    // The pill it grows out of, in this window's coordinates.
    property rect from: Qt.rect(0, 0, 0, 0)
    readonly property int fullWidth: 900
    readonly property int fullHeight: 540
    readonly property real cx: fullWidth / 2
    readonly property real cy: 250

    onShownChanged: {
        grow.stop();
        grow.to = shown ? 1 : 0;
        grow.duration = shown ? 700 : 260;
        grow.easing.bezierCurve = shown ? [0.2, 1.25, 0.3, 1, 1, 1] : [0.5, 0, 0.9, 0.3, 1, 1];
        grow.start();
        Spectrum.setWatching("orbit-dash", shown);
    }

    NumberAnimation {
        id: grow

        target: root
        property: "t"
        easing.type: Easing.BezierSpline
    }

    function lerp(a, b, k) {
        return a + (b - a) * k;
    }
    readonly property real k: Math.max(0, t)

    x: lerp(from.x, from.x + from.width / 2 - fullWidth / 2, k)
    y: lerp(from.y, from.y - 14 - fullHeight, k)
    width: Math.max(1, lerp(from.width, fullWidth, k))
    height: Math.max(1, lerp(from.height, fullHeight, k))
    // A dome: the top is one wide arch, the bottom corners small.
    topLeftRadius: lerp(25, 300, Math.min(1, k))
    topRightRadius: lerp(25, 300, Math.min(1, k))
    bottomLeftRadius: lerp(25, 40, Math.min(1, k))
    bottomRightRadius: lerp(25, 40, Math.min(1, k))
    visible: t > 0.001
    clip: true
    border.width: 1
    border.color: Theme.panelEdge
    gradient: Gradient {
        GradientStop {
            position: 0
            color: Qt.alpha(Qt.tint(Theme.glassBase, Qt.alpha(Theme.accent, 0.14)), Math.max(0.6, Theme.glassOpacity))
        }
        GradientStop {
            position: 1
            color: Qt.alpha(Theme.glassBase, Math.max(0.66, Theme.glassOpacity))
        }
    }

    SystemClock {
        id: clock

        precision: SystemClock.Seconds
    }

    MouseArea {
        anchors.fill: parent
    }

    // How far a bubble has come out, staggered.
    function out(i) {
        return Math.max(0, Math.min(1.06, (root.t - 0.25 - i * 0.05) / 0.5));
    }

    // The content keeps its size, centered, so nothing reflows while the dome grows.
    Item {
        x: (root.width - root.fullWidth) / 2
        y: root.height - root.fullHeight
        width: root.fullWidth
        height: root.fullHeight
        opacity: Math.max(0, Math.min(1, (root.t - 0.25) * 2))

        // A faint orbit.
        Rectangle {
            x: root.cx - 200
            y: root.cy - 200
            width: 400
            height: 400
            radius: 200
            color: "transparent"
            border.width: 1
            border.color: Qt.alpha(Theme.text, 0.07)
        }

        // ---------------- the music rim: bars standing out of the clock's ring
        Repeater {
            model: 72

            delegate: Item {
                required property int index
                readonly property var levels: Spectrum.levels
                readonly property real level: levels.length > 0 ? levels[index % 36] / 100 : 0

                x: root.cx - 1.5
                y: root.cy
                width: 3
                height: 1
                rotation: index * 5
                transformOrigin: Item.TopLeft
                visible: !!Media.player && Media.player.isPlaying

                Rectangle {
                    x: 0
                    y: -136 - height
                    width: 3
                    height: 4 + parent.level * 34
                    radius: 1.5
                    color: Qt.alpha(Media.artAccent, 0.75)
                }
            }
        }

        // ---------------- the clock
        Item {
            x: root.cx - 130
            y: root.cy - 130
            width: 260
            height: 260
            scale: Math.min(1, 0.6 + root.t * 0.4)

            Rectangle {
                anchors.fill: parent
                anchors.margins: 10
                radius: width / 2
                color: Qt.alpha(Theme.glassBase, 0.45)
                border.width: 1
                border.color: Qt.alpha(Theme.text, 0.1)
            }
            Ring {
                anchors.fill: parent
                thickness: 8
                value: (clock.minutes * 60 + clock.seconds) / 3600
                color: Theme.accent
            }
            // The seconds, a moon going round.
            Item {
                anchors.fill: parent
                rotation: clock.seconds * 6

                Behavior on rotation {
                    enabled: clock.seconds !== 0

                    NumberAnimation {
                        duration: 400
                        easing.type: Easing.OutBack
                    }
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: -2
                    width: 12
                    height: 12
                    radius: 6
                    color: Theme.text
                }
            }
            Column {
                anchors.centerIn: parent
                spacing: 2

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Ui.pad(clock.hours) + ":" + Ui.pad(clock.minutes)
                    font.family: Theme.display
                    size: 54
                    font.weight: Font.DemiBold
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Tr.capitalized(clock.date.toLocaleDateString(Tr.locale, "dddd, d MMMM"))
                    size: 14
                    color: Theme.muted
                }
            }
        }

        // ---------------- bubbles on the orbit's upper half
        Repeater {
            model: [
                {
                    icon: Weather.hasData ? Weather.icon(Weather.code, Weather.isDay) : "cloud",
                    value: Weather.hasData ? Weather.temperature + "°" : "—",
                    label: Tr.t("Outside"),
                    share: -1
                },
                {
                    icon: "chip",
                    value: Sys.cpu + "%",
                    label: Tr.t("CPU"),
                    share: Sys.cpu / 100
                },
                {
                    icon: "system",
                    value: Sys.ram + "%",
                    label: Tr.t("Memory"),
                    share: Sys.ram / 100
                },
                {
                    icon: "sun",
                    value: Sys.temperature > 0 ? Sys.temperature + "°" : "—",
                    label: Tr.t("Heat"),
                    share: Sys.temperature / 100
                },
                {
                    icon: Sys.hasBattery ? (Sys.charging ? "charging" : "battery") : "save",
                    value: Sys.hasBattery ? Sys.batteryPercent + "%" : Sys.disk + "%",
                    label: Sys.hasBattery ? Tr.t("Battery") : Tr.t("Disk"),
                    share: (Sys.hasBattery ? Sys.batteryPercent : Sys.disk) / 100
                },
                {
                    icon: Audio.muted ? "mute" : "volume",
                    value: Audio.percent + "%",
                    label: Tr.t("Sound"),
                    share: Audio.volume
                }
            ]

            delegate: Item {
                id: bubble

                required property var modelData
                required property int index
                readonly property real p: root.out(index)
                // From the left of the orbit over the top to its right.
                readonly property real angle: (198 + index * 28.8 - (1 - Math.min(1, p)) * 70) * Math.PI / 180

                x: root.cx + Math.cos(angle) * 200 * p - width / 2
                y: root.cy + Math.sin(angle) * 200 * p - height / 2
                width: 84
                height: 84
                opacity: Math.min(1, p * 1.5)
                scale: 0.5 + 0.5 * Math.min(1, p)

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Qt.alpha(Theme.glassBase, 0.7)
                    border.width: 1
                    border.color: Qt.alpha(Theme.text, 0.12)
                }
                Ring {
                    anchors.fill: parent
                    visible: bubble.modelData.share >= 0
                    thickness: 4
                    value: root.shown ? bubble.modelData.share : 0
                    color: Theme.hueShift(Theme.accent, bubble.index * 0.05)
                }
                Column {
                    anchors.centerIn: parent
                    spacing: 1

                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: bubble.modelData.icon
                        size: 16
                        color: Theme.accent
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: bubble.modelData.value
                        size: 15
                        font.weight: Font.DemiBold
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: bubble.modelData.label
                        size: 9
                        color: Theme.muted
                    }
                }
            }
        }

        // ---------------- the song, bottom left
        Rectangle {
            x: 40
            y: root.fullHeight - 104
            width: 360
            height: 76
            radius: 38
            color: Qt.alpha(Theme.text, 0.06)
            opacity: Math.max(0, Math.min(1, (root.t - 0.6) * 3))

            ClippingRectangle {
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 60
                height: 60
                radius: 30
                color: Media.artAccent

                Image {
                    anchors.fill: parent
                    source: Media.art
                    sourceSize: Qt.size(120, 120)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                RotationAnimator on rotation {
                    from: 0
                    to: 360
                    duration: 12000
                    loops: Animation.Infinite
                    running: root.shown && !!Media.player && Media.player.isPlaying
                }
            }
            Column {
                x: 80
                anchors.verticalCenter: parent.verticalCenter
                width: 160

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
                    size: 11
                    color: Theme.muted
                    elide: Text.ElideRight
                }
            }
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Repeater {
                    model: ["previous", "play", "next"]

                    delegate: Rectangle {
                        id: control

                        required property string modelData
                        readonly property bool main: modelData === "play"

                        anchors.verticalCenter: parent.verticalCenter
                        width: main ? 40 : 32
                        height: width
                        radius: width / 2
                        color: main ? Media.artAccent : Qt.alpha(Theme.text, controlArea.containsMouse ? 0.12 : 0)

                        Icon {
                            anchors.centerIn: parent
                            name: control.main && Media.player && Media.player.isPlaying ? "pause" : control.modelData
                            filled: !control.main || !(Media.player && Media.player.isPlaying)
                            size: control.main ? 16 : 13
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

        // ---------------- the latest notifications, bottom right
        Rectangle {
            x: root.fullWidth - 40 - 360
            y: root.fullHeight - 104
            width: 360
            height: 76
            radius: 38
            color: Qt.alpha(Theme.text, 0.06)
            opacity: Math.max(0, Math.min(1, (root.t - 0.65) * 3))

            Rectangle {
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 60
                height: 60
                radius: 30
                color: Qt.alpha(Theme.accent, 0.22)

                Icon {
                    anchors.centerIn: parent
                    name: "bell"
                    size: 20
                    color: Theme.accent
                }
                Rectangle {
                    visible: Toasts.history.length > 0
                    anchors.right: parent.right
                    anchors.top: parent.top
                    width: countLabel.implicitWidth + 10
                    height: 18
                    radius: 9
                    color: Theme.accent

                    Label {
                        id: countLabel

                        anchors.centerIn: parent
                        text: Toasts.history.length
                        size: 10
                        font.weight: Font.Bold
                        color: Theme.accentText
                    }
                }
            }
            Column {
                x: 80
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 80 - 70

                Label {
                    width: parent.width
                    text: Toasts.history.length > 0 ? Toasts.history[0].title : Tr.t("No notifications")
                    size: 13
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Label {
                    width: parent.width
                    text: Toasts.history.length > 0 ? (Toasts.history[0].app || "") + " · " + Toasts.timeLabel(Toasts.history[0]) : Tr.t("All quiet")
                    size: 11
                    color: Theme.muted
                    elide: Text.ElideRight
                }
            }
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                visible: Toasts.history.length > 0
                width: clearLabel.implicitWidth + 18
                height: 28
                radius: 14
                color: Qt.alpha(Theme.text, clearArea.containsMouse ? 0.14 : 0.07)

                Label {
                    id: clearLabel

                    anchors.centerIn: parent
                    text: Tr.t("Clear")
                    size: 11
                }
                MouseArea {
                    id: clearArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Toasts.forget(Toasts.history.map(h => h.id))
                }
            }
        }
    }
}
