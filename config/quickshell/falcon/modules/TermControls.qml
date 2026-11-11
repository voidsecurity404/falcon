import QtQuick
import Quickshell
import qs.components
import qs.services

// The terminal layout's control center: a text screen in a monospace font. Switches are [x]
// boxes, levels are bars of block characters, choices are (•) radios and the tools are [words].
// The frame unrolls a line at a time and each line types itself in after it.
Item {
    id: root

    property bool shown: false
    property real reveal: 1
    readonly property int line: 22
    readonly property int keyWidth: 62
    readonly property int bars: 22

    implicitHeight: header.height + body.implicitHeight + 10

    ControlState {
        id: cs
    }
    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    // A line of the screen, typed in after the line above. The pointer lights it like a cursor bar.
    component TermLine: Rectangle {
        id: termLine

        property int order: 0
        property string key: ""
        property bool hot: false
        default property alias content: inner.data

        width: root.width
        height: root.line
        color: hot ? Qt.alpha(Theme.accent, 0.16) : "transparent"
        opacity: root.reveal * 14 > order ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 60
            }
        }

        Text {
            x: 12
            height: root.line
            verticalAlignment: Text.AlignVCenter
            text: termLine.key
            font.family: Theme.mono
            font.pixelSize: 13
            font.bold: true
            color: Theme.accent
        }
        Item {
            id: inner

            x: 12 + root.keyWidth
            width: parent.width - x - 12
            height: parent.height
        }
    }

    component Word: Text {
        id: word

        property bool button: false
        property bool lit: false
        signal clicked

        height: root.line
        verticalAlignment: Text.AlignVCenter
        font.family: Theme.mono
        font.pixelSize: 13
        color: lit ? Theme.accent : wordArea.containsMouse && button ? Theme.text : Qt.alpha(Theme.text, button ? 0.85 : 0.6)
        font.underline: button && wordArea.containsMouse

        MouseArea {
            id: wordArea

            anchors.fill: parent
            anchors.margins: -3
            enabled: word.button
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: word.clicked()
        }
    }

    // A level as a bar of blocks, set by a click or a drag on it.
    component BlockBar: Row {
        id: bar

        property real value: 0
        property bool muted: false
        signal moved(real value)
        signal mute

        spacing: 10

        Text {
            id: blocks

            anchors.verticalCenter: parent.verticalCenter
            readonly property int filled: Math.round(Math.max(0, Math.min(1, bar.value)) * root.bars)
            text: "█".repeat(filled) + "░".repeat(root.bars - filled)
            font.family: Theme.mono
            font.pixelSize: 13
            color: bar.muted ? Theme.muted : Theme.accent

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse => bar.moved(Math.max(0, Math.min(1, mouse.x / width)))
                onPositionChanged: mouse => {
                    if (pressed)
                        bar.moved(Math.max(0, Math.min(1, mouse.x / width)));
                }
            }
        }
        Word {
            text: String(Math.round(bar.value * 100)).padStart(3, " ") + "%"
        }
        Word {
            button: true
            lit: bar.muted
            text: bar.muted ? "[muted]" : "[mute]"
            onClicked: bar.mute()
        }
    }

    // The title line, in reverse like a terminal program's header.
    Rectangle {
        id: header

        width: root.width
        height: 26
        color: Theme.accent

        Text {
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            text: "falcon ▸ control"
            font.family: Theme.mono
            font.pixelSize: 13
            font.bold: true
            color: Theme.accentText
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: Ui.pad(clock.hours) + ":" + Ui.pad(clock.minutes) + "  esc ✕"
            font.family: Theme.mono
            font.pixelSize: 13
            color: Theme.accentText

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Ui.popup = ""
            }
        }
    }

    Column {
        id: body

        y: header.height + 6
        width: root.width

        TermLine {
            order: 1
            key: "net"

            Row {
                height: parent.height
                spacing: 10

                Word {
                    button: true
                    lit: cs.wifiOn
                    text: (cs.wifiOn ? "[x]" : "[ ]") + " wifi"
                    onClicked: cs.toggleWifi()
                }
                Word {
                    width: 200
                    elide: Text.ElideRight
                    text: cs.wifiText
                }
                Word {
                    button: true
                    text: "list ›"
                    onClicked: cs.openWifi()
                }
            }
        }
        TermLine {
            order: 2

            Row {
                height: parent.height
                spacing: 10

                Word {
                    button: true
                    lit: cs.btOn
                    text: (cs.btOn ? "[x]" : "[ ]") + " bt  "
                    onClicked: cs.toggleBluetooth()
                }
                Word {
                    width: 200
                    elide: Text.ElideRight
                    text: cs.btText
                }
                Word {
                    button: true
                    text: "list ›"
                    onClicked: cs.openBluetooth()
                }
            }
        }
        TermLine {
            order: 3
            key: "mode"

            Flow {
                width: parent.width
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                Repeater {
                    model: cs.switches.slice(0, 4)

                    delegate: Word {
                        required property var modelData

                        button: true
                        lit: modelData.on
                        text: (modelData.on ? "[x] " : "[ ] ") + modelData.id
                        onClicked: cs.flip(modelData.id)
                    }
                }
            }
        }
        TermLine {
            order: 4
            visible: Power.chargeSupported

            Word {
                button: true
                lit: Power.limitOn && !Power.needsSetup
                text: (Power.limitOn && !Power.needsSetup ? "[x] " : "[ ] ") + "charge ≤ " + Power.limitValue + "%"
                onClicked: cs.toggleLimit()
            }
        }
        TermLine {
            order: 5
            key: "vol"
            visible: Audio.available

            BlockBar {
                anchors.verticalCenter: parent.verticalCenter
                value: Audio.volume
                muted: Audio.muted
                onMoved: v => Audio.setVolume(v)
                onMute: Audio.toggleMute()
            }
        }
        TermLine {
            order: 6
            key: "mic"
            visible: Audio.micAvailable

            BlockBar {
                anchors.verticalCenter: parent.verticalCenter
                value: Audio.micVolume
                muted: Audio.micMuted
                onMoved: v => Audio.setMicVolume(v)
                onMute: Audio.toggleMicMute()
            }
        }
        TermLine {
            order: 7
            key: "bri"
            visible: Brightness.available

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    readonly property int filled: Math.round(Brightness.percent / 100 * root.bars)
                    text: "█".repeat(filled) + "░".repeat(root.bars - filled)
                    font.family: Theme.mono
                    font.pixelSize: 13
                    color: Theme.accent

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onPressed: mouse => Brightness.setPercent(Math.max(0, Math.min(1, mouse.x / width)) * 100)
                        onPositionChanged: mouse => {
                            if (pressed)
                                Brightness.setPercent(Math.max(0, Math.min(1, mouse.x / width)) * 100);
                        }
                    }
                }
                Word {
                    text: String(Brightness.percent).padStart(3, " ") + "%"
                }
            }
        }
        TermLine {
            order: 8
            key: "power"

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                Repeater {
                    model: ["saver", "balanced", "perf"]

                    delegate: Word {
                        required property string modelData
                        required property int index

                        button: cs.usable(index)
                        lit: cs.mode === index
                        opacity: cs.usable(index) ? 1 : 0.4
                        text: (cs.mode === index ? "(•) " : "( ) ") + modelData
                        onClicked: cs.setMode(index)
                    }
                }
            }
        }
        TermLine {
            order: 9
            key: "tools"
            height: toolFlow.implicitHeight

            Flow {
                id: toolFlow

                width: parent.width
                spacing: 10

                Repeater {
                    model: cs.tools

                    delegate: Word {
                        required property var modelData

                        button: true
                        lit: modelData.id === "record" && Ui.recordBusy
                        text: "[" + ({
                                    copy: "shot",
                                    search: "lens",
                                    ocr: "ocr",
                                    translate: "trans",
                                    record: Ui.recordBusy ? "stop" : "rec",
                                    color: "pick",
                                    wallpaper: "wall",
                                    focus: "zen",
                                    pin: "pin"
                                })[modelData.id] + "]"
                        onClicked: cs.use(modelData.id)
                    }
                }
            }
        }
        // The prompt with a blinking block cursor.
        TermLine {
            order: 11

            Row {
                anchors.verticalCenter: parent.verticalCenter

                Word {
                    text: "$ "
                    color: Theme.accent
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8
                    height: 15
                    color: Theme.text

                    SequentialAnimation on opacity {
                        running: root.shown
                        loops: Animation.Infinite

                        NumberAnimation {
                            to: 0
                            duration: 1
                        }
                        PauseAnimation {
                            duration: 530
                        }
                        NumberAnimation {
                            to: 1
                            duration: 1
                        }
                        PauseAnimation {
                            duration: 530
                        }
                    }
                }
            }
        }
    }
}
