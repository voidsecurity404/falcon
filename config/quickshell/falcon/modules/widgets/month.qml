import QtQuick
import Quickshell
import qs.components
import qs.services

// The whole month, today in a filled circle.
Item {
    id: root

    readonly property var today: clock.date
    readonly property var cells: {
        const first = new Date(today.getFullYear(), today.getMonth(), 1);
        const blank = (first.getDay() + 6) % 7;
        const days = new Date(today.getFullYear(), today.getMonth() + 1, 0).getDate();
        const list = [];
        for (let i = 0; i < blank; i++)
            list.push(0);
        for (let d = 1; d <= days; d++)
            list.push(d);
        return list;
    }
    readonly property var names: [1, 2, 3, 4, 5, 6, 0].map(d => Tr.capitalized(Tr.locale.standaloneDayName(d, Locale.ShortFormat)).slice(0, 2))

    SystemClock {
        id: clock

        precision: SystemClock.Hours
    }

    Row {
        x: 22
        y: 16
        spacing: 8

        Label {
            text: Tr.capitalized(Tr.locale.standaloneMonthName(root.today.getMonth(), Locale.LongFormat))
            size: 21
            font.family: Theme.display
            font.weight: Font.Bold
        }
        Label {
            anchors.baseline: parent.children[0].baseline
            text: root.today.getFullYear()
            color: Theme.muted
            size: 14
        }
    }
    Grid {
        x: 16
        y: 58
        columns: 7

        Repeater {
            model: root.names

            delegate: Item {
                required property string modelData
                required property int index

                width: 38.5
                height: 30

                Label {
                    anchors.centerIn: parent
                    text: parent.modelData
                    color: parent.index >= 5 ? Theme.accent : Theme.muted
                    size: 12
                    font.weight: Font.Medium
                }
            }
        }
        Repeater {
            model: root.cells

            delegate: Item {
                id: cell

                required property int modelData
                required property int index
                readonly property bool isToday: modelData === root.today.getDate()
                readonly property bool weekend: index % 7 >= 5

                width: 38.5
                height: 36

                Rectangle {
                    anchors.centerIn: parent
                    width: 33
                    height: 33
                    radius: 16.5
                    visible: cell.isToday
                    color: Theme.accent
                }
                Label {
                    anchors.centerIn: parent
                    visible: cell.modelData > 0
                    text: cell.modelData
                    color: cell.isToday ? Theme.accentText : cell.weekend ? Theme.accent : Theme.text
                    size: 14
                    font.weight: cell.isToday ? Font.Bold : Font.Normal
                }
            }
        }
    }
}
