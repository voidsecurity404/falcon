import QtQuick
import Quickshell
import qs.services

Column {
    id: root

    readonly property var today: clock.date
    readonly property var cells: {
        const year = today.getFullYear();
        const month = today.getMonth();
        const offset = (new Date(year, month, 1).getDay() + 6) % 7;
        const days = new Date(year, month + 1, 0).getDate();
        const list = [];
        for (let i = 0; i < offset; i++)
            list.push(0);
        for (let d = 1; d <= days; d++)
            list.push(d);
        return list;
    }

    spacing: 9

    SystemClock {
        id: clock

        precision: SystemClock.Hours
    }

    Label {
        text: Tr.capitalized(Tr.locale.standaloneMonthName(root.today.getMonth(), Locale.LongFormat)) + " " + root.today.getFullYear()
        font.weight: Font.Medium
    }

    Grid {
        columns: 7
        columnSpacing: 0
        rowSpacing: 3

        Repeater {
            model: [1, 2, 3, 4, 5, 6, 0].map(d => Tr.locale.dayName(d, Locale.ShortFormat))

            delegate: Label {
                required property string modelData

                width: 30
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                color: Theme.muted
                size: 12
            }
        }

        Repeater {
            model: root.cells

            delegate: Rectangle {
                required property int modelData

                readonly property bool isToday: modelData === root.today.getDate()

                width: 30
                height: 24
                radius: 7
                color: isToday ? Theme.accent : "transparent"

                Label {
                    anchors.centerIn: parent
                    visible: parent.modelData > 0
                    text: parent.modelData
                    size: 13
                    font.weight: parent.isToday ? Font.DemiBold : Font.Normal
                    color: parent.isToday ? Theme.accentText : Theme.text
                }
            }
        }
    }
}
