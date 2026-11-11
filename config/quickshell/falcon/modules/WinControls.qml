import QtQuick
import Quickshell
import qs.components
import qs.services

// The windows layout's control center, after Windows 11's quick settings: a grid of flat buttons
// with their names under them (Wi-Fi and Bluetooth split, the arrow opens the list), thin sliders
// with a ringed knob, the tools, and a darker footer with the battery and the settings gear.
Item {
    id: root

    property bool shown: false
    readonly property int side: 20
    readonly property int buttonWidth: Math.floor((width - side * 2 - 16) / 3)

    implicitHeight: column.implicitHeight + footer.height

    ControlState {
        id: cs
    }

    // A button of the grid: accent when on, the name under it.
    component WinButton: Item {
        id: button

        property string icon: ""
        property string title: ""
        property bool on: false
        property bool split: false
        signal clicked
        signal more

        width: root.buttonWidth
        height: 82

        Rectangle {
            id: face

            width: parent.width
            height: 50
            radius: 6
            color: button.on ? (mainArea.pressed ? Qt.darker(Theme.accent, 1.15) : mainArea.containsMouse || moreArea.containsMouse ? Qt.lighter(Theme.accent, 1.08) : Theme.accent) : Qt.alpha(Theme.text, mainArea.pressed ? 0.04 : mainArea.containsMouse || moreArea.containsMouse ? 0.11 : 0.07)
            border.width: 1
            border.color: button.on ? Qt.alpha("white", 0.12) : Qt.alpha(Theme.text, 0.08)

            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }

            Icon {
                x: button.split ? (parent.width - 30 - size) / 2 : (parent.width - size) / 2
                anchors.verticalCenter: parent.verticalCenter
                name: button.icon
                size: 18
                color: button.on ? Theme.accentText : Theme.text
                scale: mainArea.pressed ? 0.88 : 1

                Behavior on scale {
                    NumberAnimation {
                        duration: 90
                    }
                }
            }
            // The split part: a thin line, then the arrow that opens the list.
            Rectangle {
                visible: button.split
                x: parent.width - 31
                y: 12
                width: 1
                height: parent.height - 24
                color: button.on ? Qt.alpha(Theme.accentText, 0.3) : Qt.alpha(Theme.text, 0.14)
            }
            Icon {
                visible: button.split
                x: parent.width - 23
                anchors.verticalCenter: parent.verticalCenter
                name: "forward"
                size: 13
                color: button.on ? Theme.accentText : Theme.text
            }
            MouseArea {
                id: mainArea

                width: button.split ? parent.width - 31 : parent.width
                height: parent.height
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: button.clicked()
            }
            MouseArea {
                id: moreArea

                x: parent.width - 31
                width: button.split ? 31 : 0
                height: parent.height
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: button.more()
            }
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            y: face.height + 7
            width: parent.width + 6
            horizontalAlignment: Text.AlignHCenter
            text: button.title
            size: 12
            elide: Text.ElideRight
        }
    }

    // Windows 11's slider: a thin track and a round knob with an accent dot that grows on hover.
    component WinSlider: Item {
        id: slider

        property real value: 0
        signal moved(real value)

        height: 32

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 4
            radius: 2
            color: Qt.alpha(Theme.text, 0.3)

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, slider.value))
                height: parent.height
                radius: 2
                color: Theme.accent
            }
        }
        Rectangle {
            x: (slider.width - width) * Math.max(0, Math.min(1, slider.value))
            anchors.verticalCenter: parent.verticalCenter
            width: 20
            height: 20
            radius: 10
            color: Qt.lighter(Theme.glassBase, 1.6)
            border.width: 1
            border.color: Qt.alpha(Theme.text, 0.12)

            Rectangle {
                anchors.centerIn: parent
                property real d: sliderArea.pressed ? 8 : sliderArea.containsMouse ? 14 : 11
                width: d
                height: d
                radius: d / 2
                color: Theme.accent

                Behavior on d {
                    NumberAnimation {
                        duration: 120
                    }
                }
            }
        }
        MouseArea {
            id: sliderArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => slider.moved(Math.max(0, Math.min(1, (mouse.x - 10) / (width - 20))))
            onPositionChanged: mouse => {
                if (pressed)
                    slider.moved(Math.max(0, Math.min(1, (mouse.x - 10) / (width - 20))));
            }
        }
    }

    component SliderRow: Row {
        id: row

        property string icon: ""
        property real value: 0
        property bool muted: false
        signal moved(real value)
        signal iconClicked

        width: root.width - root.side * 2
        spacing: 12

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            height: 34
            radius: 6
            color: Qt.alpha(Theme.text, iconArea.containsMouse ? 0.08 : 0)

            Icon {
                anchors.centerIn: parent
                name: row.icon
                size: 18
                opacity: row.muted ? 0.5 : 1
            }
            MouseArea {
                id: iconArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: row.iconClicked()
            }
        }
        WinSlider {
            anchors.verticalCenter: parent.verticalCenter
            width: row.width - 34 - 12 - 40
            value: row.value
            onMoved: v => row.moved(v)
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            width: 28
            horizontalAlignment: Text.AlignRight
            text: Math.round(row.value * 100)
            size: 12
            color: Theme.muted
        }
    }

    Column {
        id: column

        x: root.side
        width: root.width - root.side * 2
        topPadding: 22
        bottomPadding: 14
        spacing: 6

        Reveal {
            shown: root.shown
            calm: true
            delay: 40

            Grid {
                width: column.width
                columns: 3
                columnSpacing: 8
                rowSpacing: 4

                WinButton {
                    icon: cs.wired ? "ethernet" : cs.wifiOn ? "wifi" : "wifiOff"
                    title: cs.wifiNet ? cs.wifiNet.name : Tr.t("Wi-Fi")
                    on: cs.wifiOn
                    split: true
                    onClicked: cs.toggleWifi()
                    onMore: cs.openWifi()
                }
                WinButton {
                    icon: "bluetooth"
                    title: cs.btDevice ? cs.btDevice.name : Tr.t("Bluetooth")
                    on: cs.btOn
                    split: true
                    onClicked: cs.toggleBluetooth()
                    onMore: cs.openBluetooth()
                }
                WinButton {
                    icon: "battery"
                    title: Tr.t("Battery saver")
                    on: cs.mode === 0
                    onClicked: cs.setMode(cs.mode === 0 ? 1 : 0)
                }
                Repeater {
                    model: cs.switches

                    delegate: WinButton {
                        required property var modelData

                        icon: modelData.icon
                        title: modelData.title
                        on: modelData.on
                        onClicked: cs.flip(modelData.id)
                    }
                }
            }
        }

        Reveal {
            shown: root.shown
            calm: true
            delay: 90

            Column {
                width: column.width
                spacing: 2

                SliderRow {
                    visible: Brightness.available
                    icon: "sun"
                    value: Brightness.percent / 100
                    onMoved: v => Brightness.setPercent(v * 100)
                }
                SliderRow {
                    visible: Audio.available
                    icon: Audio.muted ? "mute" : "volume"
                    muted: Audio.muted
                    value: Audio.volume
                    onMoved: v => Audio.setVolume(v)
                    onIconClicked: Audio.toggleMute()
                }
                SliderRow {
                    visible: Audio.micAvailable
                    icon: Audio.micMuted ? "micOff" : "mic"
                    muted: Audio.micMuted
                    value: Audio.micVolume
                    onMoved: v => Audio.setMicVolume(v)
                    onIconClicked: Audio.toggleMicMute()
                }
            }
        }

        // The tools as a row of plain icons, like the snipping shortcuts.
        Reveal {
            shown: root.shown
            calm: true
            delay: 130

            Row {
                width: column.width
                topPadding: 6
                spacing: (width - cs.tools.length * 32) / (cs.tools.length - 1)

                Repeater {
                    model: cs.tools

                    delegate: Rectangle {
                        id: tool

                        required property var modelData

                        width: 32
                        height: 32
                        radius: 6
                        color: tool.modelData.id === "record" && Ui.recordBusy ? Qt.alpha(Theme.error, 0.3) : Qt.alpha(Theme.text, toolArea.containsMouse ? 0.1 : 0)

                        Icon {
                            anchors.centerIn: parent
                            name: tool.modelData.icon
                            size: 17
                        }
                        MouseArea {
                            id: toolArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: cs.use(tool.modelData.id)
                        }
                    }
                }
            }
        }
    }

    // The footer: battery and power mode on the left, settings on the right.
    Rectangle {
        id: footer

        y: column.height
        width: root.width
        height: 50
        color: Qt.alpha(Theme.glassBase, 0.55)
        bottomLeftRadius: 12
        bottomRightRadius: 12

        Rectangle {
            width: parent.width
            height: 1
            color: Qt.alpha(Theme.text, 0.08)
        }
        Row {
            x: root.side
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: Sys.hasBattery
                name: Sys.charging ? "charging" : "battery"
                size: 18
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                visible: Sys.hasBattery
                text: Sys.batteryPercent + "%"
                size: 13
            }
            // The power mode, a click goes to the next one.
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: modeLabel.implicitWidth + 20
                height: 28
                radius: 6
                color: Qt.alpha(Theme.text, modeArea.containsMouse ? 0.1 : 0.05)

                Label {
                    id: modeLabel

                    anchors.centerIn: parent
                    text: cs.mode >= 0 ? cs.modes[cs.mode].label : "—"
                    size: 12
                    color: Theme.muted
                }
                MouseArea {
                    id: modeArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        let next = (cs.mode + 1) % 3;
                        if (!cs.usable(next))
                            next = 0;
                        cs.setMode(next);
                    }
                }
            }
        }
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: root.side - 6
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            height: 34
            radius: 6
            color: Qt.alpha(Theme.text, gearArea.containsMouse ? 0.1 : 0)

            Icon {
                anchors.centerIn: parent
                name: "settings"
                size: 17
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
