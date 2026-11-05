import QtQuick
import QtQuick.Effects
import Quickshell
import qs.components
import qs.services

// Big clock right on the wallpaper, without a plate. Forms: wide, tall (hours over minutes), compact.
Item {
    id: root

    property string form: "wide"

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    Column {
        anchors.bottom: parent.bottom
        spacing: root.form === "tall" ? 10 : 4
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowOpacity: 0.5
            shadowBlur: 0.8
            shadowVerticalOffset: 2
        }

        Label {
            visible: root.form !== "tall"
            text: Ui.pad(clock.hours) + ":" + Ui.pad(clock.minutes)
            color: "white"
            size: root.form === "compact" ? 72 : 132
            font.weight: Font.Light
            font.letterSpacing: root.form === "compact" ? -2 : -4
        }
        Column {
            visible: root.form === "tall"
            spacing: -30

            Label {
                text: Ui.pad(clock.hours)
                color: "white"
                size: 138
                font.weight: Font.Light
                font.letterSpacing: -4
            }
            Label {
                text: Ui.pad(clock.minutes)
                color: "white"
                size: 138
                font.weight: Font.Light
                font.letterSpacing: -4
            }
        }
        Label {
            leftPadding: root.form === "compact" ? 3 : 6
            text: Tr.capitalized(clock.date.toLocaleDateString(Tr.locale, Tr.language === "ru" ? "dddd, d MMMM" : "dddd, MMMM d"))
            color: "white"
            size: root.form === "compact" ? 15 : 20
        }
    }
}
