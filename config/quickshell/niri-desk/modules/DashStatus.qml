import QtQuick
import Quickshell
import qs.components
import qs.services

// Holat: musiqa va tizim yuklamasi.
Item {
    id: root

    function openMonitor() {
        Ui.popup = "";
        Quickshell.execDetached(["kitty", "--class", "niri-desk-tool", "btop"]);
    }

    MediaCard {
        width: 360
        artSize: 110
    }

    Column {
        anchors.right: parent.right
        width: 370
        spacing: 22

        Label {
            text: Tr.t("System")
            color: Theme.muted
            size: 13
        }

        Row {
            spacing: 26

            Ring {
                value: Sys.cpu
                label: "CPU"
                onClicked: root.openMonitor()
            }
            Ring {
                value: Sys.ram
                label: "RAM"
                onClicked: root.openMonitor()
            }
            Ring {
                value: Sys.disk
                label: "DISK"
                onClicked: root.openMonitor()
            }
            Ring {
                visible: Sys.hasBattery
                value: Sys.batteryPercent
                label: "BAT"
                onClicked: root.openMonitor()
            }
        }

        Label {
            text: Tr.t("Memory used:") + " " + Sys.ramGb.toFixed(1) + " GB"
            color: Theme.muted
            size: 13
        }
    }
}
