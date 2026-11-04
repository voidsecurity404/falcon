import QtQuick
import Quickshell
import qs.components
import qs.services

// Bugun: katta soat, kompyuter yuklamasi va kalendar.
Item {
    id: root

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    // Soat
    Item {
        id: hero

        width: 300
        height: parent.height

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            spacing: 2

            Label {
                text: Ui.pad(clock.hours) + ":" + Ui.pad(clock.minutes)
                size: 104
                font.weight: Font.ExtraLight
                font.letterSpacing: -5
            }
            Label {
                width: parent.width
                leftPadding: 4
                text: Tr.capitalized(clock.date.toLocaleDateString(Tr.locale, Tr.language === "ru" ? "dddd, d MMMM" : "dddd, MMMM d"))
                size: 16
            }
            Label {
                width: parent.width
                leftPadding: 4
                topPadding: 6
                visible: !!Weather.summary && Settings.get("weather.enabled", true)
                text: Weather.summary
                color: Theme.muted
                size: 14
            }
        }

        // Sozlamalar: ustiga kelganda g'ildirak aylanadi.
        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 4
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
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

    // Kompyuter yuklamasi
    DashCard {
        id: system

        x: hero.width + 24
        width: 410
        height: parent.height
        delay: 60
        clickable: true
        onClicked: {
            Ui.popup = "";
            Quickshell.execDetached(["kitty", "--class", "niri-desk-tool", "btop"]);
        }

        Column {
            x: 22
            y: 18
            width: parent.width - 44
            spacing: 14

            Item {
                width: parent.width
                height: 74

                Column {
                    spacing: 0

                    Label {
                        text: Tr.t("Processor")
                        color: Theme.muted
                        size: 13
                    }
                    Label {
                        text: Sys.cpu + "%"
                        size: 50
                        font.weight: Font.Light
                        font.letterSpacing: -2
                    }
                }
                Row {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    spacing: 5
                    visible: Sys.cpu >= 85

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "alert"
                        size: 12
                        color: Theme.error
                    }
                    Label {
                        text: Tr.t("High load")
                        color: Theme.error
                        size: 12
                    }
                }
            }

            LoadChart {
                width: parent.width
                height: 142
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

    DashCard {
        x: system.x + system.width + 24
        width: parent.width - x
        height: parent.height
        delay: 120

        Calendar {
            anchors.centerIn: parent
            width: 210
        }
    }
}
