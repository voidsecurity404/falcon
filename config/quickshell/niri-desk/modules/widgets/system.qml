import QtQuick
import qs.components
import qs.services

Item {
    Column {
        x: 20
        y: 16
        width: parent.width - 40
        spacing: 10

        Row {
            spacing: 10

            Label {
                text: Sys.cpu + "%"
                size: 36
                font.weight: Font.Light
            }
            Label {
                anchors.baseline: parent.children[0].baseline
                text: Tr.t("Processor")
                color: Theme.muted
                size: 13
            }
        }
        LoadChart {
            width: parent.width
            height: 88
            values: Sys.history
        }
        Row {
            width: parent.width
            spacing: 16

            Stat {
                label: Tr.t("Memory")
                value: Sys.ramGb.toFixed(1) + " GB"
                share: Sys.ram / 100
                hot: Sys.ram >= 90
            }
            Stat {
                label: Tr.t("Temperature")
                value: Sys.temperature > 0 ? Sys.temperature + "°" : "—"
                share: Sys.temperature / 100
                hot: Sys.temperature >= 90
            }
            Stat {
                label: Tr.t("Disk")
                value: Sys.disk + "%"
                share: Sys.disk / 100
                hot: Sys.disk >= 90
            }
            Stat {
                label: Tr.t("Battery")
                value: Sys.hasBattery ? Sys.batteryPercent + "%" : "—"
                share: Sys.batteryPercent / 100
                hot: Sys.hasBattery && Sys.batteryPercent <= 15 && !Sys.charging
            }
        }
    }
}
