import QtQuick
import Quickshell
import qs.components
import qs.services

// The studio layout's control center, set like a magazine page: separate cards that slide in
// from the right edge one after another. Big numbers for the levels with a thin line under each,
// the switches as words underlined when on, tools as a plain grid, the power mode as three words
// with a sliding underline.
Item {
    id: root

    property bool shown: false

    implicitHeight: column.implicitHeight

    ControlState {
        id: cs
    }

    component Card: Item {
        id: card

        property int order: 0
        property string title: ""
        default property alias content: inner.data

        width: root.width
        height: frame.height

        Rectangle {
            id: frame

            x: root.shown ? 0 : 60
            opacity: root.shown ? 1 : 0
            width: parent.width
            height: inner.childrenRect.height + (card.title === "" ? 28 : 52)
            radius: 20
            color: Qt.alpha(Theme.text, 0.06)
            border.width: 1
            border.color: Qt.alpha(Theme.text, 0.06)

            Behavior on x {
                SequentialAnimation {
                    PauseAnimation {
                        duration: root.shown ? 80 + card.order * 55 : 0
                    }
                    NumberAnimation {
                        duration: root.shown ? 520 : 120
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.16, 1, 0.3, 1, 1, 1]
                    }
                }
            }
            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation {
                        duration: root.shown ? 80 + card.order * 55 : 0
                    }
                    NumberAnimation {
                        duration: root.shown ? 300 : 100
                    }
                }
            }

            Label {
                visible: card.title !== ""
                x: 18
                y: 14
                text: card.title.toUpperCase()
                size: 10
                font.weight: Font.DemiBold
                font.letterSpacing: 1.6
                color: Theme.muted
            }
            Item {
                id: inner

                x: 18
                y: card.title === "" ? 14 : 38
                width: parent.width - 36
            }
        }
    }

    // A level as a big number with a thin line under it.
    component BigLevel: Item {
        id: level

        property string icon: ""
        property string title: ""
        property real value: 0
        property bool muted: false
        signal moved(real value)
        signal iconClicked

        height: 84

        Row {
            spacing: 6

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: level.icon
                size: 13
                color: Theme.muted

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: level.iconClicked()
                }
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: level.title
                size: 11
                color: Theme.muted
            }
        }
        Label {
            y: 18
            text: Math.round(level.value * 100)
            font.family: Theme.display
            size: 38
            font.weight: Font.DemiBold
            color: level.muted ? Theme.muted : Theme.text
        }
        Item {
            id: lineArea

            y: 70
            width: parent.width
            height: 14

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 2
                color: Qt.alpha(Theme.text, 0.15)
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * Math.max(0, Math.min(1, level.value))
                height: 2
                color: level.muted ? Theme.muted : Theme.accent
            }
            Rectangle {
                x: parent.width * Math.max(0, Math.min(1, level.value)) - 5
                anchors.verticalCenter: parent.verticalCenter
                width: 10
                height: 10
                radius: 5
                color: level.muted ? Theme.muted : Theme.accent
            }
            MouseArea {
                anchors.fill: parent
                anchors.topMargin: -30
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse => level.moved(Math.max(0, Math.min(1, mouse.x / width)))
                onPositionChanged: mouse => {
                    if (pressed)
                        level.moved(Math.max(0, Math.min(1, mouse.x / width)));
                }
                onWheel: wheel => level.moved(Math.max(0, Math.min(1, level.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))))
            }
        }
    }

    // A wide connection tile: big icon, name and state, an arrow to the list.
    component Link: Rectangle {
        id: link

        property string icon: ""
        property string title: ""
        property string sub: ""
        property bool on: false
        signal toggled
        signal open

        width: parent ? parent.width : 0
        height: 58
        radius: 14
        color: on ? Qt.alpha(Theme.accent, 0.18) : Qt.alpha(Theme.text, 0.05)

        Rectangle {
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 42
            height: 42
            radius: 12
            color: link.on ? Theme.accent : Qt.alpha(Theme.text, 0.1)

            Icon {
                anchors.centerIn: parent
                name: link.icon
                size: 19
                color: link.on ? Theme.accentText : Theme.text
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: link.toggled()
            }
        }
        Column {
            x: 62
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 62 - 50

            Label {
                text: link.title
                size: 14
                font.weight: Font.DemiBold
            }
            Label {
                width: parent.width
                text: link.sub
                size: 12
                color: Theme.muted
                elide: Text.ElideRight
            }
        }
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32
            radius: 16
            color: Qt.alpha(Theme.text, openArea.containsMouse ? 0.14 : 0.06)

            Icon {
                anchors.centerIn: parent
                name: "forward"
                size: 14
            }
            MouseArea {
                id: openArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: link.open()
            }
        }
    }

    Column {
        id: column

        width: root.width
        spacing: 10

        Card {
            order: 0
            title: Tr.t("Connections")

            Column {
                width: parent.width
                spacing: 8

                Link {
                    icon: cs.wired ? "ethernet" : cs.wifiOn ? "wifi" : "wifiOff"
                    title: Tr.t("Wi-Fi")
                    sub: cs.wifiText
                    on: cs.wifiOn
                    onToggled: cs.toggleWifi()
                    onOpen: cs.openWifi()
                }
                Link {
                    icon: "bluetooth"
                    title: Tr.t("Bluetooth")
                    sub: cs.btText
                    on: cs.btOn
                    onToggled: cs.toggleBluetooth()
                    onOpen: cs.openBluetooth()
                }
            }
        }

        Card {
            order: 1
            title: Tr.t("Levels")

            Row {
                width: parent.width
                spacing: 18

                BigLevel {
                    width: (parent.width - 36) / 3
                    visible: Audio.available
                    icon: Audio.muted ? "mute" : "volume"
                    title: Tr.t("Sound")
                    value: Audio.volume
                    muted: Audio.muted
                    onMoved: v => Audio.setVolume(v)
                    onIconClicked: Audio.toggleMute()
                }
                BigLevel {
                    width: (parent.width - 36) / 3
                    visible: Brightness.available
                    icon: "sun"
                    title: Tr.t("Brightness")
                    value: Brightness.percent / 100
                    onMoved: v => Brightness.setPercent(v * 100)
                }
                BigLevel {
                    width: (parent.width - 36) / 3
                    visible: Audio.micAvailable
                    icon: Audio.micMuted ? "micOff" : "mic"
                    title: Tr.t("Microphone")
                    value: Audio.micVolume
                    muted: Audio.micMuted
                    onMoved: v => Audio.setMicVolume(v)
                    onIconClicked: Audio.toggleMicMute()
                }
            }
        }

        // The switches as words, underlined while on.
        Card {
            order: 2
            title: Tr.t("Modes")

            Flow {
                width: parent.width
                spacing: 18

                Repeater {
                    model: cs.switches

                    delegate: Item {
                        id: word

                        required property var modelData

                        width: wordRow.implicitWidth
                        height: 34

                        Row {
                            id: wordRow

                            spacing: 6

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: word.modelData.icon
                                size: 15
                                color: word.modelData.on ? Theme.accent : Theme.muted
                            }
                            Label {
                                anchors.verticalCenter: parent.verticalCenter
                                text: word.modelData.title
                                size: 15
                                font.weight: word.modelData.on ? Font.DemiBold : Font.Normal
                                color: word.modelData.on ? Theme.text : wordArea.containsMouse ? Theme.text : Theme.muted
                            }
                        }
                        Rectangle {
                            y: 28
                            width: word.modelData.on ? parent.width : 0
                            height: 3
                            radius: 1.5
                            color: Theme.accent

                            Behavior on width {
                                NumberAnimation {
                                    duration: 260
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                        MouseArea {
                            id: wordArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: cs.flip(word.modelData.id)
                        }
                    }
                }
            }
        }

        Card {
            order: 3
            title: Tr.t("Tools")

            Grid {
                width: parent.width
                columns: 3
                rowSpacing: 2
                columnSpacing: 4

                Repeater {
                    model: cs.tools

                    delegate: Rectangle {
                        id: tool

                        required property var modelData
                        readonly property bool lit: modelData.id === "record" && Ui.recordBusy

                        width: (parent.width - 8) / 3
                        height: 36
                        radius: 10
                        color: lit ? Qt.alpha(Theme.error, 0.25) : Qt.alpha(Theme.text, toolArea.containsMouse ? 0.08 : 0)

                        Row {
                            x: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: tool.modelData.icon
                                size: 16
                                color: Theme.accent
                            }
                            Label {
                                anchors.verticalCenter: parent.verticalCenter
                                text: tool.modelData.title
                                size: 12
                            }
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

        // The power mode as three words with a sliding underline.
        Card {
            order: 4

            Item {
                id: modes

                width: parent.width
                height: 34

                Rectangle {
                    x: Math.max(0, cs.mode) * modes.width / 3 + 14
                    y: 30
                    width: modes.width / 3 - 28
                    height: 3
                    radius: 1.5
                    color: Theme.accent
                    visible: cs.mode >= 0

                    Behavior on x {
                        NumberAnimation {
                            duration: 380
                            easing.type: Easing.OutCubic
                        }
                    }
                }
                Row {
                    Repeater {
                        model: cs.modes

                        delegate: Item {
                            id: mode

                            required property var modelData
                            required property int index

                            width: modes.width / 3
                            height: 30
                            opacity: cs.usable(index) ? 1 : 0.4

                            Label {
                                anchors.centerIn: parent
                                text: mode.modelData.label
                                size: 14
                                font.weight: cs.mode === mode.index ? Font.DemiBold : Font.Normal
                                color: cs.mode === mode.index ? Theme.text : Theme.muted
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
    }
}
