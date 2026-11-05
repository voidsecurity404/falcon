import QtQuick
import Quickshell
import qs.components
import qs.services

// Digits made of glowing dots, with the unlit dots still faintly there.
Item {
    id: root

    readonly property int across: 27
    readonly property int down: 7
    readonly property real step: 14.2
    readonly property var font5x7: ({
            "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
            "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
            "2": ["01110", "10001", "00001", "00110", "01000", "10000", "11111"],
            "3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
            "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
            "5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
            "6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
            "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
            "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
            "9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"]
        })
    readonly property string lit: {
        const text = Ui.pad(clock.hours) + Ui.pad(clock.minutes);
        const starts = [0, 6, 16, 22];
        const dots = new Array(across * down).fill("0");
        for (let i = 0; i < 4; i++) {
            const glyph = font5x7[text[i]];
            for (let r = 0; r < down; r++)
                for (let c = 0; c < 5; c++)
                    if (glyph[r][c] === "1")
                        dots[r * across + starts[i] + c] = "1";
        }
        dots[2 * across + 13] = "1";
        dots[4 * across + 13] = "1";
        return dots.join("");
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    Grid {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 18
        columns: root.across

        Repeater {
            model: root.across * root.down

            delegate: Item {
                id: dot

                required property int index
                readonly property bool on: root.lit[index] === "1"

                width: root.step
                height: root.step

                Rectangle {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    radius: 8
                    visible: dot.on
                    color: Qt.alpha(Theme.accent, 0.2)
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 10.5
                    height: 10.5
                    radius: width / 2
                    color: dot.on ? Theme.accent : Qt.alpha(Theme.text, 0.07)
                }
            }
        }
    }
    Label {
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        text: Tr.capitalized(clock.date.toLocaleDateString(Tr.locale, Tr.language === "ru" ? "dddd, d MMMM" : "dddd, MMMM d"))
        color: Theme.muted
        size: 12
    }
}
