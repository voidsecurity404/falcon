import QtQuick
import Quickshell
import qs.components
import qs.services

// Screen recording choices in the control center: sound, area, delay and format. They are kept in
// `record` of Saved, where falcon-record reads them, so Mod+Shift+R uses them too.
Column {
    id: root

    signal releaseFocus

    readonly property string sound: Ui.recordOption("audio", "none")
    readonly property string area: Ui.recordOption("area", "region")
    readonly property int delay: Ui.recordOption("delay", 0)
    readonly property string format: Ui.recordOption("format", "mp4")
    readonly property bool gif: format === "gif"

    readonly property var sounds: [
        {
            value: "none",
            icon: "mute",
            title: Tr.t("Video only"),
            sub: Tr.t("No sound")
        },
        {
            value: "system",
            icon: "volume",
            title: Tr.t("Video and sound"),
            sub: Tr.t("What the computer plays")
        },
        {
            value: "both",
            icon: "mic",
            title: Tr.t("Video, sound and microphone"),
            sub: Tr.t("The computer and your voice together")
        }
    ]

    width: parent.width
    spacing: 10

    // A row of choices with a sliding mark, like the power mode.
    component Choice: Item {
        id: choice

        property string label: ""
        property var options: []
        property var names: []
        property var current
        property bool active: true

        signal picked(var value)

        readonly property int index: options.indexOf(current)

        width: parent.width
        height: 34
        opacity: active ? 1 : 0.4

        Label {
            id: caption

            anchors.verticalCenter: parent.verticalCenter
            width: 112
            text: choice.label
            color: Theme.muted
            size: 12
        }
        Rectangle {
            id: track

            anchors.left: caption.right
            anchors.right: parent.right
            height: parent.height
            radius: 17
            color: Qt.alpha(Theme.text, 0.05)

            Rectangle {
                readonly property real slot: (track.width - 6) / choice.options.length

                x: 3 + Math.max(0, choice.index) * slot
                y: 3
                width: slot
                height: track.height - 6
                radius: height / 2
                color: Theme.accent
                visible: choice.index >= 0

                Behavior on x {
                    NumberAnimation {
                        duration: 340
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.3, 1.4, 0.4, 1, 1, 1]
                    }
                }
            }
            Row {
                x: 3

                Repeater {
                    model: choice.options

                    delegate: Item {
                        id: option

                        required property var modelData
                        required property int index

                        width: (track.width - 6) / choice.options.length
                        height: track.height

                        Label {
                            anchors.centerIn: parent
                            text: choice.names[option.index]
                            color: choice.index === option.index ? Theme.accentText : Theme.text
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
                            cursorShape: choice.active ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (choice.active)
                                    choice.picked(option.modelData);
                            }
                        }
                    }
                }
            }
        }
    }

    PageHeader {
        title: Tr.t("Screen recording")
        hasSwitch: false
        onBack: Ui.controlPage = ""
    }

    // What is heard in the video
    Column {
        width: parent.width
        spacing: 4
        opacity: root.gif ? 0.4 : 1

        Repeater {
            model: root.sounds

            delegate: Rectangle {
                id: soundRow

                required property var modelData

                readonly property bool current: !root.gif && root.sound === modelData.value || root.gif && modelData.value === "none"

                width: parent.width
                height: 50
                radius: 12
                color: current ? Qt.alpha(Theme.accent, 0.16) : Qt.alpha(Theme.text, soundArea.containsMouse && !root.gif ? 0.08 : 0.03)
                border.width: current ? 1 : 0
                border.color: Qt.alpha(Theme.accent, 0.5)

                Behavior on color {
                    ColorAnimation {
                        duration: 160
                    }
                }

                Rectangle {
                    id: badge

                    anchors.left: parent.left
                    anchors.leftMargin: 9
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    height: 32
                    radius: soundRow.current ? 16 : 10
                    color: soundRow.current ? Theme.accent : Qt.alpha(Theme.text, 0.07)

                    Behavior on radius {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutCubic
                        }
                    }

                    Icon {
                        anchors.centerIn: parent
                        name: soundRow.modelData.icon
                        size: 16
                        color: soundRow.current ? Theme.accentText : Theme.text
                    }
                }
                Column {
                    anchors.left: badge.right
                    anchors.leftMargin: 11
                    anchors.right: tick.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Label {
                        width: parent.width
                        text: soundRow.modelData.title
                        size: 13
                        font.weight: Font.Medium
                        color: soundRow.current ? Theme.accent : Theme.text
                    }
                    Label {
                        width: parent.width
                        text: soundRow.modelData.sub
                        size: 11
                        color: Theme.muted
                    }
                }
                Icon {
                    id: tick

                    anchors.right: parent.right
                    anchors.rightMargin: 13
                    anchors.verticalCenter: parent.verticalCenter
                    name: "check"
                    size: 15
                    color: Theme.accent
                    opacity: soundRow.current ? 1 : 0
                    scale: soundRow.current ? 1 : 0.5

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 160
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: 260
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: [0.3, 1.6, 0.4, 1, 1, 1]
                        }
                    }
                }
                MouseArea {
                    id: soundArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: root.gif ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: {
                        if (!root.gif)
                            Ui.setRecordOption("audio", soundRow.modelData.value);
                    }
                }
            }
        }
    }

    Item {
        width: 1
        height: 2
    }

    Choice {
        label: Tr.t("What to record")
        options: ["region", "screen"]
        names: [Tr.t("Area or window"), Tr.t("Whole screen")]
        current: root.area
        onPicked: value => Ui.setRecordOption("area", value)
    }
    Choice {
        label: Tr.t("Start after")
        options: [0, 3, 5, 10]
        names: [Tr.t("At once"), Tr.t("3 s"), Tr.t("5 s"), Tr.t("10 s")]
        current: root.delay
        onPicked: value => Ui.setRecordOption("delay", value)
    }
    Choice {
        label: Tr.t("Format")
        options: ["mp4", "gif"]
        names: ["MP4", Tr.t("GIF, no sound")]
        current: root.format
        onPicked: value => Ui.setRecordOption("format", value)
    }

    Item {
        width: 1
        height: 2
    }

    // Start, and the folder with the videos
    Row {
        width: parent.width
        spacing: 8

        Rectangle {
            id: start

            width: parent.width - folder.width - parent.spacing
            height: 44
            radius: startArea.containsMouse ? 22 : 14
            color: Ui.recordBusy ? Theme.error : Theme.accent
            scale: startArea.pressed ? 0.96 : 1

            Behavior on radius {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: 160
                }
            }

            Row {
                anchors.centerIn: parent
                spacing: 8

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Ui.recordBusy ? "close" : "record"
                    size: 16
                    color: Ui.recordBusy ? "white" : Theme.accentText
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Ui.recording ? Tr.t("Stop recording") + "  " + Ui.pad(Math.floor(Ui.recordSeconds / 60)) + ":" + Ui.pad(Ui.recordSeconds % 60) : Ui.recordCountdown > 0 ? Tr.t("Cancel") + "  " + Ui.recordCountdown : root.area === "screen" ? Tr.t("Start recording") : Tr.t("Choose an area")
                    color: Ui.recordBusy ? "white" : Theme.accentText
                    size: 13
                    font.weight: Font.Medium
                    font.features: {
                        "tnum": 1
                    }
                }
            }
            MouseArea {
                id: startArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Ui.toggleRecording()
            }
        }
        Rectangle {
            id: folder

            width: 44
            height: 44
            radius: folderArea.containsMouse ? 22 : 14
            color: Qt.alpha(Theme.text, folderArea.containsMouse ? 0.13 : 0.06)

            Behavior on radius {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }

            Icon {
                anchors.centerIn: parent
                name: "save"
                size: 17
            }
            MouseArea {
                id: folderArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Ui.popup = "";
                    Quickshell.execDetached(["sh", "-c", "d=\"$(xdg-user-dir VIDEOS 2>/dev/null || echo \"$HOME/Videos\")\"; mkdir -p \"$d\" && xdg-open \"$d\""]);
                }
            }
        }
    }

    Label {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: Tr.t("Stop with") + " " + Settings.get("binds.record", "Mod+Shift+R") + " " + Tr.t("or a click on the time")
        color: Theme.muted
        size: 11
        wrapMode: Text.WordWrap
    }
}
