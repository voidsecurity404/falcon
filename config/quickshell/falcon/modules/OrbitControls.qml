import QtQuick
import Quickshell
import qs.components
import qs.services

// The orbit layout's control center, a round one. A dial in the middle sets the volume, the
// brightness or the microphone (drag around it or use the wheel), the switches circle it on an
// inner orbit and the tools and power modes on an outer one. On opening they spiral out from the
// middle, and the dial names whatever the pointer is on.
Item {
    id: root

    property bool shown: false
    property real reveal: 1
    property int size: 420
    // What the dial sets: 0 volume, 1 brightness, 2 microphone.
    property int dialing: 0
    property string hoverTitle: ""
    readonly property real center: size / 2

    implicitHeight: size
    width: size

    ControlState {
        id: cs
    }

    readonly property var inner: [
        {
            id: "wifi",
            icon: cs.wired ? "ethernet" : cs.wifiOn ? "wifi" : "wifiOff",
            title: Tr.t("Wi-Fi") + " · " + cs.wifiText + "\n" + Tr.t("Right click: list"),
            on: cs.wifiOn
        },
        {
            id: "bluetooth",
            icon: "bluetooth",
            title: Tr.t("Bluetooth") + " · " + cs.btText + "\n" + Tr.t("Right click: list"),
            on: cs.btOn
        }
    ].concat(cs.switches)
    readonly property var outer: cs.tools.concat(cs.modes.map((m, i) => ({
                id: "mode" + i,
                icon: m.icon,
                title: m.label,
                mode: true,
                on: cs.mode === i
            })))

    readonly property real dialValue: dialing === 0 ? (Audio.muted ? 0 : Audio.volume) : dialing === 1 ? Brightness.percent / 100 : (Audio.micMuted ? 0 : Audio.micVolume)
    function setDial(v) {
        v = Math.max(0, Math.min(1, v));
        if (dialing === 0)
            Audio.setVolume(v);
        else if (dialing === 1)
            Brightness.setPercent(v * 100);
        else
            Audio.setMicVolume(v);
    }

    // How far one item has come out, staggered by its place.
    function out(i, count, base) {
        const t = (root.reveal - base - i * (0.35 / count)) / (1 - base - 0.35);
        return Math.max(0, Math.min(1.08, t));
    }

    component Bubble: Rectangle {
        id: bubble

        property var info: ({})
        property real radiusOut: 0
        property real angle: 0
        property real p: 1
        property int diameter: 44
        signal clicked
        signal more

        readonly property real a: (angle - (1 - Math.min(1, p)) * 80) * Math.PI / 180
        x: root.center + Math.cos(a) * radiusOut * p - width / 2
        y: root.center + Math.sin(a) * radiusOut * p - height / 2
        width: diameter
        height: diameter
        radius: diameter / 2
        opacity: Math.min(1, p * 1.6)
        scale: (0.4 + 0.6 * Math.min(1, p)) * (bubbleArea.pressed ? 0.9 : bubbleArea.containsMouse ? 1.1 : 1)
        color: info.on ? (info.mode ? Qt.alpha(Theme.accent, 0.85) : Theme.accent) : Qt.alpha(Theme.text, bubbleArea.containsMouse ? 0.18 : 0.09)
        border.width: info.mode ? 1 : 0
        border.color: Qt.alpha(Theme.accent, 0.7)

        Behavior on scale {
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutBack
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: 180
            }
        }

        Icon {
            anchors.centerIn: parent
            name: bubble.info.icon || ""
            size: bubble.diameter * 0.42
            color: bubble.info.on ? Theme.accentText : Theme.text
        }
        MouseArea {
            id: bubbleArea

            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: root.hoverTitle = containsMouse ? bubble.info.title : root.hoverTitle === bubble.info.title ? "" : root.hoverTitle
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton)
                    bubble.more();
                else
                    bubble.clicked();
            }
        }
    }

    // The faint orbits the bubbles ride on.
    Repeater {
        model: [118, 176]

        delegate: Rectangle {
            required property int modelData

            x: root.center - modelData * root.reveal
            y: root.center - modelData * root.reveal
            width: modelData * 2 * root.reveal
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: Qt.alpha(Theme.text, 0.08)
        }
    }

    // ------------------------------------------------ the dial
    Item {
        id: dial

        x: root.center - 74
        y: root.center - 74
        width: 148
        height: 148
        scale: Math.min(1, root.reveal * 1.4)

        Rectangle {
            anchors.fill: parent
            anchors.margins: 8
            radius: width / 2
            color: Qt.alpha(Theme.glassBase, 0.5)
            border.width: 1
            border.color: Qt.alpha(Theme.text, 0.1)
        }
        Ring {
            anchors.fill: parent
            value: root.dialValue
            thickness: 9
            color: Theme.accent
        }
        Column {
            anchors.centerIn: parent
            width: 104
            spacing: 2

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.hoverTitle === ""
                text: Math.round(root.dialValue * 100) + "%"
                font.family: Theme.display
                size: 26
                font.weight: Font.DemiBold
            }
            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                visible: root.hoverTitle !== ""
                text: root.hoverTitle
                size: 12
                font.weight: Font.Medium
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
            }
            // Which level the dial sets.
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.hoverTitle === ""
                spacing: 4

                Repeater {
                    model: [
                        {
                            icon: Audio.muted ? "mute" : "volume",
                            ok: Audio.available
                        },
                        {
                            icon: "sun",
                            ok: Brightness.available
                        },
                        {
                            icon: Audio.micMuted ? "micOff" : "mic",
                            ok: Audio.micAvailable
                        }
                    ]

                    delegate: Rectangle {
                        id: pick

                        required property var modelData
                        required property int index

                        visible: modelData.ok
                        width: 24
                        height: 24
                        radius: 12
                        color: root.dialing === index ? Qt.alpha(Theme.accent, 0.3) : Qt.alpha(Theme.text, pickArea.containsMouse ? 0.12 : 0)

                        Icon {
                            anchors.centerIn: parent
                            name: pick.modelData.icon
                            size: 13
                        }
                        MouseArea {
                            id: pickArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            // A second click on the chosen level mutes it.
                            onClicked: {
                                if (root.dialing === pick.index && pick.index === 0)
                                    Audio.toggleMute();
                                else if (root.dialing === pick.index && pick.index === 2)
                                    Audio.toggleMicMute();
                                root.dialing = pick.index;
                            }
                        }
                    }
                }
            }
        }
        // Dragging around the ring sets the level, from the top clockwise.
        MouseArea {
            anchors.fill: parent
            z: -1
            cursorShape: Qt.PointingHandCursor
            function fromPoint(mx, my) {
                let a = Math.atan2(mx - width / 2, -(my - height / 2));
                if (a < 0)
                    a += Math.PI * 2;
                root.setDial(a / (Math.PI * 2));
            }
            onPressed: mouse => fromPoint(mouse.x, mouse.y)
            onPositionChanged: mouse => {
                if (pressed)
                    fromPoint(mouse.x, mouse.y);
            }
            onWheel: wheel => root.setDial(root.dialValue + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
        }
    }

    // ------------------------------------------------ inner orbit: network and switches
    Repeater {
        model: root.inner

        delegate: Bubble {
            required property var modelData
            required property int index

            info: modelData
            diameter: 46
            radiusOut: 118
            angle: -90 + index * 360 / root.inner.length
            p: root.out(index, root.inner.length, 0.05)
            onClicked: cs.flip(modelData.id)
            onMore: {
                if (modelData.id === "wifi")
                    cs.openWifi();
                else if (modelData.id === "bluetooth")
                    cs.openBluetooth();
            }
        }
    }

    // ------------------------------------------------ outer orbit: tools and power modes
    Repeater {
        model: root.outer

        delegate: Bubble {
            required property var modelData
            required property int index

            info: Object.assign({}, modelData, {
                on: modelData.mode ? modelData.on : modelData.id === "record" && Ui.recordBusy
            })
            diameter: 36
            radiusOut: 176
            angle: -90 + 15 + index * 360 / root.outer.length
            p: root.out(index, root.outer.length, 0.2)
            opacity: Math.min(1, p * 1.6) * (modelData.mode && !cs.usable(Number(modelData.id.slice(4))) ? 0.4 : 1)
            onClicked: modelData.mode ? cs.setMode(Number(modelData.id.slice(4))) : cs.use(modelData.id)
        }
    }
}
