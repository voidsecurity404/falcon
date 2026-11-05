import QtQuick
import QtQuick.Shapes
import Quickshell.Widgets
import qs.components
import qs.services

// The charge as a level of liquid, whose surface moves while charging. Forms: tall, wide.
Item {
    id: root

    property string form: "tall"
    readonly property real level: Sys.hasBattery ? Sys.batteryPercent / 100 : 0
    readonly property color tone: Sys.charging ? Theme.good : Sys.batteryPercent <= 15 ? Theme.error : Theme.accent
    readonly property string note: {
        if (!Sys.hasBattery)
            return Tr.t("No battery");
        const seconds = Sys.charging ? Sys.battery.timeToFull : Sys.battery.timeToEmpty;
        if (seconds > 60) {
            const minutes = Math.round(seconds / 60);
            const span = Tr.t("{h} h {m} min").replace("{h}", Math.floor(minutes / 60)).replace("{m}", minutes % 60);
            return Sys.charging ? Tr.t("Full in {t}").replace("{t}", span) : Tr.t("{t} left").replace("{t}", span);
        }
        return Sys.charging ? Tr.t("Charging") : Tr.t("Battery");
    }

    component Wave: Shape {
        id: wave

        property real drift: 0
        property color tint: "white"

        x: -80 + drift
        y: root.height * (1 - root.level) - 7
        width: root.width + 160
        height: root.height + 10
        preferredRendererType: Shape.CurveRenderer

        Behavior on y {
            NumberAnimation {
                duration: 800
                easing.type: Easing.OutCubic
            }
        }

        ShapePath {
            fillColor: wave.tint
            strokeColor: "transparent"
            startX: 0
            startY: 7

            PathSvg {
                path: {
                    let d = "";
                    for (let x = 0; x < wave.width; x += 80)
                        d += "q 20 -10 40 0 q 20 10 40 0 ";
                    return d + "V " + wave.height + " H 0 Z";
                }
            }
        }
    }

    ClippingRectangle {
        anchors.fill: parent
        radius: 22
        color: "transparent"

        Wave {
            tint: Qt.alpha(root.tone, 0.32)
            drift: back.value
        }
        Wave {
            tint: Qt.alpha(root.tone, 0.5)
            drift: 80 - front.value
        }
    }
    QtObject {
        id: back

        property real value: 0

        NumberAnimation on value {
            from: 0
            to: 80
            duration: 2600
            loops: Animation.Infinite
            running: Sys.charging && root.visible
        }
    }
    QtObject {
        id: front

        property real value: 40

        NumberAnimation on value {
            from: 0
            to: 80
            duration: 1900
            loops: Animation.Infinite
            running: Sys.charging && root.visible
        }
    }
    Column {
        anchors.centerIn: parent
        spacing: 2

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: Sys.charging
            name: "charging"
            size: 20
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Sys.hasBattery ? Sys.batteryPercent + "%" : "—"
            size: 36
            font.family: Theme.display
            font.weight: Font.Bold
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.note
            size: 12
            font.weight: Font.Medium
        }
    }
}
