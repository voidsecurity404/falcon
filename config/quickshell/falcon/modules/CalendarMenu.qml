import QtQuick
import Quickshell
import qs.components
import qs.services

// The clock's menu: the month with today marked, arrows to other months, the settings button,
// and the weather of the next days. Opened by a click on the clock or by `desk dashboard` (Mod+D).
Flyout {
    id: root

    property int monthShift: 0
    readonly property var now: clock.date
    readonly property var shownMonth: new Date(now.getFullYear(), now.getMonth() + monthShift, 1)
    readonly property bool thisMonth: monthShift === 0
    readonly property var cells: {
        const year = shownMonth.getFullYear();
        const month = shownMonth.getMonth();
        const offset = (new Date(year, month, 1).getDay() + 6) % 7;
        const days = new Date(year, month + 1, 0).getDate();
        const list = [];
        for (let i = 0; i < offset; i++)
            list.push(0);
        for (let d = 1; d <= days; d++)
            list.push(d);
        return list;
    }
    readonly property int cell: Math.floor((panelWidth - padding * 2) / 7)

    panelWidth: 316
    onShownChanged: {
        if (shown)
            monthShift = 0;
    }

    SystemClock {
        id: clock

        precision: SystemClock.Seconds
    }

    Column {
        width: parent.width
        spacing: 12

        Item {
            width: parent.width
            height: 30

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: Tr.capitalized(Tr.locale.standaloneMonthName(root.shownMonth.getMonth(), Locale.LongFormat)) + " " + root.shownMonth.getFullYear()
                font.family: Theme.display
                size: 15
                font.weight: Font.DemiBold
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    rightPadding: 6
                    text: Ui.pad(clock.hours) + ":" + Ui.pad(clock.minutes) + ":" + Ui.pad(clock.seconds)
                    size: 12
                    color: Theme.muted
                }
                BarButton {
                    objectName: "calPrev"
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "back"
                    iconSize: 15
                    onClicked: root.monthShift -= 1
                }
                BarButton {
                    objectName: "calNext"
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "forward"
                    iconSize: 15
                    onClicked: root.monthShift += 1
                }
                // Opens the Settings window.
                BarButton {
                    objectName: "settings"
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "settings"
                    iconSize: 15
                    onClicked: {
                        Ui.popup = "";
                        Ui.settingsOpen = true;
                    }
                }
            }
        }

        Grid {
            columns: 7
            rowSpacing: 2

            Repeater {
                model: [1, 2, 3, 4, 5, 6, 0].map(d => Tr.locale.dayName(d, Locale.ShortFormat))

                delegate: Label {
                    required property string modelData

                    width: root.cell
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    size: 11
                    color: Theme.muted
                }
            }

            Repeater {
                model: root.cells

                delegate: Item {
                    id: day

                    required property int modelData

                    readonly property bool isToday: root.thisMonth && modelData === root.now.getDate()

                    width: root.cell
                    height: 32

                    Rectangle {
                        anchors.centerIn: parent
                        width: 30
                        height: 30
                        radius: 10
                        visible: day.isToday
                        color: Theme.accent
                    }
                    Label {
                        anchors.centerIn: parent
                        visible: day.modelData > 0
                        text: day.modelData
                        size: 13
                        font.weight: day.isToday ? Font.Bold : Font.Normal
                        color: day.isToday ? Theme.accentText : Theme.text
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Qt.alpha(Theme.text, 0.1)
            visible: forecast.count > 0
        }

        Row {
            width: parent.width
            visible: forecast.count > 0

            Repeater {
                id: forecast

                model: Weather.daily.slice(1, 5)

                delegate: Column {
                    required property var modelData

                    width: parent.width / 4
                    spacing: 4

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Tr.capitalized(new Date(modelData.date).toLocaleDateString(Tr.locale, "ddd"))
                        size: 11
                        color: Theme.muted
                    }
                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: Weather.icon(modelData.code, true)
                        size: 18
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.max + "° / " + modelData.min + "°"
                        size: 12
                        font.weight: Font.Medium
                    }
                }
            }
        }
    }
}
