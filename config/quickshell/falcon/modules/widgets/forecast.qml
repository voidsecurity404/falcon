import QtQuick
import qs.components
import qs.services

// The coming days. Forms: wide (rows with a range bar), across (columns).
Item {
    id: root

    property string form: "wide"
    readonly property var days: Weather.daily.slice(0, 5)
    readonly property int low: days.length ? Math.min(...days.map(d => d.min)) : 0
    readonly property int high: days.length ? Math.max(...days.map(d => d.max)) : 1

    function dayName(day, index) {
        if (index === 0)
            return Tr.t("Today");
        return Tr.capitalized(new Date(day.date).toLocaleDateString(Tr.locale, "ddd"));
    }

    Label {
        anchors.centerIn: parent
        visible: root.days.length === 0
        text: Tr.t("No weather data")
        color: Theme.muted
    }
    Column {
        visible: root.form !== "across"
        x: 20
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 40
        spacing: 3

        Repeater {
            model: root.form !== "across" ? root.days : []

            delegate: Item {
                id: row

                required property var modelData
                required property int index

                width: parent.width
                height: 40

                Label {
                    width: 72
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.dayName(row.modelData, row.index)
                    size: 14
                    font.weight: row.index === 0 ? Font.DemiBold : Font.Normal
                }
                Icon {
                    x: 76
                    anchors.verticalCenter: parent.verticalCenter
                    name: Weather.icon(row.modelData.code, true)
                    size: 21
                    color: Theme.accent
                }
                Label {
                    x: 110
                    width: 32
                    horizontalAlignment: Text.AlignRight
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.min + "°"
                    color: Theme.muted
                    size: 14
                }
                Rectangle {
                    id: track

                    x: 150
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - x - 44
                    height: 6
                    radius: 3
                    color: Qt.alpha(Theme.text, 0.1)

                    Rectangle {
                        readonly property real span: Math.max(1, root.high - root.low)

                        x: track.width * (row.modelData.min - root.low) / span
                        width: Math.max(8, track.width * (row.modelData.max - row.modelData.min) / span)
                        height: parent.height
                        radius: 3
                        gradient: Gradient {
                            orientation: Gradient.Horizontal

                            GradientStop {
                                position: 0
                                color: Theme.accent
                            }
                            GradientStop {
                                position: 1
                                color: Theme.hueShift(Theme.accent, 0.92)
                            }
                        }
                    }
                }
                Label {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.max + "°"
                    size: 14
                    font.weight: Font.Medium
                }
            }
        }
    }
    Row {
        visible: root.form === "across"
        anchors.centerIn: parent

        Repeater {
            model: root.form === "across" ? root.days : []

            delegate: Column {
                id: column

                required property var modelData
                required property int index

                width: 82
                spacing: 7

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.dayName(column.modelData, column.index)
                    color: column.index === 0 ? Theme.text : Theme.muted
                    size: 13
                    font.weight: column.index === 0 ? Font.DemiBold : Font.Normal
                }
                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: Weather.icon(column.modelData.code, true)
                    size: 30
                    color: Theme.accent
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: column.modelData.max + "°"
                    size: 18
                    font.weight: Font.DemiBold
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: column.modelData.min + "°"
                    color: Theme.muted
                    size: 13
                }
            }
        }
    }
}
