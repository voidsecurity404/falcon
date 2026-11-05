import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import qs.components
import qs.services

// Network, quick switches, levels, tools and power mode on glass. The panel drops down from the
// status pill by growing its own size, because the blur region follows that and not a scale.
Rectangle {
    id: root

    property bool shown: false
    property real reveal: 0
    readonly property int panelWidth: 430
    readonly property int padding: 16
    readonly property real pageHeight: (Ui.controlPage === "" ? content.implicitHeight : pageLoader.implicitHeight) + padding * 2
    property real shownHeight: pageHeight

    onShownChanged: {
        revealAnimation.stop();
        revealAnimation.to = shown ? 1 : 0;
        revealAnimation.duration = shown ? 460 : 200;
        revealAnimation.easing.type = shown ? Easing.OutBack : Easing.InCubic;
        revealAnimation.start();
    }
    onHeightChanged: Ui.controlHeight = height

    signal releaseFocus

    function tool(name) {
        Ui.popup = "";
        Ui.run(name);
    }

    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)

    width: 320 + (panelWidth - 320) * reveal
    height: shownHeight * reveal
    clip: true
    radius: 28
    border.width: 1
    border.color: Theme.panelEdge
    // Stays dark enough for its text over a white window, whatever the panel opacity is.
    gradient: Gradient {
        GradientStop {
            position: 0
            color: Qt.alpha(Theme.glassBase, Math.max(0.7, Theme.glassOpacity))
        }
        GradientStop {
            position: 1
            color: Qt.alpha(Theme.glassBase, Math.max(0.58, Theme.glassOpacity))
        }
    }
    opacity: Math.min(1, reveal * 3)
    visible: reveal > 0

    NumberAnimation {
        id: revealAnimation

        target: root
        property: "reveal"
        easing.overshoot: 0.7
        onFinished: {
            if (!root.shown)
                Ui.controlPage = "";
        }
    }

    Behavior on shownHeight {
        enabled: root.reveal >= 1

        NumberAnimation {
            duration: 380
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.25, 1.1, 0.35, 1, 1, 1]
        }
    }

    // Panel ichidagi bosish orqadagi catcher'ga o'tib ketmasin.
    MouseArea {
        anchors.fill: parent
    }

    // Keeps its size while the panel grows, so nothing inside reflows.
    Item {
        x: root.width - width
        y: Settings.bottom ? root.height - height : 0
        width: root.panelWidth
        height: root.pageHeight

        // Wi-Fi and Bluetooth lists open in place of the main page.
        Loader {
            id: pageLoader

            x: root.padding
            y: root.padding
            width: parent.width - root.padding * 2
            active: Ui.controlPage !== ""
            source: Ui.controlPage === "wifi" ? "WifiPage.qml" : Ui.controlPage === "bluetooth" ? "BluetoothPage.qml" : Ui.controlPage === "sound" ? "SoundPage.qml" : ""
            opacity: status === Loader.Ready ? 1 : 0
            transform: Translate {
                x: pageLoader.status === Loader.Ready ? 0 : 28

                Behavior on x {
                    NumberAnimation {
                        duration: 360
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.25, 1.2, 0.35, 1, 1, 1]
                    }
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                }
            }
        }

        Connections {
            target: pageLoader.item
            ignoreUnknownSignals: true

            function onReleaseFocus() {
                root.releaseFocus();
            }
        }

        Column {
            id: content

            x: root.padding
            y: root.padding
            width: parent.width - root.padding * 2
            spacing: 10
            visible: opacity > 0
            opacity: Ui.controlPage === "" ? 1 : 0
            transform: Translate {
                x: Ui.controlPage === "" ? 0 : -28

                Behavior on x {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                }
            }

            // Tarmoq
            Reveal {
                shown: root.shown
                delay: 20

                Row {
                    id: toggles

                    readonly property var adapter: Bluetooth.defaultAdapter
                    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) || null
                    readonly property var wifiNet: wifiDevice ? wifiDevice.networks.values.find(n => n.connected) || null : null
                    readonly property bool wired: Networking.devices.values.some(d => d.type === DeviceType.Wired && d.connected)
                    readonly property var btDevice: adapter && adapter.enabled ? adapter.devices.values.find(d => d.connected) || null : null

                    width: parent.width
                    spacing: 10

                    NetTile {
                        icon: "wifi"
                        title: Tr.t("Wi-Fi")
                        on: Networking.wifiEnabled
                        active: !!toggles.wifiNet
                        sub: toggles.wifiNet ? toggles.wifiNet.name : !Networking.wifiEnabled ? Tr.t("Off") : toggles.wired ? Tr.t("Using cable") : Tr.t("Not connected")
                        onOpen: Ui.controlPage = "wifi"
                        onToggled: {
                            if (Networking.wifiHardwareEnabled)
                                Networking.wifiEnabled = !Networking.wifiEnabled;
                        }
                    }
                    NetTile {
                        icon: "bluetooth"
                        title: Tr.t("Bluetooth")
                        on: !!toggles.adapter && toggles.adapter.enabled
                        active: !!toggles.btDevice
                        sub: toggles.btDevice ? toggles.btDevice.name : !!toggles.adapter && toggles.adapter.enabled ? Tr.t("Not connected") : Tr.t("Off")
                        onOpen: {
                            if (toggles.adapter)
                                Ui.controlPage = "bluetooth";
                        }
                        onToggled: {
                            if (toggles.adapter)
                                toggles.adapter.enabled = !toggles.adapter.enabled;
                        }
                    }
                }
            }

            // Tez tugmalar
            Reveal {
                shown: root.shown
                delay: 60

                Row {
                    width: parent.width
                    spacing: 10

                    QuickTile {
                        icon: "coffee"
                        title: Tr.t("Awake")
                        on: Caffeine.enabled
                        onClicked: {
                            Caffeine.enabled = !Caffeine.enabled;
                            Toasts.show(Caffeine.enabled ? Tr.t("Caffeine on") : Tr.t("Caffeine off"), Caffeine.enabled ? Tr.t("The screen stays on and unlocked") : Tr.t("It will lock when idle again"), "coffee");
                        }
                    }
                    QuickTile {
                        icon: "moon"
                        title: Tr.t("Night")
                        on: Night.enabled
                        onClicked: Night.toggle()
                    }
                    QuickTile {
                        icon: "bell"
                        title: Tr.t("Silent")
                        on: Toasts.doNotDisturb
                        onClicked: Toasts.doNotDisturb = !Toasts.doNotDisturb
                    }
                }
            }

            // Ovoz va yorqinlik
            Reveal {
                shown: root.shown
                delay: 100

                Rectangle {
                    width: parent.width
                    height: levels.height + 12
                    radius: 24
                    color: Qt.alpha(Theme.text, 0.05)

                    Column {
                        id: levels

                        x: 10
                        y: 6
                        width: parent.width - 20

                        LevelRow {
                            width: parent.width
                            visible: Audio.available
                            icon: Audio.muted ? "mute" : "volume"
                            dimmed: Audio.muted
                            value: Audio.volume
                            text: Audio.percent + "%"
                            onMoved: value => Audio.setVolume(value)
                        }
                        LevelRow {
                            width: parent.width
                            visible: Audio.micAvailable
                            icon: Audio.micMuted ? "micOff" : "mic"
                            dimmed: Audio.micMuted
                            iconButton: true
                            value: Audio.micVolume
                            text: Audio.micPercent + "%"
                            onMoved: value => Audio.setMicVolume(value)
                            onIconClicked: Audio.toggleMicMute()
                        }
                        LevelRow {
                            width: parent.width
                            visible: Brightness.available
                            icon: "sun"
                            value: Brightness.percent / 100
                            text: Brightness.percent + "%"
                            onMoved: value => Brightness.setPercent(value * 100)
                        }
                        // Ovoz chiqishi: bittadan ko'p qurilma bo'lsa ochiladi
                        Rectangle {
                            width: parent.width
                            height: 34
                            radius: 12
                            visible: root.sinks.length > 1
                            color: Qt.alpha(Theme.text, sinkArea.containsMouse ? 0.08 : 0)

                            Behavior on color {
                                ColorAnimation {
                                    duration: 140
                                }
                            }

                            Label {
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.right: sinkArrow.left
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: Pipewire.defaultAudioSink ? (Pipewire.defaultAudioSink.description || Pipewire.defaultAudioSink.name) : Tr.t("Sound output")
                                color: Theme.muted
                                size: 12
                            }
                            Icon {
                                id: sinkArrow

                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                name: "forward"
                                size: 12
                                color: Theme.muted
                            }
                            MouseArea {
                                id: sinkArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Ui.controlPage = "sound"
                            }
                        }
                    }
                }
            }

            // Asboblar
            Reveal {
                shown: root.shown
                delay: 140

                Row {
                    width: parent.width

                    ToolButton {
                        icon: "record"
                        title: Tr.t("Record")
                        onClicked: root.tool("niri-desk-record")
                    }
                    ToolButton {
                        icon: "ocr"
                        title: Tr.t("Text")
                        onClicked: root.tool("niri-desk-ocr")
                    }
                    ToolButton {
                        icon: "color"
                        title: Tr.t("Color")
                        onClicked: root.tool("niri-desk-color")
                    }
                    ToolButton {
                        icon: "translate"
                        title: Tr.t("Translate")
                        onClicked: root.tool("niri-desk-translate")
                    }
                    ToolButton {
                        icon: "wallpaper"
                        title: Tr.t("Wallpaper")
                        onClicked: Ui.popup = "wallpapers"
                    }
                    ToolButton {
                        icon: "focus"
                        title: Tr.t("Focus")
                        onClicked: root.tool("niri-desk-zen")
                    }
                }
            }

            // Quvvat rejimi: tanlov belgisi sirpanadi
            Reveal {
                shown: root.shown
                delay: 180

                Rectangle {
                    id: power

                    readonly property var modes: [
                        {
                            label: Tr.t("Saver"),
                            value: PowerProfile.PowerSaver
                        },
                        {
                            label: Tr.t("Balanced"),
                            value: PowerProfile.Balanced
                        },
                        {
                            label: Tr.t("Performance"),
                            value: PowerProfile.Performance
                        }
                    ]
                    readonly property int current: modes.findIndex(m => m.value === PowerProfiles.profile)

                    width: parent.width
                    height: 42
                    radius: 21
                    color: Qt.alpha(Theme.text, 0.05)

                    Rectangle {
                        x: 4 + Math.max(0, power.current) * (power.width - 8) / 3
                        y: 4
                        width: (power.width - 8) / 3
                        height: 34
                        radius: 17
                        color: Theme.accent
                        visible: power.current >= 0

                        Behavior on x {
                            NumberAnimation {
                                duration: 380
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: [0.3, 1.4, 0.4, 1, 1, 1]
                            }
                        }
                    }
                    Row {
                        x: 4
                        y: 4

                        Repeater {
                            model: power.modes

                            delegate: Item {
                                id: profile

                                required property var modelData
                                required property int index

                                readonly property bool usable: modelData.value !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile

                                width: (power.width - 8) / 3
                                height: 34
                                opacity: usable ? 1 : 0.4

                                Label {
                                    anchors.centerIn: parent
                                    text: profile.modelData.label
                                    color: power.current === profile.index ? Theme.accentText : Theme.text
                                    size: 12
                                    font.weight: Font.Medium

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 200
                                        }
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (profile.usable)
                                            PowerProfiles.profile = profile.modelData.value;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
