import QtQuick
import qs.components
import qs.services

// Processor, memory and temperature as rings in three colors. Forms: wide (with names), round.
Item {
    id: root

    property string form: "wide"
    readonly property bool wide: form === "wide"
    readonly property var meters: [
        { title: Tr.t("Processor"), value: Sys.cpu + "%", share: Sys.cpu / 100, color: Theme.accent },
        { title: Tr.t("Memory"), value: Sys.ram + "%", share: Sys.ram / 100, color: Theme.hueShift(Theme.accent, 0.3) },
        { title: Tr.t("Temperature"), value: Sys.temperature > 0 ? Sys.temperature + "°" : "—", share: Sys.temperature / 100, color: Theme.hueShift(Theme.accent, 0.62) }
    ]

    Item {
        id: dial

        x: root.wide ? 18 : (parent.width - width) / 2
        y: (parent.height - height) / 2
        width: root.wide ? 144 : 164
        height: width

        Repeater {
            model: root.meters

            delegate: Ring {
                required property var modelData
                required property int index

                anchors.fill: parent
                anchors.margins: index * dial.width * 0.125
                thickness: dial.width * 0.095
                color: modelData.color
                value: modelData.share
            }
        }
    }
    Column {
        visible: root.wide
        x: dial.x + dial.width + 20
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Repeater {
            model: root.meters

            delegate: Column {
                id: legend

                required property var modelData

                Label {
                    text: legend.modelData.value
                    color: legend.modelData.color
                    size: 22
                    font.family: Theme.display
                    font.weight: Font.Medium
                }
                Label {
                    text: legend.modelData.title
                    color: Theme.muted
                    size: 12
                }
            }
        }
    }
}
