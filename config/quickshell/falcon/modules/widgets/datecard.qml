import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.services

// A page of a desk calendar, in the color of the wallpaper. Forms: square, wide (with the week number).
Item {
    id: root

    property string form: "square"
    readonly property bool wide: form === "wide"
    readonly property var today: clock.date
    readonly property int week: {
        const d = new Date(today.getFullYear(), today.getMonth(), today.getDate());
        d.setDate(d.getDate() + 3 - (d.getDay() + 6) % 7);
        const first = new Date(d.getFullYear(), 0, 4);
        return 1 + Math.round(((d - first) / 86400000 - 3 + (first.getDay() + 6) % 7) / 7);
    }

    SystemClock {
        id: clock

        precision: SystemClock.Hours
    }

    ClippingRectangle {
        anchors.fill: parent
        radius: 22
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.lighter(Theme.accent, 1.08)
                }
                GradientStop {
                    position: 1
                    color: Qt.darker(Theme.accent, 1.22)
                }
            }
        }

        Rectangle {
            width: parent.width
            height: root.wide ? parent.height : 40
            visible: !root.wide
            color: Qt.alpha(Theme.accentText, 0.16)

            Label {
                anchors.centerIn: parent
                text: Tr.capitalized(root.today.toLocaleDateString(Tr.locale, "dddd"))
                color: Theme.accentText
                size: 14
                font.weight: Font.DemiBold
            }
        }
        Column {
            visible: !root.wide
            anchors.horizontalCenter: parent.horizontalCenter
            y: 42
            spacing: -6

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.today.getDate()
                color: Theme.accentText
                size: 72
                font.family: Theme.display
                font.weight: Font.ExtraBold
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Tr.capitalized(root.today.toLocaleDateString(Tr.locale, "MMMM"))
                color: Qt.alpha(Theme.accentText, 0.8)
                size: 14
                font.weight: Font.Medium
            }
        }
        Row {
            visible: root.wide
            anchors.verticalCenter: parent.verticalCenter
            x: 20
            spacing: 18

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: root.today.getDate()
                color: Theme.accentText
                size: 76
                font.family: Theme.display
                font.weight: Font.ExtraBold
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Label {
                    text: Tr.capitalized(root.today.toLocaleDateString(Tr.locale, "dddd"))
                    color: Theme.accentText
                    size: 17
                    font.weight: Font.DemiBold
                }
                Label {
                    text: Tr.capitalized(root.today.toLocaleDateString(Tr.locale, "MMMM"))
                    color: Qt.alpha(Theme.accentText, 0.8)
                    size: 14
                }
                Label {
                    text: Tr.t("Week {n}").replace("{n}", root.week)
                    color: Qt.alpha(Theme.accentText, 0.65)
                    size: 12
                }
            }
        }
    }
}
