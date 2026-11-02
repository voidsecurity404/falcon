import QtQuick
import Quickshell
import qs.components
import qs.services

// Bugun: vaqt, ob-havo, diqqat taymeri va kalendar.
Item {
    id: root

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    Column {
        width: 360
        spacing: 6

        Label {
            text: Ui.pad(clock.hours) + ":" + Ui.pad(clock.minutes)
            size: 72
            font.weight: Font.Light
            font.letterSpacing: -2
        }
        Label {
            width: parent.width
            text: {
                const date = clock.date.toLocaleDateString(Tr.locale, Tr.language === "ru" ? "d MMMM" : "MMMM d");
                return Weather.summary && Settings.get("weather.enabled", true) ? date + " · " + Weather.summary : date;
            }
            color: Theme.muted
            size: 15
        }

        Item {
            width: 1
            height: 14
        }

        Rectangle {
            width: parent.width
            height: 118
            radius: 13
            color: Qt.alpha(Theme.text, 0.05)

            Column {
                x: 16
                y: 13
                width: parent.width - 32
                spacing: 6

                Label {
                    text: Pomodoro.phase === "work" ? Tr.t("Focus time") : Pomodoro.phase === "rest" ? Tr.t("Break") : Tr.t("Focus timer")
                    color: Theme.muted
                    size: 13
                }
                Label {
                    text: Pomodoro.active ? Pomodoro.label : Ui.pad(Number(Settings.get("pomodoro.work", 25))) + ":00"
                    size: 30
                    font.weight: Font.Medium
                    color: Pomodoro.paused ? Theme.muted : Theme.text
                }
                Row {
                    spacing: 6

                    Repeater {
                        model: [
                            {
                                text: Pomodoro.active ? (Pomodoro.paused ? Tr.t("Resume") : Tr.t("Stop")) : Tr.t("Start"),
                                run: () => Pomodoro.active ? Pomodoro.togglePause() : Pomodoro.start()
                            },
                            {
                                text: Tr.t("Cancel"),
                                run: () => Pomodoro.reset()
                            }
                        ]

                        delegate: Rectangle {
                            id: pomoButton

                            required property var modelData

                            width: pomoLabel.implicitWidth + 20
                            height: 26
                            radius: 8
                            color: Qt.alpha(Theme.text, pomoArea.containsMouse ? 0.14 : 0.08)

                            Label {
                                id: pomoLabel

                                anchors.centerIn: parent
                                text: pomoButton.modelData.text
                                size: 13
                            }
                            MouseArea {
                                id: pomoArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: pomoButton.modelData.run()
                            }
                        }
                    }
                }
            }
        }
    }

    Calendar {
        anchors.right: parent.right
        width: 210
    }
}
