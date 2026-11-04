import QtQuick
import QtQuick.Effects
import Quickshell
import qs.components
import qs.services

// Big clock right on the wallpaper, without a plate.
Item {
    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    Column {
        anchors.bottom: parent.bottom
        spacing: 4
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowOpacity: 0.5
            shadowBlur: 0.8
            shadowVerticalOffset: 2
        }

        Label {
            text: Ui.pad(clock.hours) + ":" + Ui.pad(clock.minutes)
            color: "white"
            size: 132
            font.weight: Font.Light
            font.letterSpacing: -4
        }
        Label {
            leftPadding: 6
            text: Tr.capitalized(clock.date.toLocaleDateString(Tr.locale, Tr.language === "ru" ? "dddd, d MMMM" : "dddd, MMMM d"))
            color: "white"
            size: 20
        }
    }
}
