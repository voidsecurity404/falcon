import QtQuick
import Quickshell
import qs.components
import qs.services

// How much of this day, week, month and year has gone. Forms: wide (bars), compact (rings).
Item {
    id: root

    property string form: "wide"
    readonly property var parts: {
        const now = clock.date;
        const dayShare = (now.getHours() * 60 + now.getMinutes()) / 1440;
        const inMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
        const first = new Date(now.getFullYear(), 0, 1);
        const inYear = new Date(now.getFullYear(), 1, 29).getMonth() === 1 ? 366 : 365;
        const dayOfYear = Math.floor((new Date(now.getFullYear(), now.getMonth(), now.getDate()) - first) / 86400000 + 0.5);
        return [
            { title: Tr.t("Day"), share: dayShare },
            { title: Tr.t("Week"), share: (((now.getDay() + 6) % 7) + dayShare) / 7 },
            { title: Tr.t("Month"), share: (now.getDate() - 1 + dayShare) / inMonth },
            { title: Tr.t("Year"), share: (dayOfYear + dayShare) / inYear }
        ];
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    Column {
        visible: root.form !== "compact"
        anchors.fill: parent
        anchors.margins: 20
        anchors.topMargin: 16
        spacing: 9

        Repeater {
            model: root.parts

            delegate: Column {
                id: row

                required property var modelData
                required property int index

                width: parent.width
                spacing: 4

                Item {
                    width: parent.width
                    height: 18

                    Label {
                        text: row.modelData.title
                        size: 13
                        font.weight: Font.Medium
                    }
                    Label {
                        anchors.right: parent.right
                        text: Math.floor(row.modelData.share * 100) + "%"
                        color: Theme.muted
                        size: 13
                    }
                }
                Rectangle {
                    width: parent.width
                    height: 10
                    radius: 5
                    color: Qt.alpha(Theme.text, 0.1)

                    Rectangle {
                        width: Math.max(height, parent.width * row.modelData.share)
                        height: parent.height
                        radius: 5
                        color: Theme.hueShift(Theme.accent, row.index * 0.07)
                    }
                }
            }
        }
    }
    Row {
        visible: root.form === "compact"
        anchors.centerIn: parent
        spacing: 26

        Repeater {
            model: root.parts

            delegate: Column {
                id: gauge

                required property var modelData
                required property int index

                spacing: 3

                Ring {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 56
                    height: 56
                    thickness: 6
                    value: gauge.modelData.share
                    color: Theme.hueShift(Theme.accent, gauge.index * 0.07)

                    Label {
                        anchors.centerIn: parent
                        text: Math.floor(gauge.modelData.share * 100)
                        size: 14
                        font.weight: Font.DemiBold
                    }
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: gauge.modelData.title
                    color: Theme.muted
                    size: 11
                }
            }
        }
    }
}
