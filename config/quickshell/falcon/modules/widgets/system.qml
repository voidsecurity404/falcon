import QtQuick
import qs.components
import qs.services

// Forms: wide, tall (figures in two columns), compact (figures only).
Item {
    id: root

    property string form: "wide"

    Column {
        x: 20
        y: root.form === "compact" ? (parent.height - height) / 2 : 16
        width: parent.width - 40
        spacing: 10

        Row {
            visible: root.form !== "compact"
            spacing: 10

            Label {
                id: cpu

                text: Sys.cpu + "%"
                size: 36
                font.weight: Font.Light
            }
            Label {
                anchors.baseline: cpu.baseline
                text: Tr.t("Processor")
                color: Theme.muted
                size: 13
            }
        }
        LoadChart {
            visible: root.form !== "compact"
            width: parent.width
            height: 88
            values: Sys.history
        }
        Grid {
            id: figures

            readonly property int across: root.form === "tall" ? 2 : 4

            width: parent.width
            topPadding: root.form === "tall" ? 8 : 0
            columns: across
            columnSpacing: 16
            rowSpacing: 16

            Stat {
                width: (figures.width - 16 * (figures.across - 1)) / figures.across
                label: Tr.t("Memory")
                value: Sys.ramGb.toFixed(1) + " GB"
                share: Sys.ram / 100
                hot: Sys.ram >= 90
            }
            Stat {
                width: (figures.width - 16 * (figures.across - 1)) / figures.across
                label: Tr.t("Temperature")
                value: Sys.temperature > 0 ? Sys.temperature + "°" : "—"
                share: Sys.temperature / 100
                hot: Sys.temperature >= 90
            }
            Stat {
                width: (figures.width - 16 * (figures.across - 1)) / figures.across
                label: Tr.t("Disk")
                value: Sys.disk + "%"
                share: Sys.disk / 100
                hot: Sys.disk >= 90
            }
            Stat {
                width: (figures.width - 16 * (figures.across - 1)) / figures.across
                label: Tr.t("Battery")
                value: Sys.hasBattery ? Sys.batteryPercent + "%" : "—"
                share: Sys.batteryPercent / 100
                hot: Sys.hasBattery && Sys.batteryPercent <= 15 && !Sys.charging
            }
        }
    }
}
