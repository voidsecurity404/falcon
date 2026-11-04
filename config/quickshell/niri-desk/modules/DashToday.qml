import QtQuick
import Quickshell
import qs.components
import qs.services

// Bugun: o'rtada dumaloq soat, chapda kompyuter yuklamasi, o'ngda sana va kalendar.
Item {
    id: root

    readonly property int sideWidth: (width - clockFace.width - 2 * 28) / 2

    function gigabytes(value) {
        return value.toFixed(value < 100 ? 1 : 0);
    }

    function rate(bytes) {
        if (bytes >= 1048576)
            return (bytes / 1048576).toFixed(1) + " " + Tr.t("MB/s");
        return Math.round(bytes / 1024) + " " + Tr.t("KB/s");
    }

    SystemClock {
        id: clock

        precision: SystemClock.Hours
    }

    // Kompyuter yuklamasi: bosilganda btop ochiladi.
    Item {
        id: system

        width: root.sideWidth
        height: parent.height

        Rectangle {
            anchors.fill: parent
            anchors.margins: -8
            radius: 18
            color: Qt.alpha(Theme.text, systemArea.containsMouse ? 0.05 : 0)

            Behavior on color {
                ColorAnimation {
                    duration: 180
                }
            }
        }
        MouseArea {
            id: systemArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Ui.popup = "";
                Quickshell.execDetached(["kitty", "--class", "niri-desk-tool", "btop"]);
            }
        }

        Column {
            anchors.centerIn: parent
            width: parent.width
            spacing: 16

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

                Gauge {
                    width: (system.width - 8) / 2
                    value: Sys.cpu / 100
                    text: Sys.cpu
                    unit: "%"
                    label: Tr.t("Processor")
                    hot: Sys.cpu >= 85
                }
                Gauge {
                    width: (system.width - 8) / 2
                    value: Sys.ram / 100
                    text: root.gigabytes(Sys.ramGb)
                    detail: Tr.t("of {n} GB").replace("{n}", Math.round(Sys.ramTotalGb))
                    label: Tr.t("Memory")
                    hot: Sys.ram >= 90
                }
            }

            LoadChart {
                width: parent.width
                height: 62
                values: Sys.history
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6

                Gauge {
                    width: (system.width - 12) / 3
                    value: Sys.temperature / 100
                    text: Sys.temperature > 0 ? Sys.temperature : "—"
                    unit: Sys.temperature > 0 ? "°" : ""
                    label: Tr.t("Temperature")
                    hot: Sys.temperature >= 90
                }
                Gauge {
                    width: (system.width - 12) / 3
                    value: Sys.disk / 100
                    text: Sys.disk
                    unit: "%"
                    label: Tr.t("Disk")
                    hot: Sys.disk >= 90
                }
                Gauge {
                    width: (system.width - 12) / 3
                    value: Sys.batteryPercent / 100
                    text: Sys.hasBattery ? Sys.batteryPercent : "—"
                    unit: Sys.hasBattery ? "%" : ""
                    label: Tr.t("Battery")
                    hot: Sys.hasBattery && Sys.batteryPercent <= 15 && !Sys.charging
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 18

                Label {
                    text: "↓ " + root.rate(Sys.netDown)
                    size: 12
                    color: Theme.muted
                }
                Label {
                    text: "↑ " + root.rate(Sys.netUp)
                    size: 12
                    color: Theme.muted
                }
            }
        }
    }

    AnalogClock {
        id: clockFace

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(parent.height, 470)
        height: width
    }

    // Sana, ob-havo, kalendar
    Item {
        anchors.right: parent.right
        width: root.sideWidth
        height: parent.height

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            spacing: 22

            Column {
                width: parent.width
                spacing: 2

                Label {
                    width: parent.width
                    text: Tr.capitalized(clock.date.toLocaleDateString(Tr.locale, "dddd"))
                    size: 34
                    font.weight: Font.Light
                    font.letterSpacing: -0.5
                }
                Label {
                    width: parent.width
                    text: clock.date.toLocaleDateString(Tr.locale, Tr.language === "ru" ? "d MMMM yyyy" : "MMMM d, yyyy")
                    size: 15
                    color: Theme.muted
                }
                Label {
                    width: parent.width
                    topPadding: 6
                    visible: !!Weather.summary && Settings.get("weather.enabled", true)
                    text: Weather.summary
                    color: Theme.accent
                    size: 14
                }
            }

            Calendar {
                width: parent.width
                cellWidth: Math.floor(parent.width / 7)
                cellHeight: 26
            }
        }

        // Sozlamalar: ustiga kelganda g'ildirak aylanadi.
        Rectangle {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: 38
            height: 38
            radius: gearArea.containsMouse ? 13 : 19
            color: Qt.alpha(gearArea.containsMouse ? Theme.accent : Theme.text, gearArea.containsMouse ? 0.26 : 0.08)
            scale: gearArea.pressed ? 0.9 : 1

            Behavior on radius {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: 160
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: 120
                }
            }

            Icon {
                anchors.centerIn: parent
                name: "settings"
                size: 17
                color: gearArea.containsMouse ? Theme.accent : Theme.text
                rotation: gearArea.containsMouse ? 90 : 0

                Behavior on rotation {
                    NumberAnimation {
                        duration: 520
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.3, 1.3, 0.4, 1, 1, 1]
                    }
                }
            }
            MouseArea {
                id: gearArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Ui.popup = "";
                    Ui.settingsOpen = true;
                }
            }
        }
    }
}
