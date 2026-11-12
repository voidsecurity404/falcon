import QtQuick
import Quickshell.Services.UPower
import Quickshell.Widgets
import qs.components
import qs.services

// The battery as a large cell, the time left, the power mode in one press and the charge limit.
// Forms: wide, square.
Item {
    id: root

    readonly property bool widgetRoot: true
    property string widgetId: ""
    property string form: "wide"
    readonly property bool square: form === "square"
    readonly property var device: UPower.displayDevice
    readonly property int percent: Sys.batteryPercent
    readonly property bool charging: Sys.charging
    readonly property bool full: Sys.hasBattery && !UPower.onBattery && !charging
    readonly property color level: !Sys.hasBattery ? Theme.accent : charging ? Theme.good : percent <= 15 ? Theme.error : percent <= 30 ? Theme.hueShift(Theme.accent, 0.92) : Theme.accent
    readonly property var modes: [
        { label: Tr.t("Saver"), icon: "moon", value: PowerProfile.PowerSaver },
        { label: Tr.t("Balanced"), icon: "focus", value: PowerProfile.Balanced },
        { label: Tr.t("Performance"), icon: "bolt", value: PowerProfile.Performance }
    ]

    function span(seconds) {
        const m = Math.round(seconds / 60);
        if (m <= 0)
            return "";
        return m >= 60 ? Math.floor(m / 60) + " " + Tr.t("h") + " " + (m % 60) + " " + Tr.t("min") : m + " " + Tr.t("min");
    }
    readonly property string status: {
        if (!Sys.hasBattery)
            return Tr.t("On mains power");
        if (charging) {
            const t = span(device ? device.timeToFull : 0);
            return t !== "" ? Tr.t("Full in") + " " + t : Tr.t("Charging");
        }
        if (full)
            return Power.limitOn && percent >= Power.limitValue - 1 ? Tr.t("At the limit") : Tr.t("Plugged in");
        const t = span(device ? device.timeToEmpty : 0);
        return t !== "" ? t + " " + Tr.t("left") : Tr.t("On battery");
    }

    // ---------------------------------------------------------------- the cell
    Item {
        id: cell

        x: root.square ? (root.width - width) / 2 : 22
        y: root.square ? 22 : 24
        width: root.square ? 176 : 170
        height: root.square ? 92 : 96

        ClippingRectangle {
            id: body

            width: parent.width - 10
            height: parent.height
            radius: 22
            color: Qt.alpha(root.level, 0.12)
            border.width: 2
            border.color: Qt.alpha(root.level, 0.5)

            Rectangle {
                id: liquid

                width: Math.max(0, (body.width - 8) * (Sys.hasBattery ? root.percent / 100 : 1))
                x: 4
                y: 4
                height: body.height - 8
                radius: 17
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0
                        color: Qt.alpha(root.level, 0.55)
                    }
                    GradientStop {
                        position: 1
                        color: root.level
                    }
                }

                Behavior on width {
                    NumberAnimation {
                        duration: 800
                        easing.type: Easing.OutCubic
                    }
                }

                // A light that runs along while charging.
                Rectangle {
                    visible: root.charging
                    width: 40
                    height: parent.height
                    opacity: 0.45
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0
                            color: "transparent"
                        }
                        GradientStop {
                            position: 0.5
                            color: "white"
                        }
                        GradientStop {
                            position: 1
                            color: "transparent"
                        }
                    }

                    NumberAnimation on x {
                        running: root.charging
                        loops: Animation.Infinite
                        from: -40
                        to: liquid.width
                        duration: 1800
                    }
                }
            }
            Row {
                anchors.centerIn: parent
                spacing: 4

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.charging
                    name: "bolt"
                    size: 22
                    filled: true
                    color: root.percent >= 45 ? Theme.accentText : Theme.text
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Sys.hasBattery ? root.percent + "%" : "AC"
                    font.family: Theme.display
                    font.pixelSize: 30
                    font.weight: Font.Bold
                    color: Sys.hasBattery && root.percent >= 55 ? Theme.accentText : Theme.text
                }
            }
        }
        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 7
            height: parent.height * 0.36
            radius: 3
            color: Qt.alpha(root.level, 0.5)
        }
    }
    Label {
        id: statusLine

        x: root.square ? 0 : cell.x + 2
        width: root.square ? root.width : modesBox.x - cell.x - 12
        y: cell.y + cell.height + 12
        horizontalAlignment: root.square ? Text.AlignHCenter : Text.AlignLeft
        text: root.status
        size: 14
        font.weight: Font.DemiBold
    }
    Label {
        x: statusLine.x
        width: statusLine.width
        y: statusLine.y + 21
        horizontalAlignment: statusLine.horizontalAlignment
        visible: Power.chargeSupported
        text: Power.limitOn ? Tr.t("Charge limit") + " " + Power.limitValue + "%" : Tr.t("No charge limit")
        size: 12
        color: Theme.muted
    }

    // ---------------------------------------------------------------- power mode
    Item {
        id: modesBox

        x: root.square ? 18 : cell.x + cell.width + 26
        y: root.square ? root.height - height - 18 : 20
        width: root.width - x - (root.square ? 18 : 20)
        height: root.square ? 58 : root.height - 40

        WidgetCaption {
            visible: !root.square
            icon: "bolt"
            text: Tr.t("Power mode")
        }
        Grid {
            y: root.square ? 0 : 34
            width: parent.width
            columns: root.square ? 3 : 1
            spacing: 6

            Repeater {
                model: root.modes

                Rectangle {
                    id: mode

                    required property var modelData
                    readonly property bool current: PowerProfiles.profile === modelData.value
                    readonly property bool usable: modelData.value !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile

                    width: root.square ? (modesBox.width - 12) / 3 : modesBox.width
                    height: root.square ? 58 : 36
                    radius: root.square ? 18 : 12
                    opacity: usable ? 1 : 0.4
                    color: current ? Theme.accent : Qt.alpha(Theme.text, modeHot.hovered ? 0.14 : 0.06)
                    scale: modeHot.down ? 0.96 : 1

                    Behavior on color {
                        ColorAnimation {
                            duration: 200
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: 120
                        }
                    }

                    Row {
                        visible: !root.square
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: mode.modelData.icon
                            size: 15
                            color: mode.current ? Theme.accentText : Theme.text
                        }
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: mode.modelData.label
                            size: 13
                            font.weight: mode.current ? Font.DemiBold : Font.Normal
                            color: mode.current ? Theme.accentText : Theme.text
                        }
                    }
                    Column {
                        visible: root.square
                        anchors.centerIn: parent
                        spacing: 4

                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: mode.modelData.icon
                            size: 17
                            color: mode.current ? Theme.accentText : Theme.text
                        }
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: mode.modelData.label
                            size: 10
                            width: Math.min(implicitWidth, mode.width - 6)
                            color: mode.current ? Theme.accentText : Theme.muted
                        }
                    }
                    WidgetHot {
                        id: modeHot

                        anchors.fill: parent
                        onClicked: {
                            if (mode.usable)
                                PowerProfiles.profile = mode.modelData.value;
                        }
                    }
                }
            }
        }
    }
}
