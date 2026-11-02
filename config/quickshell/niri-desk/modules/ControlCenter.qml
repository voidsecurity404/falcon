import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import qs.components
import qs.services

Rectangle {
    id: root

    property bool shown: false

    // O'chirish va qayta yuklash ikki bosishda bajariladi, tasodifiy bosishdan himoya.
    property string armed: ""

    onShownChanged: armed = ""
    onHeightChanged: Ui.controlHeight = height

    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)

    width: 400
    height: content.implicitHeight + 32
    radius: 17
    color: Theme.pill
    opacity: shown ? 1 : 0
    scale: shown ? 1 : 0.96
    transformOrigin: Settings.bottom ? Item.BottomRight : Item.TopRight
    visible: opacity > 0

    Behavior on opacity {
        NumberAnimation {
            duration: 180
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: 240
            easing.type: Easing.OutCubic
        }
    }

    // Panel ichidagi bosish orqadagi catcher'ga o'tib ketmasin.
    MouseArea {
        anchors.fill: parent
    }

    Column {
        id: content

        x: 16
        y: 16
        width: parent.width - 32
        spacing: 15

        Grid {
            id: toggles

            readonly property var adapter: Bluetooth.defaultAdapter
            readonly property bool vpnConfigured: Settings.vpnUp !== ""

            width: parent.width
            columns: 6
            columnSpacing: 7

            Repeater {
                model: [
                    {
                        icon: "wifi",
                        on: Networking.wifiEnabled,
                        enabled: Networking.wifiHardwareEnabled,
                        run: () => Networking.wifiEnabled = !Networking.wifiEnabled
                    },
                    {
                        icon: "bluetooth",
                        on: !!toggles.adapter && toggles.adapter.enabled,
                        enabled: !!toggles.adapter,
                        run: () => toggles.adapter.enabled = !toggles.adapter.enabled
                    },
                    {
                        icon: "shield",
                        on: Lab.vpnAddress !== "",
                        enabled: toggles.vpnConfigured,
                        run: () => {
                            Quickshell.execDetached(["sh", "-c", Lab.vpnAddress !== "" ? Settings.vpnDown : Settings.vpnUp]);
                            refreshLab.restart();
                        }
                    },
                    {
                        icon: "coffee",
                        on: Caffeine.enabled,
                        enabled: true,
                        run: () => {
                            Caffeine.enabled = !Caffeine.enabled;
                            Toasts.show(Caffeine.enabled ? Tr.t("Caffeine on") : Tr.t("Caffeine off"), Caffeine.enabled ? Tr.t("The screen stays on and unlocked") : Tr.t("It will lock when idle again"), "coffee");
                        }
                    },
                    {
                        icon: "moon",
                        on: Night.enabled,
                        enabled: true,
                        run: () => Night.toggle()
                    },
                    {
                        icon: "bell",
                        on: !Toasts.doNotDisturb,
                        enabled: true,
                        run: () => Toasts.doNotDisturb = !Toasts.doNotDisturb
                    }
                ]

                delegate: Rectangle {
                    id: toggle

                    required property var modelData

                    width: (toggles.width - 35) / 6
                    height: 46
                    radius: 12
                    color: modelData.on ? Theme.accent : Qt.alpha(Theme.text, toggleArea.containsMouse && modelData.enabled ? 0.13 : 0.08)
                    opacity: modelData.enabled ? 1 : 0.4

                    Icon {
                        anchors.centerIn: parent
                        name: toggle.modelData.icon
                        size: 18
                        color: toggle.modelData.on ? Theme.accentText : Theme.text
                    }

                    MouseArea {
                        id: toggleArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: toggle.modelData.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (toggle.modelData.enabled)
                                toggle.modelData.run();
                        }
                    }
                }
            }
        }

        Timer {
            id: refreshLab

            interval: 3000
            onTriggered: Lab.refresh()
        }

        Row {
            width: parent.width
            spacing: 11
            visible: Audio.available

            Item {
                width: 20
                height: 20

                Icon {
                    anchors.centerIn: parent
                    name: Audio.muted ? "mute" : "volume"
                    size: 17
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Audio.toggleMute()
                }
            }
            SliderBar {
                width: parent.width - 76
                value: Audio.volume
                onMoved: value => Audio.setVolume(value)
            }
            Label {
                width: 34
                text: Audio.percent + "%"
                color: Theme.muted
                size: 13
                horizontalAlignment: Text.AlignRight
            }
        }

        Row {
            width: parent.width
            spacing: 11
            visible: Brightness.available

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                name: "sun"
                size: 17
            }
            SliderBar {
                width: parent.width - 76
                value: Brightness.percent / 100
                onMoved: value => Brightness.setPercent(value * 100)
            }
            Label {
                width: 34
                text: Brightness.percent + "%"
                color: Theme.muted
                size: 13
                horizontalAlignment: Text.AlignRight
            }
        }

        // Ovoz chiqishi: bittadan ko'p qurilma bo'lsa ko'rinadi
        Column {
            width: parent.width
            spacing: 2
            visible: root.sinks.length > 1

            Repeater {
                model: root.sinks

                delegate: Rectangle {
                    id: sinkRow

                    required property var modelData

                    readonly property bool current: Pipewire.defaultAudioSink === modelData

                    width: parent.width
                    height: 30
                    radius: 8
                    color: sinkArea.containsMouse ? Qt.alpha(Theme.text, 0.08) : "transparent"

                    Label {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: sinkRow.modelData.description || sinkRow.modelData.name
                        color: sinkRow.current ? Theme.accent : Theme.muted
                        size: 13
                    }
                    MouseArea {
                        id: sinkArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Pipewire.preferredDefaultAudioSink = sinkRow.modelData
                    }
                }
            }
        }

        // Quvvat rejimi
        Row {
            width: parent.width
            spacing: 4

            Repeater {
                model: [
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

                delegate: Rectangle {
                    id: profile

                    required property var modelData

                    readonly property bool current: PowerProfiles.profile === modelData.value
                    readonly property bool usable: modelData.value !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile

                    width: (parent.width - 8) / 3
                    height: 30
                    radius: 8
                    color: current ? Qt.alpha(Theme.accent, 0.24) : Qt.alpha(Theme.text, profileArea.containsMouse && usable ? 0.13 : 0.06)
                    opacity: usable ? 1 : 0.4

                    Label {
                        anchors.centerIn: parent
                        text: profile.modelData.label
                        color: profile.current ? Theme.accent : Theme.text
                        size: 13
                    }
                    MouseArea {
                        id: profileArea

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

        Rectangle {
            width: parent.width
            height: media.implicitHeight + 24
            radius: 12
            color: Qt.alpha(Theme.text, 0.05)

            MediaCard {
                id: media

                x: 12
                y: 12
                width: parent.width - 24
                artSize: 56
                showControls: false
            }
        }

        // Xabarlar tarixi
        Column {
            width: parent.width
            spacing: 6

            Item {
                width: parent.width
                height: 18

                Label {
                    text: Tr.t("Notifications")
                    color: Theme.muted
                    size: 12
                }
                Label {
                    anchors.right: parent.right
                    visible: Toasts.history.length > 0
                    text: Tr.t("Clear")
                    color: clearArea.containsMouse ? Theme.text : Theme.muted
                    size: 12

                    MouseArea {
                        id: clearArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Toasts.clearHistory()
                    }
                }
            }

            Label {
                visible: Toasts.history.length === 0
                text: Tr.t("No notifications yet")
                color: Qt.alpha(Theme.text, 0.4)
                size: 13
            }

            Repeater {
                model: Toasts.history.slice(0, 4)

                delegate: Column {
                    id: note

                    required property var modelData

                    width: parent.width
                    spacing: 1

                    Item {
                        width: parent.width
                        height: 18

                        Label {
                            anchors.left: parent.left
                            anchors.right: noteTime.left
                            anchors.rightMargin: 8
                            text: note.modelData.title
                            size: 13
                            font.weight: Font.Medium
                        }
                        Label {
                            id: noteTime

                            anchors.right: parent.right
                            text: note.modelData.time
                            color: Theme.muted
                            size: 12
                        }
                    }
                    Label {
                        width: parent.width
                        visible: note.modelData.sub !== ""
                        text: note.modelData.sub
                        color: Theme.muted
                        size: 12
                    }
                }
            }
        }

        // Sessiya
        Row {
            width: parent.width
            spacing: 7

            Repeater {
                model: [
                    {
                        id: "lock",
                        icon: "lock",
                        confirm: false,
                        run: ["loginctl", "lock-session"]
                    },
                    {
                        id: "sleep",
                        icon: "moon",
                        confirm: false,
                        run: ["systemctl", "suspend"]
                    },
                    {
                        id: "logout",
                        icon: "logout",
                        confirm: true,
                        run: ["niri", "msg", "action", "quit", "--skip-confirmation"]
                    },
                    {
                        id: "reboot",
                        icon: "reboot",
                        confirm: true,
                        run: ["systemctl", "reboot"]
                    },
                    {
                        id: "power",
                        icon: "power",
                        confirm: true,
                        run: ["systemctl", "poweroff"]
                    }
                ]

                delegate: Rectangle {
                    id: sessionButton

                    required property var modelData

                    readonly property bool isArmed: root.armed === modelData.id

                    width: (parent.width - 28) / 5
                    height: 38
                    radius: 11
                    color: isArmed ? Theme.error : Qt.alpha(Theme.text, sessionArea.containsMouse ? 0.13 : 0.06)

                    Icon {
                        anchors.centerIn: parent
                        name: sessionButton.modelData.icon
                        size: 16
                        color: sessionButton.isArmed ? Theme.pill : Theme.text
                    }
                    MouseArea {
                        id: sessionArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const b = sessionButton.modelData;
                            if (b.confirm && root.armed !== b.id) {
                                root.armed = b.id;
                                Toasts.show(Tr.t("Confirm"), Tr.t("Press once more to proceed"), "alert");
                                disarm.restart();
                                return;
                            }
                            root.armed = "";
                            Ui.popup = "";
                            Quickshell.execDetached(b.run);
                        }
                    }
                }
            }
        }

        Timer {
            id: disarm

            interval: 4000
            onTriggered: root.armed = ""
        }
    }
}
