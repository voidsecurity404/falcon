import QtQuick
import Quickshell
import Quickshell.Io
import qs.components
import qs.services

// Time in other cities, with the difference from here. Forms: wide, compact (three cities across).
Item {
    id: root

    property string form: "wide"
    readonly property bool compact: form === "compact"
    readonly property var cities: [
        { name: Tr.t("Moscow"), zone: "Europe/Moscow" },
        { name: Tr.t("London"), zone: "Europe/London" },
        { name: Tr.t("New York"), zone: "America/New_York" },
        { name: Tr.t("Tokyo"), zone: "Asia/Tokyo" }
    ]
    readonly property var rows: compact ? places.slice(0, 3) : places
    property var places: []

    function refresh() {
        reader.running = true;
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
        onMinutesChanged: root.refresh()
    }
    Component.onCompleted: refresh()

    // The system's own zone data knows every clock change, a fixed table would not.
    Process {
        id: reader

        command: ["sh", "-c", 'date +%z; for z in "$@"; do TZ=$z date "+%H:%M %z"; done', "falcon"].concat(root.cities.map(c => c.zone))
        stdout: StdioCollector {
            onStreamFinished: {
                const minutes = z => (z[0] === "-" ? -1 : 1) * (Number(z.slice(1, 3)) * 60 + Number(z.slice(3, 5)));
                const lines = text.trim().split("\n");
                const here = minutes(lines[0]);
                root.places = root.cities.map((city, i) => {
                    const parts = (lines[i + 1] || "--:-- +0000").split(" ");
                    const diff = (minutes(parts[1]) - here) / 60;
                    return {
                        name: city.name,
                        time: parts[0],
                        day: Number(parts[0].slice(0, 2)) >= 7 && Number(parts[0].slice(0, 2)) < 19,
                        diff: (diff > 0 ? "+" : diff < 0 ? "−" : "") + Math.abs(diff) + " " + Tr.t("h")
                    };
                });
            }
        }
    }

    Column {
        visible: !root.compact
        anchors.fill: parent
        anchors.margins: 16
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        spacing: 4

        Repeater {
            model: root.compact ? [] : root.rows

            delegate: Item {
                id: city

                required property var modelData

                width: parent.width
                height: 40

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: city.modelData.day ? "sun" : "moon"
                    size: 18
                    color: city.modelData.day ? Theme.accent : Theme.muted
                }
                Column {
                    x: 30
                    anchors.verticalCenter: parent.verticalCenter

                    Label {
                        text: city.modelData.name
                        size: 14
                        font.weight: Font.Medium
                    }
                    Label {
                        text: city.modelData.diff
                        color: Theme.muted
                        size: 11
                    }
                }
                Label {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: city.modelData.time
                    size: 24
                    font.family: Theme.display
                    font.weight: Font.Medium
                }
            }
        }
    }
    Row {
        visible: root.compact
        anchors.centerIn: parent
        spacing: 16

        Repeater {
            model: root.compact ? root.rows : []

            delegate: Column {
                id: column

                required property var modelData

                width: 120
                spacing: 2

                Row {
                    spacing: 6

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: column.modelData.day ? "sun" : "moon"
                        size: 13
                        color: column.modelData.day ? Theme.accent : Theme.muted
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: column.modelData.name
                        color: Theme.muted
                        size: 12
                    }
                }
                Label {
                    text: column.modelData.time
                    size: 25
                    font.family: Theme.display
                    font.weight: Font.Medium
                }
            }
        }
    }
}
