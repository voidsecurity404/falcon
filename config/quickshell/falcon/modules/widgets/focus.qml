import QtQuick
import qs.components
import qs.services

// Pomodoro rounds and quick timers around a live ring. It drives the shell's own timer, so the bar shows
// the same time. Forms: round, wide.
Item {
    id: root

    readonly property bool widgetRoot: true
    property string widgetId: ""
    property string form: "round"
    readonly property bool wide: form === "wide"
    readonly property bool active: Countdown.active
    readonly property bool resting: Countdown.phase === "break"
    readonly property color tint: resting ? Theme.good : Theme.accent
    readonly property real share: active && Countdown.total > 0 ? Countdown.left / Countdown.total : 0
    readonly property var today: Countdown.statOf(new Date())
    readonly property var week: Countdown.stats, Countdown.week()
    readonly property int weekTop: Math.max(1, ...week.map(d => d.n))
    readonly property int weekTotal: week.reduce((a, d) => a + d.n, 0)
    readonly property string todayText: Tr.t("Today") + ": " + today.n + " · " + today.min + " " + Tr.t("min")
    readonly property string phaseText: !active ? Tr.t("Ready to focus") : Countdown.paused ? Tr.t("Paused") : Countdown.phase === "work" ? Tr.t("Focus") : resting ? Tr.t("Break") : (Countdown.label || Tr.t("Timer"))

    Item {
        id: dial

        readonly property real side: root.wide ? root.height - 36 : 190

        x: root.wide ? 22 : (root.width - side) / 2
        y: root.wide ? 18 : 22
        width: side
        height: side

        // A soft glow under the ring while it runs.
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.78
            height: width
            radius: width / 2
            color: Qt.alpha(root.tint, root.active && !Countdown.paused ? 0.12 : 0.05)

            Behavior on color {
                ColorAnimation {
                    duration: 400
                }
            }
        }
        // Minute ticks.
        Repeater {
            model: 60

            Rectangle {
                required property int index

                x: dial.width / 2 - width / 2
                y: 0
                width: index % 5 === 0 ? 2 : 1
                height: index % 5 === 0 ? 7 : 4
                radius: 1
                color: Qt.alpha(Theme.text, index % 5 === 0 ? 0.35 : 0.18)
                transform: Rotation {
                    origin.x: 1
                    origin.y: dial.height / 2
                    angle: index * 6
                }
            }
        }
        Ring {
            anchors.fill: parent
            anchors.margins: 12
            thickness: root.wide ? 9 : 11
            value: root.active ? root.share : 0
            color: root.tint
            trackColor: Qt.alpha(root.tint, 0.14)
        }
        Column {
            anchors.centerIn: parent
            spacing: 2

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.active ? Countdown.text : "25:00"
                font.family: Theme.display
                font.pixelSize: root.wide ? 26 : 34
                font.weight: Font.DemiBold
                color: root.active ? Theme.text : Qt.alpha(Theme.text, 0.45)
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.phaseText
                size: root.wide ? 11 : 13
                color: root.active ? root.tint : Theme.muted
                font.weight: Font.Medium
            }
        }
    }

    // Rounds of the Pomodoro.
    Row {
        id: rounds

        visible: Countdown.phase !== ""
        x: root.wide ? panel.x : (root.width - width) / 2
        y: root.wide ? 58 : dial.y + dial.height + 10
        spacing: 6

        Repeater {
            model: 4

            Rectangle {
                required property int index
                readonly property int at: (Countdown.round - 1) % 4

                width: index === at ? 22 : 8
                height: 8
                radius: 4
                color: index < at ? root.tint : index === at ? Qt.alpha(root.tint, 0.85) : Qt.alpha(Theme.text, 0.18)

                Behavior on width {
                    NumberAnimation {
                        duration: 250
                    }
                }
            }
        }
    }

    // The week in the round form too: small bars in the corner beside the dial, the total under them.
    Column {
        visible: !root.wide
        anchors.right: parent.right
        anchors.rightMargin: 14
        y: 16
        spacing: 3

        Row {
            anchors.right: parent.right
            spacing: 2

            Repeater {
                model: root.week

                Item {
                    id: miniBar

                    required property var modelData
                    required property int index

                    width: 4
                    height: 20

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: Math.max(2, parent.height * miniBar.modelData.n / root.weekTop)
                        radius: 2
                        color: miniBar.modelData.n === 0 ? Qt.alpha(Theme.text, 0.15) : miniBar.index === 6 ? root.tint : Qt.alpha(root.tint, 0.55)
                    }
                }
            }
        }
        Label {
            anchors.right: parent.right
            text: Tr.t("Week") + ": " + root.weekTotal
            size: 9
            color: Theme.muted
        }
    }

    // Rounds finished today (round form).
    Label {
        visible: !root.wide
        anchors.horizontalCenter: parent.horizontalCenter
        y: dial.y + dial.height + (rounds.visible ? 22 : 10)
        text: root.todayText
        size: 11
        color: Theme.muted
    }

    Item {
        id: panel

        x: root.wide ? dial.x + dial.width + 24 : 18
        y: root.wide ? 20 : root.height - height - 18
        width: root.width - x - (root.wide ? 22 : 18)
        height: root.wide ? root.height - 40 : 44

        Column {
            visible: root.wide
            spacing: 3

            WidgetCaption {
                icon: "focus"
                text: Tr.t("Focus timer")
            }
        }
        // The last seven days as bars, today on the right, with today's count under them.
        Column {
            visible: root.wide
            anchors.right: parent.right
            y: 0
            spacing: 4

            Row {
                anchors.right: parent.right
                spacing: 4

                Repeater {
                    model: root.week

                    Item {
                        id: dayBar

                        required property var modelData
                        required property int index

                        width: 9
                        height: 30

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: Math.max(3, parent.height * dayBar.modelData.n / root.weekTop)
                            radius: 3
                            color: dayBar.modelData.n === 0 ? Qt.alpha(Theme.text, 0.15) : dayBar.index === 6 ? root.tint : Qt.alpha(root.tint, 0.55)
                        }
                    }
                }
            }
            Label {
                anchors.right: parent.right
                text: root.todayText
                size: 10
                color: Theme.muted
            }
            Label {
                anchors.right: parent.right
                text: Tr.t("Week") + ": " + root.weekTotal
                size: 10
                color: Theme.muted
            }
        }

        // Before a timer: quick choices.
        Row {
            visible: !root.active
            anchors.bottom: parent.bottom
            x: root.wide ? 0 : (parent.width - width) / 2
            spacing: 6

            WidgetButton {
                height: 40
                main: true
                icon: "focus"
                text: Tr.t("Pomodoro")
                onClicked: Countdown.pomodoro()
            }
            WidgetButton {
                height: 40
                text: "15"
                onClicked: Countdown.start(15 * 60, "")
            }
            WidgetButton {
                height: 40
                text: "45"
                onClicked: Countdown.start(45 * 60, "")
            }
        }
        // While it runs.
        Row {
            visible: root.active
            anchors.bottom: parent.bottom
            x: root.wide ? 0 : (parent.width - width) / 2
            spacing: 8

            WidgetButton {
                anchors.verticalCenter: parent.verticalCenter
                height: 40
                icon: "close"
                onClicked: Countdown.stop()
            }
            WidgetButton {
                anchors.verticalCenter: parent.verticalCenter
                height: 48
                main: true
                onColor: root.tint
                icon: Countdown.paused ? "play" : "pause"
                onClicked: Countdown.togglePause()
            }
            WidgetButton {
                anchors.verticalCenter: parent.verticalCenter
                height: 40
                text: "+5"
                onClicked: Countdown.add(300)
            }
            WidgetButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: Countdown.phase !== ""
                height: 40
                icon: "next"
                onClicked: {
                    if (Countdown.phase === "break")
                        Countdown.round++;
                    Countdown.startPhase(Countdown.phase === "work" ? "break" : "work");
                }
            }
        }
    }
}
