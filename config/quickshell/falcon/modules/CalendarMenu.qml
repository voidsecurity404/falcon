import QtQuick
import Quickshell
import qs.components
import qs.services

// The clock's menu: the month with today marked, arrows to other months, the settings button,
// the events of the chosen day (Agenda, from calendar.sources) and the weather of the next days. Opened by a click on the clock or by `desk dashboard` (Mod+D).
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
    // The day whose events are listed; a click on a day picks it.
    property var picked: null
    readonly property var chosenDay: picked || now
    readonly property var dayEvents: Agenda.eventsOn(chosenDay)

    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    function dayTitle(d) {
        const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        const diff = Math.round((new Date(d.getFullYear(), d.getMonth(), d.getDate()) - today) / 86400000);
        if (diff === 0)
            return Tr.t("Today");
        if (diff === 1)
            return Tr.t("Tomorrow");
        if (diff === -1)
            return Tr.t("Yesterday");
        return Tr.capitalized(d.toLocaleDateString(Tr.locale, "dddd, d MMMM"));
    }

    function timeOf(e) {
        if (e.allDay)
            return Tr.t("All day");
        const a = new Date(e.start), b = new Date(e.end);
        const t = x => Ui.pad(x.getHours()) + ":" + Ui.pad(x.getMinutes());
        // An event that started on an earlier day, or ends on a later one, shows only its own end.
        if (!sameDay(a, chosenDay))
            return "… " + t(b);
        if (!sameDay(b, chosenDay) && b - a > 0)
            return t(a) + " …";
        return b - a > 0 ? t(a) + " – " + t(b) : t(a);
    }

    panelWidth: 316
    onShownChanged: {
        if (shown) {
            monthShift = 0;
            picked = null;
            Agenda.refreshIfStale();
        }
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
                model: [1, 2, 3, 4, 5, 6, 0].map(d => Tr.capitalized(Tr.locale.dayName(d, Locale.ShortFormat)))

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
                    readonly property var date: new Date(root.shownMonth.getFullYear(), root.shownMonth.getMonth(), Math.max(1, modelData))
                    readonly property bool isPicked: modelData > 0 && root.picked !== null && root.sameDay(date, root.picked) && !isToday
                    readonly property int count: modelData > 0 && Agenda.configured ? Agenda.eventsOn(date).length : 0

                    width: root.cell
                    height: 32

                    Rectangle {
                        anchors.centerIn: parent
                        width: 30
                        height: 30
                        radius: 10
                        visible: day.isPicked || dayArea.containsMouse && day.modelData > 0 && !day.isToday
                        color: day.isPicked ? Qt.alpha(Theme.accent, 0.22) : Qt.alpha(Theme.text, 0.08)
                    }

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
                    // Up to three dots for the day's events.
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: day.isToday ? 4 : 2
                        spacing: 2
                        visible: day.count > 0

                        Repeater {
                            model: Math.min(3, day.count)

                            delegate: Rectangle {
                                width: 4
                                height: 4
                                radius: 2
                                color: day.isToday ? Theme.accentText : Theme.accent
                            }
                        }
                    }
                    MouseArea {
                        id: dayArea

                        anchors.fill: parent
                        enabled: day.modelData > 0 && Agenda.configured
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.picked = root.sameDay(day.date, root.now) ? null : day.date
                    }
                }
            }
        }

        // The chosen day's events.
        Column {
            width: parent.width
            spacing: 6
            visible: Agenda.configured

            Rectangle {
                width: parent.width
                height: 1
                color: Qt.alpha(Theme.text, 0.1)
            }
            Item {
                width: parent.width
                height: 22

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.dayTitle(root.chosenDay)
                    size: 13
                    font.weight: Font.DemiBold
                }
                Label {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Agenda.loading || Agenda.errors.length > 0
                    text: Agenda.loading ? Tr.t("Updating…") : Tr.t("Offline, last copy")
                    color: Theme.muted
                    size: 11
                }
            }
            Label {
                visible: root.dayEvents.length === 0
                text: Agenda.fetchedAt === 0 ? Tr.t("Loading events…") : Tr.t("No events")
                color: Theme.muted
                size: 12
                bottomPadding: 2
            }
            Repeater {
                model: root.dayEvents.slice(0, 5)

                delegate: Rectangle {
                    id: row

                    required property var modelData
                    readonly property bool past: !modelData.allDay && new Date(modelData.end) < root.now

                    width: parent.width
                    height: eventText.implicitHeight + 14
                    radius: 10
                    color: Qt.alpha(Agenda.colorOf(modelData.source), 0.1)
                    opacity: past ? 0.55 : 1

                    Rectangle {
                        x: 6
                        y: 6
                        width: 3
                        height: parent.height - 12
                        radius: 1.5
                        color: Agenda.colorOf(row.modelData.source)
                    }
                    Column {
                        id: eventText

                        x: 16
                        width: parent.width - 24
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Label {
                            width: parent.width
                            text: row.modelData.title || Tr.t("(no title)")
                            size: 13
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }
                        Label {
                            width: parent.width
                            text: root.timeOf(row.modelData) + (row.modelData.location ? "  ·  " + row.modelData.location : "")
                            color: Theme.muted
                            size: 11
                            elide: Text.ElideRight
                        }
                    }
                }
            }
            Label {
                visible: root.dayEvents.length > 5
                text: Tr.t("And {n} more").replace("{n}", root.dayEvents.length - 5)
                color: Theme.muted
                size: 11
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

                model: Weather.hasData ? Weather.daily.slice(1, 5) : []

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
