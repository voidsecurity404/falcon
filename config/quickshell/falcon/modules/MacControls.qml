import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.services

// The macos layout's control center, after macOS: rounded modules on frosted glass. A tall
// module with Wi-Fi, Bluetooth and Night Shift, small ones beside it, wide pill sliders for the
// display and the sound, the song playing, the tools and the energy mode.
Item {
    id: root

    property bool shown: false
    readonly property int gap: 8
    readonly property int half: (width - gap) / 2

    implicitHeight: column.implicitHeight

    ControlState {
        id: cs
    }

    component Module: Rectangle {
        radius: 14
        color: Qt.alpha(Theme.text, 0.08)
        border.width: 1
        border.color: Qt.alpha(Theme.text, 0.07)
    }

    // A round switch with its name and state beside it.
    component MacRow: Item {
        id: row

        property string icon: ""
        property string title: ""
        property string sub: ""
        property bool on: false
        signal toggled
        signal open

        width: parent ? parent.width : 0
        height: 40

        Rectangle {
            id: circle

            anchors.verticalCenter: parent.verticalCenter
            width: 30
            height: 30
            radius: 15
            color: row.on ? Theme.accent : Qt.alpha(Theme.text, circleArea.containsMouse ? 0.22 : 0.14)

            Behavior on color {
                ColorAnimation {
                    duration: 160
                }
            }

            Icon {
                anchors.centerIn: parent
                name: row.icon
                size: 15
                color: row.on ? Theme.accentText : Theme.text
            }
            MouseArea {
                id: circleArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: row.toggled()
            }
        }
        Column {
            x: 38
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 38

            Label {
                width: parent.width
                text: row.title
                size: 12
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Label {
                width: parent.width
                visible: row.sub !== ""
                text: row.sub
                size: 11
                color: Theme.muted
                elide: Text.ElideRight
            }
        }
        MouseArea {
            x: 38
            width: parent.width - 38
            height: parent.height
            cursorShape: Qt.PointingHandCursor
            onClicked: row.open()
        }
    }

    // A small square module: icon in a circle, the name under it.
    component MacTile: Module {
        id: tile

        property string icon: ""
        property string title: ""
        property bool on: false
        signal clicked

        color: Qt.alpha(Theme.text, tileArea.containsMouse ? 0.13 : 0.08)

        Column {
            anchors.centerIn: parent
            spacing: 5

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 28
                height: 28
                radius: 14
                color: tile.on ? Theme.accent : Qt.alpha(Theme.text, 0.14)

                Icon {
                    anchors.centerIn: parent
                    name: tile.icon
                    size: 14
                    color: tile.on ? Theme.accentText : Theme.text
                }
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                width: tile.width - 8
                horizontalAlignment: Text.AlignHCenter
                text: tile.title
                size: 10
                elide: Text.ElideRight
            }
        }
        MouseArea {
            id: tileArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.clicked()
        }
    }

    // macOS's wide slider: a pill filled in light from the left, its icon inside.
    component MacSlider: Item {
        id: slider

        property string icon: ""
        property real value: 0
        signal moved(real value)
        signal iconClicked

        width: parent ? parent.width : 0
        height: 26

        ClippingRectangle {
            anchors.fill: parent
            radius: height / 2
            color: Qt.alpha(Theme.text, 0.12)

            Rectangle {
                width: Math.max(slider.height, slider.width * Math.max(0, Math.min(1, slider.value)))
                height: parent.height
                radius: height / 2
                color: Qt.alpha(Theme.text, 0.92)

                Behavior on width {
                    enabled: !sliderArea.pressed

                    NumberAnimation {
                        duration: 140
                    }
                }
            }
        }
        Icon {
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            name: slider.icon
            size: 14
            color: Theme.glassBase
        }
        MouseArea {
            id: sliderArea

            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => {
                if (mouse.x < 26)
                    slider.iconClicked();
                else
                    slider.moved(Math.max(0, Math.min(1, mouse.x / width)));
            }
            onPositionChanged: mouse => {
                if (pressed && mouse.x >= 26)
                    slider.moved(Math.max(0, Math.min(1, mouse.x / width)));
            }
        }
    }

    Column {
        id: column

        width: root.width
        spacing: root.gap

        // Network and the small modules beside it.
        Reveal {
            shown: root.shown
            calm: true
            delay: 30

            Row {
                width: root.width
                spacing: root.gap

                Module {
                    width: root.half
                    height: 150

                    Column {
                        x: 10
                        y: 13
                        width: parent.width - 20
                        spacing: 4

                        MacRow {
                            icon: cs.wired ? "ethernet" : "wifi"
                            title: Tr.t("Wi-Fi")
                            sub: cs.wifiText
                            on: cs.wifiOn
                            onToggled: cs.toggleWifi()
                            onOpen: cs.openWifi()
                        }
                        MacRow {
                            icon: "bluetooth"
                            title: Tr.t("Bluetooth")
                            sub: cs.btText
                            on: cs.btOn
                            onToggled: cs.toggleBluetooth()
                            onOpen: cs.openBluetooth()
                        }
                        MacRow {
                            icon: "moon"
                            title: Tr.t("Night")
                            sub: Night.enabled ? Tr.t("On") : Tr.t("Off")
                            on: Night.enabled
                            onToggled: Night.toggle()
                            onOpen: Night.toggle()
                        }
                    }
                }
                Column {
                    width: root.half
                    spacing: root.gap

                    Module {
                        width: parent.width
                        height: 71

                        MacRow {
                            x: 10
                            width: parent.width - 20
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "bell"
                            title: Tr.t("Silent")
                            sub: Toasts.doNotDisturb ? Tr.t("On") : ""
                            on: Toasts.doNotDisturb
                            onToggled: Toasts.doNotDisturb = !Toasts.doNotDisturb
                            onOpen: Toasts.doNotDisturb = !Toasts.doNotDisturb
                        }
                    }
                    Row {
                        spacing: root.gap

                        MacTile {
                            width: (root.half - root.gap) / 2
                            height: 71
                            icon: "coffee"
                            title: Tr.t("Awake")
                            on: Caffeine.enabled
                            onClicked: cs.toggleCaffeine()
                        }
                        MacTile {
                            width: (root.half - root.gap) / 2
                            height: 71
                            icon: "game"
                            title: Tr.t("Game")
                            on: GameMode.enabled
                            onClicked: GameMode.toggle()
                        }
                    }
                }
            }
        }

        Reveal {
            shown: root.shown
            calm: true
            delay: 70

            Module {
                width: root.width
                height: displayColumn.implicitHeight + 22
                visible: Brightness.available

                Column {
                    id: displayColumn

                    x: 12
                    y: 10
                    width: parent.width - 24
                    spacing: 7

                    Label {
                        text: Tr.t("Display")
                        size: 12
                        font.weight: Font.DemiBold
                    }
                    MacSlider {
                        icon: "sun"
                        value: Brightness.percent / 100
                        onMoved: v => Brightness.setPercent(v * 100)
                    }
                }
            }
        }

        Reveal {
            shown: root.shown
            calm: true
            delay: 100

            Module {
                width: root.width
                height: soundColumn.implicitHeight + 22
                visible: Audio.available

                Column {
                    id: soundColumn

                    x: 12
                    y: 10
                    width: parent.width - 24
                    spacing: 7

                    Label {
                        text: Tr.t("Sound")
                        size: 12
                        font.weight: Font.DemiBold
                    }
                    MacSlider {
                        icon: Audio.muted ? "mute" : "volume"
                        value: Audio.muted ? 0 : Audio.volume
                        onMoved: v => Audio.setVolume(v)
                        onIconClicked: Audio.toggleMute()
                    }
                    MacSlider {
                        visible: Audio.micAvailable
                        icon: Audio.micMuted ? "micOff" : "mic"
                        value: Audio.micMuted ? 0 : Audio.micVolume
                        onMoved: v => Audio.setMicVolume(v)
                        onIconClicked: Audio.toggleMicMute()
                    }
                }
            }
        }

        // The song playing.
        Reveal {
            shown: root.shown
            calm: true
            delay: 130

            Module {
                width: root.width
                height: 62
                visible: !!Media.player

                ClippingRectangle {
                    id: art

                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 42
                    height: 42
                    radius: 8
                    color: Qt.alpha(Theme.text, 0.1)

                    Image {
                        anchors.fill: parent
                        source: Media.art
                        sourceSize: Qt.size(84, 84)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    Icon {
                        anchors.centerIn: parent
                        visible: Media.art === ""
                        name: "music"
                        size: 18
                    }
                }
                Column {
                    x: 62
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 62 - 104

                    Label {
                        width: parent.width
                        text: Media.title
                        size: 12
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Label {
                        width: parent.width
                        text: Media.player ? Media.player.trackArtist : ""
                        size: 11
                        color: Theme.muted
                        elide: Text.ElideRight
                    }
                }
                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter

                    Repeater {
                        model: ["previous", "play", "next"]

                        delegate: Item {
                            id: control

                            required property string modelData

                            width: 32
                            height: 32

                            Icon {
                                anchors.centerIn: parent
                                name: control.modelData === "play" && Media.player && Media.player.isPlaying ? "pause" : control.modelData
                                filled: control.modelData !== "play" || !(Media.player && Media.player.isPlaying)
                                size: control.modelData === "play" ? 18 : 15
                                opacity: controlArea.containsMouse ? 1 : 0.8
                            }
                            MouseArea {
                                id: controlArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const p = Media.player;
                                    if (!p)
                                        return;
                                    if (control.modelData === "previous")
                                        p.previous();
                                    else if (control.modelData === "next")
                                        p.next();
                                    else
                                        p.togglePlaying();
                                }
                            }
                        }
                    }
                }
            }
        }

        // The tools, small square modules.
        Reveal {
            shown: root.shown
            calm: true
            delay: 160

            Grid {
                width: root.width
                columns: 5
                spacing: root.gap

                Repeater {
                    model: cs.tools.concat(Power.chargeSupported ? [
                            {
                                id: "limit",
                                icon: "charging",
                                title: Tr.t("Up to {n}%").replace("{n}", Power.limitValue)
                            }
                        ] : [])

                    delegate: MacTile {
                        required property var modelData

                        width: (root.width - root.gap * 4) / 5
                        height: 62
                        icon: modelData.icon
                        title: modelData.title
                        on: modelData.id === "record" ? Ui.recordBusy : modelData.id === "limit" ? Power.limitOn && !Power.needsSetup : false
                        onClicked: modelData.id === "limit" ? cs.toggleLimit() : cs.use(modelData.id)
                    }
                }
            }
        }

        // Energy mode, three small pills.
        Reveal {
            shown: root.shown
            calm: true
            delay: 190

            Module {
                width: root.width
                height: 44

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    Repeater {
                        model: cs.modes

                        delegate: Rectangle {
                            id: mode

                            required property var modelData
                            required property int index
                            readonly property bool current: cs.mode === index

                            width: (root.width - 20 - 12) / 3
                            height: 30
                            radius: 15
                            opacity: cs.usable(index) ? 1 : 0.4
                            color: current ? Theme.accent : Qt.alpha(Theme.text, modeArea.containsMouse ? 0.1 : 0)

                            Behavior on color {
                                ColorAnimation {
                                    duration: 160
                                }
                            }

                            Label {
                                anchors.centerIn: parent
                                text: mode.modelData.label
                                size: 11
                                font.weight: Font.Medium
                                color: mode.current ? Theme.accentText : Theme.text
                            }
                            MouseArea {
                                id: modeArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: cs.setMode(mode.index)
                            }
                        }
                    }
                }
            }
        }
    }
}
