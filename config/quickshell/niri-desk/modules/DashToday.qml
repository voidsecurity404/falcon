import QtQuick
import Quickshell
import qs.components
import qs.services

// Bugun: zarralardan yig'iladigan vaqt, sana va kompyuter ko'rsatkichlari.
Item {
    id: root

    readonly property var figures: [
        {
            label: Tr.t("Processor"),
            value: Sys.cpu + "%",
            hot: Sys.cpu >= 85
        },
        {
            label: Tr.t("Memory"),
            value: Sys.ramGb.toFixed(1) + " " + Tr.t("GB"),
            hot: Sys.ram >= 90
        },
        {
            label: Tr.t("Temperature"),
            value: Sys.temperature > 0 ? Sys.temperature + "°" : "—",
            hot: Sys.temperature >= 90
        },
        {
            label: Tr.t("Disk"),
            value: Sys.disk + "%",
            hot: Sys.disk >= 90
        },
        {
            label: Tr.t("Battery"),
            value: Sys.hasBattery ? Sys.batteryPercent + "%" : "—",
            hot: Sys.hasBattery && Sys.batteryPercent <= 15 && !Sys.charging
        }
    ]

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    ParticleClock {
        anchors.fill: parent
        centerY: 188
        pointerX: pointer.containsMouse ? pointer.mouseX : -999
        pointerY: pointer.containsMouse ? pointer.mouseY : -999
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    Label {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 322
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        size: 17
        color: Qt.alpha(Theme.text, 0.8)
        text: {
            const date = Tr.capitalized(clock.date.toLocaleDateString(Tr.locale, Tr.language === "ru" ? "dddd, d MMMM yyyy" : "dddd, MMMM d, yyyy"));
            return Weather.summary && Settings.get("weather.enabled", true) ? date + " · " + Weather.summary : date;
        }
    }

    // Kompyuter ko'rsatkichlari: bosilganda btop ochiladi.
    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 42
        anchors.rightMargin: 42
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        height: 62

        Row {
            anchors.fill: parent

            Repeater {
                model: root.figures

                delegate: Column {
                    required property var modelData

                    width: parent.width / root.figures.length
                    spacing: 3

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.label
                        size: 13
                        color: Qt.alpha(Theme.text, 0.75)
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.value
                        size: 27
                        font.weight: Font.Light
                        color: modelData.hot ? Theme.error : Theme.text
                    }
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Ui.popup = "";
                Quickshell.execDetached(["kitty", "--class", "niri-desk-tool", "btop"]);
            }
        }
    }

    // Sozlamalar: ustiga kelganda g'ildirak aylanadi.
    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
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
