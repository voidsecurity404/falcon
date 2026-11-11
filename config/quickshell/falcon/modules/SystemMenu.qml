import QtQuick
import Quickshell
import qs.components
import qs.services

// The resource rings' menu: processor, memory, disk and temperature as bars, and the five busiest
// processes. A click on the list opens btop.
Flyout {
    id: root

    readonly property var busiest: Object.values(Processes.byPid).sort((a, b) => b.cpu - a.cpu).slice(0, 5)

    panelWidth: 320

    component Meter: Column {
        id: meter

        property string label: ""
        property string value: ""
        property real share: 0

        width: parent.width
        spacing: 5

        Item {
            width: parent.width
            height: 16

            Label {
                text: meter.label
                size: 12
                color: Theme.muted
            }
            Label {
                anchors.right: parent.right
                text: meter.value
                size: 12
                font.weight: Font.DemiBold
            }
        }
        Rectangle {
            width: parent.width
            height: 6
            radius: 3
            color: Qt.alpha(Theme.text, 0.12)

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, meter.share))
                height: parent.height
                radius: 3
                color: meter.share >= 0.9 ? Theme.error : Theme.accent

                Behavior on width {
                    NumberAnimation {
                        duration: 500
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }

    Column {
        width: parent.width
        spacing: 12

        Label {
            text: Tr.t("System")
            font.family: Theme.display
            size: 15
            font.weight: Font.DemiBold
        }
        Meter {
            label: Tr.t("Processor")
            value: Sys.cpu + "%"
            share: Sys.cpu / 100
        }
        Meter {
            label: Tr.t("Memory")
            value: Sys.ramGb.toFixed(1) + " / " + Sys.ramTotalGb.toFixed(1) + " " + Tr.t("GB")
            share: Sys.ram / 100
        }
        Meter {
            label: Tr.t("Disk")
            value: Sys.diskFreeGb + " " + Tr.t("GB free")
            share: Sys.disk / 100
        }
        Meter {
            label: Tr.t("Temperature")
            value: Sys.temperature > 0 ? Sys.temperature + "°" : "—"
            share: Sys.temperature / 100
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Qt.alpha(Theme.text, 0.1)
        }

        Column {
            objectName: "processes"
            width: parent.width
            spacing: 6

            Repeater {
                model: root.busiest

                delegate: Item {
                    required property var modelData

                    width: parent.width
                    height: 18

                    Label {
                        width: parent.width - 60
                        text: modelData.name
                        font.family: Theme.mono
                        size: 12
                    }
                    Label {
                        anchors.right: parent.right
                        text: modelData.cpu.toFixed(1) + "%"
                        font.family: Theme.mono
                        size: 12
                        color: Theme.muted
                    }
                }
            }
        }

        BarButton {
            objectName: "btop"
            anchors.horizontalCenter: parent.horizontalCenter
            padding: 12
            lit: true
            onClicked: {
                Ui.popup = "";
                Quickshell.execDetached(["kitty", "--class", "falcon-tool", "btop"]);
            }

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: Tr.t("Open the task manager")
                size: 12
                font.weight: Font.Medium
            }
        }
    }
}
