import QtQuick
import qs.components
import qs.services

// The month with today marked, leafed through with the arrows. Forms: month, wide (today beside it).
Item {
    id: root

    readonly property bool widgetRoot: true
    property string widgetId: ""
    property string form: "month"
    readonly property bool wide: form === "wide"
    property date today: new Date()
    // Both copies of the widget show the same month.
    readonly property int offset: Widgets.sharedValue(widgetId, "offset", 0)
    readonly property date shown: new Date(today.getFullYear(), today.getMonth() + offset, 1)
    readonly property int firstDay: Qt.locale().firstDayOfWeek % 7
    readonly property int lead: (shown.getDay() - firstDay + 7) % 7
    readonly property int daysInMonth: new Date(shown.getFullYear(), shown.getMonth() + 1, 0).getDate()
    readonly property int rows: Math.ceil((lead + daysInMonth) / 7)
    readonly property color weekend: Theme.hueShift(Theme.accent, 0.5)

    function go(step) {
        Widgets.share(widgetId, "offset", step === 0 ? 0 : offset + step);
    }
    function weekNumber(d) {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        const day = t.getUTCDay() || 7;
        t.setUTCDate(t.getUTCDate() + 4 - day);
        const start = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
        return Math.ceil(((t - start) / 86400000 + 1) / 7);
    }
    function dayOfYear(d) {
        return Math.round((new Date(d.getFullYear(), d.getMonth(), d.getDate()) - new Date(d.getFullYear(), 0, 1)) / 86400000) + 1;
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: {
            const d = new Date();
            if (d.getDate() !== root.today.getDate())
                root.today = d;
        }
    }

    // Today, large, on the left of the wide form.
    Item {
        id: side

        visible: root.wide
        x: 0
        width: root.wide ? 196 : 0
        height: parent.height

        Rectangle {
            anchors.fill: parent
            anchors.margins: 10
            radius: 18
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.alpha(Theme.accent, 0.32)
                }
                GradientStop {
                    position: 1
                    color: Qt.alpha(Theme.accent, 0.08)
                }
            }
            border.width: 1
            border.color: Qt.alpha(Theme.accent, 0.25)
        }
        Column {
            x: 30
            y: 28
            spacing: 2

            Label {
                text: Qt.locale().toString(root.today, "dddd")
                size: 16
                font.weight: Font.DemiBold
                font.capitalization: Font.Capitalize
                color: Theme.accent
            }
            Text {
                text: root.today.getDate()
                font.family: Theme.display
                font.pixelSize: 86
                font.weight: Font.Bold
                color: Theme.text
            }
            Label {
                text: Qt.locale().standaloneMonthName(root.today.getMonth()) + " " + root.today.getFullYear()
                size: 15
                font.capitalization: Font.Capitalize
                color: Theme.muted
            }
        }
        Column {
            x: 30
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 30
            spacing: 6

            Label {
                text: Tr.t("Week") + " " + root.weekNumber(root.today)
                size: 13
                font.weight: Font.Medium
            }
            Item {
                width: 136
                height: 6

                Rectangle {
                    anchors.fill: parent
                    radius: 3
                    color: Qt.alpha(Theme.text, 0.12)
                }
                Rectangle {
                    width: parent.width * root.dayOfYear(root.today) / 365
                    height: parent.height
                    radius: 3
                    color: Theme.accent
                }
            }
            Label {
                text: Tr.t("Day") + " " + root.dayOfYear(root.today) + " / " + (new Date(root.today.getFullYear(), 1, 29).getDate() === 29 ? 366 : 365)
                size: 12
                color: Theme.muted
            }
        }
    }

    Item {
        id: month

        x: side.width + (root.wide ? 6 : 0)
        width: parent.width - x
        height: parent.height

        Row {
            x: 22
            y: 20
            spacing: 8

            Label {
                anchors.baseline: year.baseline
                text: Qt.locale().standaloneMonthName(root.shown.getMonth())
                size: 21
                font.family: Theme.display
                font.weight: Font.DemiBold
                font.capitalization: Font.Capitalize
            }
            Label {
                id: year

                text: root.shown.getFullYear()
                size: 15
                color: Theme.muted
            }
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 16
            y: 15
            spacing: 6

            WidgetButton {
                visible: root.offset !== 0
                height: 32
                icon: "calendar"
                on: true
                onClicked: root.go(0)
            }
            WidgetButton {
                height: 32
                icon: "back"
                onClicked: root.go(-1)
            }
            WidgetButton {
                height: 32
                icon: "forward"
                onClicked: root.go(1)
            }
        }

        Grid {
            id: grid

            readonly property real cell: (month.width - 32) / 7
            readonly property real rowHeight: (month.height - y - (root.wide ? 18 : 40)) / 7

            x: 16
            y: 60
            columns: 7

            // Weekday names.
            Repeater {
                model: 7

                Item {
                    required property int index
                    readonly property int day: (root.firstDay + index) % 7

                    width: grid.cell
                    height: grid.rowHeight

                    Label {
                        anchors.centerIn: parent
                        text: Qt.locale().dayName(parent.day, Locale.ShortFormat)
                        size: 12
                        font.weight: Font.DemiBold
                        font.capitalization: Font.Capitalize
                        color: parent.day === 0 || parent.day === 6 ? Qt.alpha(root.weekend, 0.85) : Theme.muted
                    }
                }
            }
            Repeater {
                model: 42

                Item {
                    id: cell

                    required property int index
                    readonly property date date: new Date(root.shown.getFullYear(), root.shown.getMonth(), index - root.lead + 1)
                    readonly property bool inMonth: date.getMonth() === root.shown.getMonth()
                    readonly property bool isToday: date.toDateString() === root.today.toDateString()
                    readonly property bool weekendDay: date.getDay() === 0 || date.getDay() === 6

                    width: grid.cell
                    height: grid.rowHeight
                    visible: index < root.rows * 7

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height) - 4
                        height: width
                        radius: width / 2
                        visible: cell.isToday
                        color: Theme.accent

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width + 8
                            height: width
                            radius: width / 2
                            color: "transparent"
                            border.width: 2
                            border.color: Qt.alpha(Theme.accent, 0.3)
                        }
                    }
                    Label {
                        anchors.centerIn: parent
                        text: cell.date.getDate()
                        size: 14
                        font.weight: cell.isToday ? Font.Bold : Font.Normal
                        color: cell.isToday ? Theme.accentText : cell.weekendDay ? root.weekend : Theme.text
                        opacity: cell.inMonth ? 1 : 0.28
                    }
                }
            }
        }
        Label {
            visible: !root.wide
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            x: 22
            text: Tr.t("Week") + " " + root.weekNumber(root.today) + "  ·  " + Tr.t("Day") + " " + root.dayOfYear(root.today)
            size: 12
            color: Theme.muted
        }
    }
}
