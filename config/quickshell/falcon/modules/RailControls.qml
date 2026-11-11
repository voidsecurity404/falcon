import QtQuick
import Quickshell
import qs.components
import qs.services

// The rail layout's control center: a settings list. Grouped rows with a tinted icon, a name,
// a line under it and a switch on the right; thick sliders; tools as outlined chips; the power
// mode as a segmented button. Rows slide in from the rail's side one after another.
Item {
    id: root

    property bool shown: false

    implicitHeight: column.implicitHeight

    ControlState {
        id: cs
    }

    // Each row comes in from the left, after the one above it.
    component Slide: Item {
        id: slide

        property int order: 0
        default property alias content: holder.data

        width: root.width
        implicitHeight: holder.childrenRect.height
        height: implicitHeight

        Item {
            id: holder

            width: parent.width
            height: parent.height
            x: -26
            opacity: 0
        }
        states: State {
            when: root.shown
            PropertyChanges {
                target: holder
                x: 0
                opacity: 1
            }
        }
        transitions: Transition {
            SequentialAnimation {
                PauseAnimation {
                    duration: root.shown ? 30 + slide.order * 28 : 0
                }
                ParallelAnimation {
                    NumberAnimation {
                        target: holder
                        property: "x"
                        duration: root.shown ? 380 : 100
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: holder
                        property: "opacity"
                        duration: root.shown ? 240 : 100
                    }
                }
            }
        }
    }

    component Heading: Label {
        leftPadding: 6
        topPadding: 6
        bottomPadding: 2
        size: 12
        font.weight: Font.DemiBold
        color: Theme.accent
    }

    // A switch like a phone's: a track with a knob that grows when on.
    component Toggle: Rectangle {
        id: toggle

        property bool on: false
        signal clicked

        width: 46
        height: 26
        radius: 13
        color: on ? Theme.accent : "transparent"
        border.width: on ? 0 : 2
        border.color: Qt.alpha(Theme.text, 0.45)

        Behavior on color {
            ColorAnimation {
                duration: 160
            }
        }

        Rectangle {
            property real d: toggle.on ? 18 : 12
            x: toggle.on ? toggle.width - d - 4 : 7
            anchors.verticalCenter: parent.verticalCenter
            width: d
            height: d
            radius: d / 2
            color: toggle.on ? Theme.accentText : Qt.alpha(Theme.text, 0.6)

            Behavior on x {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on d {
                NumberAnimation {
                    duration: 200
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            onClicked: toggle.clicked()
        }
    }

    component ListRow: Rectangle {
        id: row

        property string icon: ""
        property string title: ""
        property string sub: ""
        property bool on: false
        property bool opens: false
        property bool first: false
        property bool last: false
        signal toggled
        signal open

        width: root.width
        height: sub === "" ? 46 : 54
        topLeftRadius: first ? 18 : 4
        topRightRadius: first ? 18 : 4
        bottomLeftRadius: last ? 18 : 4
        bottomRightRadius: last ? 18 : 4
        color: Qt.alpha(Theme.text, rowArea.containsMouse ? 0.1 : 0.06)

        Rectangle {
            id: badge

            x: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32
            radius: 10
            color: row.on ? Qt.alpha(Theme.accent, 0.25) : Qt.alpha(Theme.text, 0.08)

            Icon {
                anchors.centerIn: parent
                name: row.icon
                size: 16
                color: row.on ? Theme.accent : Theme.text
            }
        }
        Column {
            x: 56
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 56 - 70

            Label {
                width: parent.width
                text: row.title
                size: 13
                font.weight: Font.Medium
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
            id: rowArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.opens ? row.open() : row.toggled()
        }
        // A thin divider before the switch on rows that open a list.
        Rectangle {
            visible: row.opens
            x: parent.width - 72
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 24
            color: Qt.alpha(Theme.text, 0.15)
        }
        Toggle {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            on: row.on
            onClicked: row.toggled()
        }
    }

    // A thick slider: a tall track split at the handle, a small dot at the end.
    component ThickSlider: Item {
        id: thick

        property string icon: ""
        property real value: 0
        property bool muted: false
        signal moved(real value)
        signal iconClicked

        width: root.width
        height: 40

        Rectangle {
            width: 36
            height: 36
            radius: 12
            anchors.verticalCenter: parent.verticalCenter
            color: Qt.alpha(Theme.text, iconArea.containsMouse ? 0.12 : 0.06)

            Icon {
                anchors.centerIn: parent
                name: thick.icon
                size: 17
                opacity: thick.muted ? 0.5 : 1
            }
            MouseArea {
                id: iconArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: thick.iconClicked()
            }
        }
        Item {
            id: track

            x: 46
            width: parent.width - 46 - 6
            height: parent.height
            readonly property real at: width * Math.max(0, Math.min(1, thick.value))

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, track.at - 6)
                height: 16
                topLeftRadius: 8
                bottomLeftRadius: 8
                topRightRadius: 3
                bottomRightRadius: 3
                color: thick.muted ? Theme.muted : Theme.accent
            }
            Rectangle {
                x: track.at - 2
                anchors.verticalCenter: parent.verticalCenter
                width: 4
                height: 32
                radius: 2
                color: thick.muted ? Theme.muted : Theme.accent
            }
            Rectangle {
                x: Math.min(track.width, track.at + 6)
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, track.width - track.at - 6)
                height: 16
                topRightRadius: 8
                bottomRightRadius: 8
                topLeftRadius: 3
                bottomLeftRadius: 3
                color: Qt.alpha(Theme.accent, 0.2)
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse => thick.moved(Math.max(0, Math.min(1, mouse.x / width)))
                onPositionChanged: mouse => {
                    if (pressed)
                        thick.moved(Math.max(0, Math.min(1, mouse.x / width)));
                }
            }
        }
    }

    Column {
        id: column

        width: root.width
        spacing: 2

        Slide {
            order: 0

            Item {
                width: root.width
                height: 34

                Label {
                    x: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: Tr.t("Quick settings")
                    size: 17
                    font.weight: Font.DemiBold
                }
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    height: 32
                    radius: 16
                    color: Qt.alpha(Theme.text, gearArea.containsMouse ? 0.12 : 0)

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

        Slide {
            order: 1

            Heading {
                text: Tr.t("Network")
            }
        }
        Slide {
            order: 2

            ListRow {
                first: true
                icon: cs.wired ? "ethernet" : cs.wifiOn ? "wifi" : "wifiOff"
                title: Tr.t("Wi-Fi")
                sub: cs.wifiText
                on: cs.wifiOn
                opens: true
                onToggled: cs.toggleWifi()
                onOpen: cs.openWifi()
            }
        }
        Slide {
            order: 3

            ListRow {
                last: true
                icon: "bluetooth"
                title: Tr.t("Bluetooth")
                sub: cs.btText
                on: cs.btOn
                opens: true
                onToggled: cs.toggleBluetooth()
                onOpen: cs.openBluetooth()
            }
        }

        Slide {
            order: 4

            Heading {
                text: Tr.t("Modes")
            }
        }
        Repeater {
            model: cs.switches

            delegate: Slide {
                id: switchSlide

                required property var modelData
                required property int index

                order: 5 + index

                ListRow {
                    first: switchSlide.index === 0
                    last: switchSlide.index === cs.switches.length - 1
                    icon: switchSlide.modelData.icon
                    title: switchSlide.modelData.title
                    on: switchSlide.modelData.on
                    onToggled: cs.flip(switchSlide.modelData.id)
                }
            }
        }

        Slide {
            order: 10

            Heading {
                text: Tr.t("Levels")
            }
        }
        Slide {
            order: 11

            Column {
                width: root.width
                spacing: 2

                ThickSlider {
                    visible: Audio.available
                    icon: Audio.muted ? "mute" : "volume"
                    muted: Audio.muted
                    value: Audio.volume
                    onMoved: v => Audio.setVolume(v)
                    onIconClicked: Audio.toggleMute()
                }
                ThickSlider {
                    visible: Audio.micAvailable
                    icon: Audio.micMuted ? "micOff" : "mic"
                    muted: Audio.micMuted
                    value: Audio.micVolume
                    onMoved: v => Audio.setMicVolume(v)
                    onIconClicked: Audio.toggleMicMute()
                }
                ThickSlider {
                    visible: Brightness.available
                    icon: "sun"
                    value: Brightness.percent / 100
                    onMoved: v => Brightness.setPercent(v * 100)
                }
            }
        }

        Slide {
            order: 12

            Heading {
                text: Tr.t("Tools")
            }
        }
        Slide {
            order: 13

            Flow {
                width: root.width
                spacing: 6

                Repeater {
                    model: cs.tools

                    delegate: Rectangle {
                        id: chip

                        required property var modelData
                        readonly property bool lit: modelData.id === "record" && Ui.recordBusy

                        width: chipRow.implicitWidth + 22
                        height: 32
                        radius: 9
                        color: lit ? Theme.accent : Qt.alpha(Theme.text, chipArea.containsMouse ? 0.08 : 0)
                        border.width: lit ? 0 : 1
                        border.color: Qt.alpha(Theme.text, 0.22)

                        Row {
                            id: chipRow

                            anchors.centerIn: parent
                            spacing: 6

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: chip.modelData.icon
                                size: 15
                                color: chip.lit ? Theme.accentText : Theme.accent
                            }
                            Label {
                                anchors.verticalCenter: parent.verticalCenter
                                text: chip.modelData.title
                                size: 12
                                color: chip.lit ? Theme.accentText : Theme.text
                            }
                        }
                        MouseArea {
                            id: chipArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: cs.use(chip.modelData.id)
                        }
                    }
                }
            }
        }

        Slide {
            order: 14

            Heading {
                text: Tr.t("Power mode")
            }
        }
        // A segmented button with a check on the chosen part.
        Slide {
            order: 15

            Row {
                width: root.width

                Repeater {
                    model: cs.modes

                    delegate: Rectangle {
                        id: seg

                        required property var modelData
                        required property int index
                        readonly property bool current: cs.mode === index

                        width: root.width / 3
                        height: 38
                        topLeftRadius: index === 0 ? 19 : 0
                        bottomLeftRadius: index === 0 ? 19 : 0
                        topRightRadius: index === 2 ? 19 : 0
                        bottomRightRadius: index === 2 ? 19 : 0
                        color: current ? Qt.alpha(Theme.accent, 0.28) : Qt.alpha(Theme.text, segArea.containsMouse ? 0.06 : 0)
                        border.width: 1
                        border.color: Qt.alpha(Theme.text, 0.25)
                        opacity: cs.usable(index) ? 1 : 0.4

                        Row {
                            anchors.centerIn: parent
                            spacing: 5

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: seg.current
                                name: "check"
                                size: 14
                            }
                            Label {
                                anchors.verticalCenter: parent.verticalCenter
                                text: seg.modelData.label
                                size: 12
                                font.weight: Font.Medium
                            }
                        }
                        MouseArea {
                            id: segArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: cs.setMode(seg.index)
                        }
                    }
                }
            }
        }
    }
}
