import QtQuick
import Quickshell.Bluetooth
import Quickshell.Networking
import qs.components
import qs.services

// Volume and brightness as large sliders and the main switches as tiles. Forms: wide, tall.
Item {
    id: root

    readonly property bool widgetRoot: true
    property string widgetId: ""
    property string form: "wide"
    readonly property bool tall: form === "tall"
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) || null
    readonly property var wifiNet: wifiDevice ? wifiDevice.networks.values.find(n => n.connected) || null : null
    readonly property var btDevice: adapter && adapter.enabled ? adapter.devices.values.find(d => d.connected) || null : null

    readonly property var switches: [
        {
            id: "wifi",
            icon: Networking.wifiEnabled ? "wifi" : "wifiOff",
            label: wifiNet ? wifiNet.name : Tr.t("Wi-Fi"),
            on: Networking.wifiEnabled,
            run: () => {
                if (Networking.wifiHardwareEnabled)
                    Networking.wifiEnabled = !Networking.wifiEnabled;
            }
        },
        {
            id: "bt",
            icon: "bluetooth",
            label: btDevice ? btDevice.name : Tr.t("Bluetooth"),
            on: !!adapter && adapter.enabled,
            run: () => {
                if (root.adapter)
                    root.adapter.enabled = !root.adapter.enabled;
            }
        },
        {
            id: "dnd",
            icon: "bell",
            label: Tr.t("Silent"),
            on: Toasts.doNotDisturb,
            run: () => Toasts.doNotDisturb = !Toasts.doNotDisturb
        },
        {
            id: "night",
            icon: "moon",
            label: Tr.t("Night"),
            on: Night.enabled,
            run: () => Night.toggle()
        },
        {
            id: "caffeine",
            icon: "coffee",
            label: Tr.t("Caffeine"),
            on: Caffeine.enabled,
            run: () => Caffeine.enabled = !Caffeine.enabled
        },
        {
            id: "mic",
            icon: Audio.micMuted ? "micOff" : "mic",
            label: Audio.micMuted ? Tr.t("Mic off") : Tr.t("Microphone"),
            on: Audio.micAvailable && !Audio.micMuted,
            run: () => Audio.toggleMicMute()
        }
    ]

    Column {
        id: sliders

        x: 20
        y: 20
        width: root.tall ? root.width - 40 : 220
        spacing: 12

        WidgetCaption {
            icon: "volume"
            text: Tr.t("Sound and light")
        }
        WidgetSlider {
            width: parent.width
            height: root.tall ? 46 : 48
            icon: Audio.muted || Audio.volume === 0 ? "mute" : "volume"
            value: Audio.volume
            dimmed: Audio.muted
            onMoved: v => Audio.setVolume(v)
            onIconClicked: Audio.toggleMute()
        }
        WidgetSlider {
            width: parent.width
            height: root.tall ? 46 : 48
            visible: Brightness.available
            icon: "sun"
            value: Brightness.percent / 100
            color: Theme.hueShift(Theme.accent, 0.92)
            onMoved: v => Brightness.setPercent(Math.max(1, Math.round(v * 100)))
        }
        WidgetSlider {
            width: parent.width
            height: 46
            visible: root.tall || !Brightness.available
            icon: Audio.micMuted ? "micOff" : "mic"
            value: Audio.micVolume
            dimmed: Audio.micMuted
            color: Theme.hueShift(Theme.accent, 0.18)
            onMoved: v => Audio.setMicVolume(v)
            onIconClicked: Audio.toggleMicMute()
        }
    }

    Grid {
        id: tiles

        readonly property int cols: 3
        readonly property real tileW: (width - spacing * (cols - 1)) / cols

        x: root.tall ? 20 : sliders.x + sliders.width + 18
        y: root.tall ? sliders.y + sliders.height + 18 : 20
        width: root.width - x - 20
        columns: cols
        spacing: 8

        Repeater {
            model: root.switches

            Rectangle {
                id: tile

                required property var modelData

                width: tiles.tileW
                height: root.tall ? 78 : (root.height - 48) / 2
                radius: 20
                color: modelData.on ? (tileHot.hovered ? Qt.lighter(Theme.accent, 1.1) : Theme.accent) : Qt.alpha(Theme.text, tileHot.hovered ? 0.16 : 0.07)
                border.width: modelData.on ? 0 : 1
                border.color: Qt.alpha(Theme.text, 0.06)
                scale: tileHot.down ? 0.94 : 1

                Behavior on color {
                    ColorAnimation {
                        duration: 220
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 140
                        easing.type: Easing.OutBack
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 7

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 34
                        height: 34
                        radius: 17
                        color: tile.modelData.on ? Qt.alpha(Theme.accentText, 0.14) : Qt.alpha(Theme.text, 0.08)

                        Icon {
                            anchors.centerIn: parent
                            name: tile.modelData.icon
                            size: 16
                            color: tile.modelData.on ? Theme.accentText : Theme.text
                        }
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(implicitWidth, tile.width - 12)
                        horizontalAlignment: Text.AlignHCenter
                        text: tile.modelData.label
                        size: 11
                        font.weight: Font.Medium
                        color: tile.modelData.on ? Theme.accentText : Theme.text
                    }
                }
                WidgetHot {
                    id: tileHot

                    anchors.fill: parent
                    onClicked: tile.modelData.run()
                }
            }
        }
    }
}
