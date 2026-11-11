import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.services

// The halo layout's control center, after a phone's: big rounded blocks on a grid. Four round
// switches in one block, the song in the next, tall sliders that fill from below, small square
// switches, round tools and the power mode as one capsule. Each block pops in on its own.
Item {
    id: root

    property bool shown: false
    readonly property int gap: 12
    readonly property int unit: (width - gap * 3) / 4
    readonly property int block: unit * 2 + gap

    implicitHeight: column.implicitHeight

    ControlState {
        id: cs
    }

    // Blocks pop from a little smaller, one after another.
    component Pop: Item {
        id: pop

        property int order: 0
        default property alias content: holder.data

        Item {
            id: holder

            anchors.fill: parent
            transformOrigin: Item.Center
            scale: 0.86
            opacity: 0
        }
        states: State {
            when: root.shown
            PropertyChanges {
                target: holder
                scale: 1
                opacity: 1
            }
        }
        transitions: Transition {
            to: "*"
            SequentialAnimation {
                PauseAnimation {
                    duration: root.shown ? 40 + pop.order * 35 : 0
                }
                ParallelAnimation {
                    NumberAnimation {
                        target: holder
                        property: "scale"
                        duration: root.shown ? 420 : 120
                        easing.type: Easing.OutBack
                        easing.overshoot: 2.2
                    }
                    NumberAnimation {
                        target: holder
                        property: "opacity"
                        duration: root.shown ? 220 : 100
                    }
                }
            }
        }
    }

    component Block: Rectangle {
        anchors.fill: parent
        radius: 24
        color: Qt.alpha(Theme.text, 0.08)
    }

    component RoundSwitch: Column {
        id: sw

        property string icon: ""
        property string title: ""
        property bool on: false
        signal clicked
        signal held

        spacing: 6

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 54
            height: 54
            radius: 27
            color: sw.on ? Theme.accent : Qt.alpha(Theme.text, swArea.containsMouse ? 0.2 : 0.13)
            scale: swArea.pressed ? 0.9 : 1

            Behavior on color {
                ColorAnimation {
                    duration: 180
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: 120
                }
            }

            Icon {
                anchors.centerIn: parent
                name: sw.icon
                size: 22
                color: sw.on ? Theme.accentText : Theme.text
            }
            MouseArea {
                id: swArea

                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => mouse.button === Qt.RightButton ? sw.held() : sw.clicked()
                onPressAndHold: sw.held()
            }
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 76
            horizontalAlignment: Text.AlignHCenter
            text: sw.title
            size: 11
            elide: Text.ElideRight
        }
    }

    // A tall slider that fills from below, its icon at the bottom.
    component TallSlider: ClippingRectangle {
        id: tall

        property string icon: ""
        property real value: 0
        signal moved(real value)
        signal iconClicked

        radius: 24
        color: Qt.alpha(Theme.text, 0.1)

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: parent.height * Math.max(0, Math.min(1, tall.value))
            color: Qt.alpha(Theme.text, 0.92)

            Behavior on height {
                enabled: !tallArea.pressed

                NumberAnimation {
                    duration: 160
                    easing.type: Easing.OutCubic
                }
            }
        }
        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - 38
            name: tall.icon
            size: 22
            color: tall.value > 38 / tall.height ? Theme.glassBase : Theme.text
        }
        MouseArea {
            id: tallArea

            property real startY: 0
            property real startValue: 0
            property bool dragged: false

            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => {
                startY = mouse.y;
                startValue = tall.value;
                dragged = false;
            }
            onPositionChanged: mouse => {
                if (Math.abs(mouse.y - startY) > 3)
                    dragged = true;
                if (dragged)
                    tall.moved(Math.max(0, Math.min(1, startValue + (startY - mouse.y) / height)));
            }
            onReleased: mouse => {
                if (!dragged) {
                    if (mouse.y > height - 48)
                        tall.iconClicked();
                    else
                        tall.moved(Math.max(0, Math.min(1, 1 - mouse.y / height)));
                }
            }
            onWheel: wheel => tall.moved(Math.max(0, Math.min(1, tall.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))))
        }
    }

    component SmallSquare: Rectangle {
        id: square

        property string icon: ""
        property string title: ""
        property bool on: false
        signal clicked

        radius: 22
        color: on ? Theme.accent : Qt.alpha(Theme.text, squareArea.containsMouse ? 0.13 : 0.08)

        Behavior on color {
            ColorAnimation {
                duration: 180
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 5

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: square.icon
                size: 22
                color: square.on ? Theme.accentText : Theme.text
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                width: square.width - 10
                horizontalAlignment: Text.AlignHCenter
                text: square.title
                size: 10
                color: square.on ? Theme.accentText : Theme.text
                elide: Text.ElideRight
            }
        }
        MouseArea {
            id: squareArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: square.clicked()
        }
    }

    Column {
        id: column

        width: root.width
        spacing: root.gap

        Row {
            spacing: root.gap

            // Four round switches in one block.
            Pop {
                order: 0
                width: root.block
                height: root.block

                Block {}
                Grid {
                    anchors.centerIn: parent
                    columns: 2
                    columnSpacing: 10
                    rowSpacing: 6

                    RoundSwitch {
                        icon: cs.wired ? "ethernet" : cs.wifiOn ? "wifi" : "wifiOff"
                        title: cs.wifiNet ? cs.wifiNet.name : Tr.t("Wi-Fi")
                        on: cs.wifiOn
                        onClicked: cs.toggleWifi()
                        onHeld: cs.openWifi()
                    }
                    RoundSwitch {
                        icon: "bluetooth"
                        title: cs.btDevice ? cs.btDevice.name : Tr.t("Bluetooth")
                        on: cs.btOn
                        onClicked: cs.toggleBluetooth()
                        onHeld: cs.openBluetooth()
                    }
                    RoundSwitch {
                        icon: "moon"
                        title: Tr.t("Night")
                        on: Night.enabled
                        onClicked: Night.toggle()
                    }
                    RoundSwitch {
                        icon: "bell"
                        title: Tr.t("Silent")
                        on: Toasts.doNotDisturb
                        onClicked: Toasts.doNotDisturb = !Toasts.doNotDisturb
                    }
                }
            }
            // The song playing, its cover behind it.
            Pop {
                order: 1
                width: root.block
                height: root.block

                ClippingRectangle {
                    anchors.fill: parent
                    radius: 24
                    color: Qt.alpha(Theme.text, 0.08)

                    Image {
                        anchors.fill: parent
                        source: Media.art
                        sourceSize: Qt.size(240, 240)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        opacity: 0.45
                    }
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop {
                                position: 0.3
                                color: "transparent"
                            }
                            GradientStop {
                                position: 1
                                color: Qt.alpha(Theme.glassBase, 0.85)
                            }
                        }
                    }
                    Icon {
                        x: 16
                        y: 16
                        name: "music"
                        size: 20
                        color: Media.artAccent
                    }
                    Column {
                        x: 16
                        y: parent.height - 92
                        width: parent.width - 32

                        Label {
                            width: parent.width
                            text: Media.player ? Media.title : Tr.t("No music")
                            size: 13
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
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: parent.height - 46
                        spacing: 14

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
                                    size: control.modelData === "play" ? 22 : 17
                                    opacity: Media.player ? 1 : 0.4
                                }
                                MouseArea {
                                    anchors.fill: parent
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
        }

        Row {
            spacing: root.gap

            Pop {
                order: 2
                width: root.unit
                height: root.block

                TallSlider {
                    anchors.fill: parent
                    icon: "sun"
                    opacity: Brightness.available ? 1 : 0.4
                    value: Brightness.percent / 100
                    onMoved: v => Brightness.setPercent(v * 100)
                }
            }
            Pop {
                order: 3
                width: root.unit
                height: root.block

                TallSlider {
                    anchors.fill: parent
                    icon: Audio.muted ? "mute" : "volume"
                    value: Audio.muted ? 0 : Audio.volume
                    onMoved: v => Audio.setVolume(v)
                    onIconClicked: Audio.toggleMute()
                }
            }
            Pop {
                order: 4
                width: root.unit
                height: root.block

                TallSlider {
                    anchors.fill: parent
                    icon: Audio.micMuted ? "micOff" : "mic"
                    opacity: Audio.micAvailable ? 1 : 0.4
                    value: Audio.micMuted ? 0 : Audio.micVolume
                    onMoved: v => Audio.setMicVolume(v)
                    onIconClicked: Audio.toggleMicMute()
                }
            }
            Pop {
                order: 5
                width: root.unit
                height: root.block

                Column {
                    anchors.fill: parent
                    spacing: root.gap

                    SmallSquare {
                        width: root.unit
                        height: root.unit
                        icon: "coffee"
                        title: Tr.t("Awake")
                        on: Caffeine.enabled
                        onClicked: cs.toggleCaffeine()
                    }
                    SmallSquare {
                        width: root.unit
                        height: root.unit
                        icon: "game"
                        title: Tr.t("Game")
                        on: GameMode.enabled
                        onClicked: GameMode.toggle()
                    }
                }
            }
        }

        // Round tools.
        Pop {
            order: 6
            width: root.width
            height: toolGrid.implicitHeight + 24

            Block {}
            Grid {
                id: toolGrid

                anchors.centerIn: parent
                columns: 5
                columnSpacing: (root.width - 24 - 5 * 52) / 4
                rowSpacing: 10

                Repeater {
                    model: cs.tools.concat(Power.chargeSupported ? [
                            {
                                id: "limit",
                                icon: "charging",
                                title: Tr.t("Up to {n}%").replace("{n}", Power.limitValue)
                            }
                        ] : [])

                    delegate: Rectangle {
                        id: tool

                        required property var modelData
                        readonly property bool lit: modelData.id === "record" ? Ui.recordBusy : modelData.id === "limit" ? Power.limitOn && !Power.needsSetup : false

                        width: 52
                        height: 52
                        radius: 26
                        color: lit ? Theme.accent : Qt.alpha(Theme.text, toolArea.containsMouse ? 0.18 : 0.1)
                        scale: toolArea.pressed ? 0.9 : 1

                        Behavior on scale {
                            NumberAnimation {
                                duration: 110
                            }
                        }

                        Icon {
                            anchors.centerIn: parent
                            name: tool.modelData.icon
                            size: 20
                            color: tool.lit ? Theme.accentText : Theme.text
                        }
                        MouseArea {
                            id: toolArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: tool.modelData.id === "limit" ? cs.toggleLimit() : cs.use(tool.modelData.id)
                        }
                    }
                }
            }
        }

        // Power mode as one capsule with a sliding light.
        Pop {
            order: 7
            width: root.width
            height: 48

            Rectangle {
                id: modeBar

                anchors.fill: parent
                radius: 24
                color: Qt.alpha(Theme.text, 0.08)

                Rectangle {
                    x: 4 + Math.max(0, cs.mode) * (modeBar.width - 8) / 3
                    y: 4
                    width: (modeBar.width - 8) / 3
                    height: 40
                    radius: 20
                    color: Theme.accent
                    visible: cs.mode >= 0

                    Behavior on x {
                        NumberAnimation {
                            duration: 420
                            easing.type: Easing.OutBack
                        }
                    }
                }
                Row {
                    x: 4
                    y: 4

                    Repeater {
                        model: cs.modes

                        delegate: Item {
                            id: mode

                            required property var modelData
                            required property int index

                            width: (modeBar.width - 8) / 3
                            height: 40
                            opacity: cs.usable(index) ? 1 : 0.4

                            Row {
                                anchors.centerIn: parent
                                spacing: 6

                                Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: mode.modelData.icon
                                    size: 14
                                    color: cs.mode === mode.index ? Theme.accentText : Theme.text
                                }
                                Label {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: mode.modelData.label
                                    size: 12
                                    font.weight: Font.Medium
                                    color: cs.mode === mode.index ? Theme.accentText : Theme.text
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: cs.setMode(mode.index)
                            }
                        }
                    }
                }
            }
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Tr.t("Right click Wi-Fi or Bluetooth for the list")
            size: 11
            color: Theme.muted
        }
    }
}
