import QtQuick
import QtQuick.Effects
import Quickshell
import qs.components
import qs.services

// Bold hours and thin minutes right on the wallpaper. Forms: stacked, line, small.
Item {
    id: root

    property string form: "stacked"
    readonly property bool stacked: form === "stacked"
    readonly property int digits: stacked ? 124 : form === "line" ? 104 : 66

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    Item {
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowOpacity: 0.55
            shadowBlur: 0.9
            shadowVerticalOffset: 3
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.stacked ? 4 : 0

            Grid {
                columns: root.stacked ? 1 : 2
                columnSpacing: root.form === "line" ? 14 : 8
                rowSpacing: -26

                Label {
                    text: Ui.pad(clock.hours)
                    color: "white"
                    size: root.digits
                    font.family: Theme.display
                    font.weight: Font.ExtraBold
                }
                Label {
                    text: Ui.pad(clock.minutes)
                    color: Qt.lighter(Theme.hueShift(Theme.accent, 0), 1.12)
                    size: root.digits
                    font.family: Theme.display
                    font.weight: Font.ExtraLight
                }
            }
            Label {
                leftPadding: 4
                text: Tr.capitalized(clock.date.toLocaleDateString(Tr.locale, Tr.language === "ru" ? "dddd, d MMMM" : "dddd, MMMM d"))
                color: "white"
                size: root.form === "small" ? 13 : 17
                font.weight: Font.Medium
            }
        }
    }
}
