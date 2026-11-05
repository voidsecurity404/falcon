import QtQuick
import Quickshell
import qs.components
import qs.services

// Three rings for hours, minutes and seconds. Forms: round, wide (the date beside them).
Item {
    id: root

    property string form: "round"
    readonly property bool wide: form === "wide"

    SystemClock {
        id: clock

        precision: SystemClock.Seconds
    }

    Item {
        id: rings

        x: root.wide ? 16 : (parent.width - width) / 2
        y: (parent.height - height) / 2
        width: root.wide ? 140 : 192
        height: width

        readonly property real band: width * 0.058

        Ring {
            anchors.fill: parent
            thickness: rings.band
            color: Theme.accent
            value: (clock.hours % 12 + clock.minutes / 60) / 12
        }
        Ring {
            anchors.fill: parent
            anchors.margins: rings.band * 1.5
            thickness: rings.band
            color: Theme.hueShift(Theme.accent, 0.12)
            value: (clock.minutes + clock.seconds / 60) / 60
        }
        Ring {
            anchors.fill: parent
            anchors.margins: rings.band * 3
            thickness: rings.band
            color: Theme.hueShift(Theme.accent, 0.88)
            animated: false
            value: clock.seconds / 60
        }
        Label {
            anchors.centerIn: parent
            visible: !root.wide
            text: Ui.pad(clock.hours) + ":" + Ui.pad(clock.minutes)
            size: 28
            font.family: Theme.display
            font.weight: Font.Bold
        }
        Label {
            anchors.centerIn: parent
            visible: root.wide
            text: Ui.pad(clock.seconds)
            color: Theme.muted
            size: 16
            font.family: Theme.display
        }
    }
    Column {
        visible: root.wide
        x: rings.x + rings.width + 22
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - x - 14
        spacing: 2

        Label {
            text: Ui.pad(clock.hours) + ":" + Ui.pad(clock.minutes)
            size: 38
            font.family: Theme.display
            font.weight: Font.Bold
        }
        Label {
            width: parent.width
            text: Tr.capitalized(clock.date.toLocaleDateString(Tr.locale, "dddd"))
            color: Theme.muted
            size: 14
        }
    }
}
