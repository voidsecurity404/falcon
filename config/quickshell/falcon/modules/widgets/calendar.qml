import QtQuick
import Quickshell
import qs.components
import qs.services

// Forms: month, week (only the current week).
Item {
    id: root

    property string form: "month"

    SystemClock {
        id: clock

        precision: SystemClock.Hours
    }

    Calendar {
        anchors.centerIn: parent
        visible: root.form !== "week"
        width: 210
    }

    Column {
        anchors.centerIn: parent
        visible: root.form === "week"
        spacing: 8

        Label {
            text: Tr.capitalized(Tr.locale.standaloneMonthName(clock.date.getMonth(), Locale.LongFormat)) + " " + clock.date.getFullYear()
            font.weight: Font.Medium
        }
        Row {
            Repeater {
                model: {
                    const start = new Date(clock.date);
                    start.setDate(start.getDate() - (start.getDay() + 6) % 7);
                    return [0, 1, 2, 3, 4, 5, 6].map(i => {
                        const day = new Date(start);
                        day.setDate(start.getDate() + i);
                        return day;
                    });
                }

                delegate: Column {
                    id: day

                    required property var modelData

                    readonly property bool isToday: modelData.toDateString() === clock.date.toDateString()

                    width: 52
                    spacing: 4

                    Label {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: Tr.locale.dayName(day.modelData.getDay(), Locale.ShortFormat)
                        color: Theme.muted
                        size: 12
                    }
                    Item {
                        width: parent.width
                        height: 28

                        Rectangle {
                            anchors.centerIn: parent
                            width: 28
                            height: 28
                            radius: 14
                            visible: day.isToday
                            color: Theme.accent
                        }
                        Label {
                            anchors.centerIn: parent
                            text: day.modelData.getDate()
                            size: 14
                            font.weight: day.isToday ? Font.DemiBold : Font.Normal
                            color: day.isToday ? Theme.accentText : Theme.text
                        }
                    }
                }
            }
        }
    }
}
