import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.services

// The studio layout's dashboard: a cover flow of four big cards (Today, Music, System,
// Notifications). The chosen one faces you, the others turn away to the sides. Arrows, Tab, the
// wheel or a click on a side card bring another one forward. On opening the cards fan out of
// the middle after the card has grown out of the clock.
Item {
    id: root

    property int current: 0
    readonly property bool open: Ui.popup === "dashboard" && visible
    readonly property int cardWidth: 500
    readonly property int cardHeight: 430
    // 0 while the cards still lie in a stack, 1 once fanned out.
    property real fan: open ? 1 : 0
    readonly property var titles: [Tr.t("Today"), Tr.t("Music"), Tr.t("System"), Tr.t("Notifications")]

    Behavior on fan {
        NumberAnimation {
            duration: root.open ? 760 : 150
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.16, 1.1, 0.3, 1, 1, 1]
        }
    }

    function select(i) {
        current = Math.max(0, Math.min(3, i));
    }

    focus: true
    Keys.onEscapePressed: Ui.popup = ""
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
            select(current + 1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) {
            select(current - 1);
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

        precision: SystemClock.Seconds
    }

    MouseArea {
        anchors.fill: parent
        onWheel: wheel => root.select(root.current + (wheel.angleDelta.y < 0 || wheel.angleDelta.x < 0 ? 1 : -1))
    }

    // The page names along the top, the chosen one lit.
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 20
        spacing: 26
        opacity: root.fan

        Repeater {
            model: root.titles

            delegate: Column {
                id: title

                required property string modelData
                required property int index

                spacing: 5

                Label {
                    text: title.modelData
                    size: 14
                    font.weight: root.current === title.index ? Font.DemiBold : Font.Normal
                    color: root.current === title.index ? Theme.text : Theme.muted

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.select(title.index)
                    }
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: root.current === title.index ? 18 : 4
                    height: 4
                    radius: 2
                    color: root.current === title.index ? Theme.accent : Qt.alpha(Theme.text, 0.3)

                    Behavior on width {
                        NumberAnimation {
                            duration: 260
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }
    }

    // A card of the flow, placed and turned by how far it is from the chosen one.
    component FlowCard: Item {
        id: card

        property int index: 0
        default property alias content: face.data
        property real offset: index - root.current

        Behavior on offset {
            NumberAnimation {
                duration: 520
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.2, 1, 0.3, 1, 1, 1]
            }
        }

        readonly property real away: Math.max(-1.6, Math.min(1.6, offset))
        x: (root.width - root.cardWidth) / 2 + away * 390 * root.fan
        y: 62 + Math.abs(away) * 22
        z: 10 - Math.abs(offset)
        width: root.cardWidth
        height: root.cardHeight
        opacity: Math.max(0, 1 - Math.abs(offset) * 0.42) * Math.min(1, root.fan * 1.5)
        visible: Math.abs(offset) < 2.2
        transform: [
            Rotation {
                origin.x: card.width / 2
                origin.y: card.height / 2
                axis.x: 0
                axis.y: 1
                axis.z: 0
                angle: -card.away * 38 * root.fan
            },
            Scale {
                origin.x: card.width / 2
                origin.y: card.height / 2
                xScale: 1 - Math.min(1, Math.abs(card.away)) * 0.16
                yScale: xScale
            }
        ]

        ClippingRectangle {
            id: face

            anchors.fill: parent
            radius: 28
            color: Qt.alpha(Theme.glassBase, 0.55)
            border.width: 1
            border.color: Math.abs(card.offset) < 0.5 ? Qt.alpha(Theme.accent, 0.5) : Qt.alpha(Theme.text, 0.1)
        }
        // A side card comes forward on a click and takes no clicks itself.
        MouseArea {
            anchors.fill: parent
            visible: Math.abs(card.offset) > 0.5
            cursorShape: Qt.PointingHandCursor
            onClicked: root.select(card.index)
        }
    }

    // ------------------------------------------------ today
    FlowCard {
        index: 0

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.alpha(Theme.accent, 0.3)
                }
                GradientStop {
                    position: 0.7
                    color: "transparent"
                }
            }
        }
        Column {
            x: 34
            y: 34
            width: parent.width - 68
            spacing: 0

            Label {
                text: Tr.capitalized(clock.date.toLocaleDateString(Tr.locale, "dddd"))
                size: 18
                color: Theme.accent
                font.weight: Font.DemiBold
            }
            Label {
                text: Ui.pad(clock.hours) + ":" + Ui.pad(clock.minutes)
                font.family: Theme.display
                size: 110
                font.weight: Font.DemiBold
            }
            Label {
                text: clock.date.toLocaleDateString(Tr.locale, "d MMMM yyyy")
                size: 18
                color: Theme.muted
            }
        }
        Row {
            x: 34
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 34
            spacing: 16
            visible: Weather.hasData

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: Weather.icon(Weather.code, Weather.isDay)
                size: 44
                color: Theme.accent
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter

                Label {
                    text: Weather.temperature + "° " + Weather.describe(Weather.code)
                    size: 20
                    font.weight: Font.DemiBold
                }
                Label {
                    text: Tr.t("Feels like") + " " + Weather.feels + "° · " + Tr.t("Wind") + " " + Weather.wind + " " + Tr.t("km/h")
                    size: 13
                    color: Theme.muted
                }
            }
        }
        // The seconds go round in the corner.
        Ring {
            anchors.right: parent.right
            anchors.rightMargin: 34
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 34
            width: 56
            height: 56
            thickness: 5
            value: clock.seconds / 60
            animated: false

            Label {
                anchors.centerIn: parent
                text: Ui.pad(clock.seconds)
                size: 14
                font.weight: Font.Medium
            }
        }
    }

    // ------------------------------------------------ music
    FlowCard {
        index: 1

        readonly property bool playing: !!Media.player && Media.player.isPlaying

        Image {
            anchors.fill: parent
            source: Media.art
            sourceSize: Qt.size(500, 500)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop {
                    position: 0.25
                    color: "transparent"
                }
                GradientStop {
                    position: 0.95
                    color: Qt.alpha(Theme.glassBase, 0.95)
                }
            }
        }
        Icon {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -60
            visible: Media.art === ""
            name: "music"
            size: 80
            color: Qt.alpha(Theme.text, 0.25)
        }
        Column {
            x: 30
            y: parent.height - 170
            width: parent.width - 60
            spacing: 4

            Label {
                width: parent.width
                text: Media.player ? Media.title : Tr.t("No music")
                size: 24
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Label {
                width: parent.width
                text: Media.player ? Media.player.trackArtist : Tr.t("Play something and it shows here")
                size: 14
                color: Theme.muted
                elide: Text.ElideRight
            }
        }
        Rectangle {
            x: 30
            y: parent.height - 96
            width: parent.width - 60
            height: 4
            radius: 2
            color: Qt.alpha(Theme.text, 0.2)

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, Media.progress))
                height: 4
                radius: 2
                color: Media.artAccent
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - 76
            spacing: 26

            Repeater {
                model: ["previous", "play", "next"]

                delegate: Rectangle {
                    id: control

                    required property string modelData
                    readonly property bool main: modelData === "play"

                    anchors.verticalCenter: parent.verticalCenter
                    width: main ? 56 : 42
                    height: width
                    radius: width / 2
                    color: main ? Media.artAccent : Qt.alpha(Theme.text, controlArea.containsMouse ? 0.15 : 0.07)

                    Icon {
                        anchors.centerIn: parent
                        name: control.main && Media.player && Media.player.isPlaying ? "pause" : control.modelData
                        filled: !control.main || !(Media.player && Media.player.isPlaying)
                        size: control.main ? 22 : 17
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

    // ------------------------------------------------ system
    FlowCard {
        index: 2

        Label {
            x: 30
            y: 26
            text: Tr.t("System")
            size: 20
            font.weight: Font.DemiBold
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 72
            spacing: 24

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
                        label: Sys.hasBattery ? Tr.t("Battery") : Tr.t("Heat"),
                        value: Sys.hasBattery ? Sys.batteryPercent / 100 : Sys.temperature / 100,
                        text: Sys.hasBattery ? Sys.batteryPercent + "%" : Sys.temperature + "°"
                    }
                ]

                delegate: Column {
                    id: meter

                    required property var modelData
                    required property int index

                    spacing: 10

                    Ring {
                        width: 124
                        height: 124
                        thickness: 11
                        value: root.open ? meter.modelData.value : 0
                        color: Theme.hueShift(Theme.accent, meter.index * 0.08)

                        Label {
                            anchors.centerIn: parent
                            text: meter.modelData.text
                            font.family: Theme.display
                            size: 22
                            font.weight: Font.DemiBold
                        }
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: meter.modelData.label
                        size: 13
                        color: Theme.muted
                    }
                }
            }
        }
        LoadChart {
            x: 30
            y: 260
            width: parent.width - 60
            height: parent.height - y - 30
            values: Sys.history
        }
    }

    // ------------------------------------------------ notifications
    FlowCard {
        index: 3

        NotificationList {
            clearMargin: 20
            anchors.fill: parent
            color: "transparent"
        }
    }
}
