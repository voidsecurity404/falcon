import QtQuick
import Quickshell
import qs.components
import qs.services

// This week as seven pills, today lifted out in the accent color.
Item {
    id: root

    readonly property var days: {
        const start = new Date(clock.date);
        start.setDate(start.getDate() - (start.getDay() + 6) % 7);
        return [0, 1, 2, 3, 4, 5, 6].map(i => {
            const day = new Date(start);
            day.setDate(start.getDate() + i);
            return day;
        });
    }

    SystemClock {
        id: clock

        precision: SystemClock.Hours
    }

    Row {
        anchors.centerIn: parent
        spacing: 6

        Repeater {
            model: root.days

            delegate: Rectangle {
                id: pill

                required property var modelData
                readonly property bool isToday: modelData.toDateString() === clock.date.toDateString()
                readonly property bool past: modelData < clock.date && !isToday

                anchors.verticalCenter: parent.verticalCenter
                width: 52
                height: isToday ? 100 : 84
                radius: 18
                color: isToday ? Theme.accent : Qt.alpha(Theme.text, past ? 0.03 : 0.07)

                Column {
                    anchors.centerIn: parent
                    spacing: 5

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Tr.capitalized(Tr.locale.standaloneDayName(pill.modelData.getDay(), Locale.ShortFormat)).slice(0, 2)
                        color: pill.isToday ? Theme.accentText : Theme.muted
                        size: 12
                        font.weight: Font.Medium
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: pill.modelData.getDate()
                        color: pill.isToday ? Theme.accentText : pill.past ? Theme.muted : Theme.text
                        size: pill.isToday ? 24 : 19
                        font.family: Theme.display
                        font.weight: pill.isToday ? Font.Bold : Font.Medium
                    }
                }
            }
        }
    }
}
