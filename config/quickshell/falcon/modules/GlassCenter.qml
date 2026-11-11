import QtQuick
import Quickshell
import qs.components
import qs.services

// The middle island of the glass bar: processor, memory and temperature rings (they open the
// system menu), the clock (the calendar), the timer and the recording time, and the music (the
// play button, and the title, which opens the player). It never grows: notifications have their
// own card at the top right, and volume and brightness levels a pill under this island.
GlassIsland {
    id: root

    readonly property bool showSeconds: Settings.get("panel.clockSeconds", false)
    readonly property bool showDate: Settings.get("panel.clockDate", false)
    readonly property bool clock24: Settings.get("panel.clock24", true)
    readonly property bool showResources: Settings.get("panel.resources", true)
    readonly property bool showMedia: Settings.get("panel.media", true) && !!Media.player

    // The parts the menus drop from.
    readonly property var ringsItem: ringsButton
    readonly property var clockItem: clockButton
    readonly property var mediaItem: mediaBox

    spacing: 10

    Behavior on implicitWidth {
        NumberAnimation {
            duration: 300
            easing.type: Easing.OutCubic
        }
    }

    SystemClock {
        id: clock

        precision: root.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    BarButton {
        id: ringsButton

        objectName: "rings"
        anchors.verticalCenter: parent.verticalCenter
        visible: root.showResources
        padding: 3
        lit: Ui.popup === "system"
        onClicked: Ui.togglePopup("system")

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            RingMeter {
                icon: "chip"
                value: Sys.cpu / 100
            }
            RingMeter {
                icon: "memory"
                value: Sys.ram / 100
            }
            RingMeter {
                icon: "thermo"
                value: Sys.temperature / 100
            }
        }
    }

    BarSeparator {
        visible: root.showResources
    }

    // Recording: a red dot and the time, or the seconds before a delayed one starts. A click stops it.
    Row {
        anchors.verticalCenter: parent.verticalCenter
        visible: Ui.recordBusy
        spacing: 7

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 8
            height: 8
            radius: 4
            color: Theme.error

            SequentialAnimation on opacity {
                running: Ui.recordBusy
                loops: Animation.Infinite
                onRunningChanged: {
                    if (!running)
                        parent.opacity = 1;
                }
                NumberAnimation {
                    to: 0.3
                    duration: 600
                }
                NumberAnimation {
                    to: 1
                    duration: 600
                }
            }
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: Ui.recording ? Ui.pad(Math.floor(Ui.recordSeconds / 60)) + ":" + Ui.pad(Ui.recordSeconds % 60) : String(Ui.recordCountdown)
            color: Theme.error
            size: 14
            font.weight: Font.Medium

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: Ui.toggleRecording()
            }
        }
    }

    // The timer. A click pauses it, a right click stops it.
    BarButton {
        anchors.verticalCenter: parent.verticalCenter
        visible: Countdown.active
        padding: 8
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                Countdown.stop();
            else
                Countdown.togglePause();
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5
            opacity: Countdown.paused ? 0.5 : 1

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: Countdown.icon
                color: Countdown.left <= 10 && !Countdown.paused ? Theme.error : Theme.accent
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: Countdown.text
                size: 13
                font.weight: Font.Medium
            }
        }
    }

    // The clock, with the date beside it. Opens the calendar.
    BarButton {
        id: clockButton

        objectName: "clock"
        anchors.verticalCenter: parent.verticalCenter
        padding: 8
        lit: Ui.popup === "calendar"
        onClicked: Ui.togglePopup("calendar")

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    const hours = root.clock24 ? clock.hours : clock.hours % 12 || 12;
                    return Ui.pad(hours) + ":" + Ui.pad(clock.minutes) + (root.showSeconds ? ":" + Ui.pad(clock.seconds) : "") + (root.clock24 ? "" : clock.hours < 12 ? " AM" : " PM");
                }
                font.family: Theme.display
                size: 15
                font.weight: Font.DemiBold
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.showDate
                text: Tr.capitalized(clock.date.toLocaleDateString(Tr.locale, "ddd, d MMM"))
                size: 12
                color: Theme.muted
            }
        }
    }

    BarSeparator {
        visible: root.showMedia
    }

    // The music: play or pause, the title and how far it has played. The title opens the player.
    Row {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.showMedia
        spacing: 9

        Rectangle {
            objectName: "play"
            anchors.verticalCenter: parent.verticalCenter
            width: 24
            height: 24
            radius: 12
            color: playArea.containsMouse ? Qt.lighter(Theme.accent, 1.12) : Theme.accent

            Icon {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: Media.player && Media.player.isPlaying ? 0 : 1
                name: Media.player && Media.player.isPlaying ? "pause" : "play"
                filled: true
                size: 12
                color: Theme.accentText
            }
            MouseArea {
                id: playArea

                anchors.fill: parent
                anchors.margins: -3
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (Media.player && Media.player.canTogglePlaying)
                        Media.player.togglePlaying();
                }
            }
        }
        Item {
            id: mediaBox

            objectName: "media"
            anchors.verticalCenter: parent.verticalCenter
            width: 140
            height: 30

            Label {
                y: 4
                width: parent.width
                text: Media.title + (Media.player && Media.player.trackArtist ? " — " + Media.player.trackArtist : "")
                size: 12
                font.weight: Font.Medium
                color: mediaArea.containsMouse || Ui.popup === "player" ? Theme.accent : Theme.text
            }
            // No animation on the width: an animated bar repainted the whole layer every frame.
            Rectangle {
                y: 22
                width: parent.width
                height: 3
                radius: 1.5
                color: Qt.alpha(Theme.text, 0.18)

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, Media.progress))
                    height: parent.height
                    radius: 1.5
                    color: Theme.accent
                }
            }
            MouseArea {
                id: mediaArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Ui.togglePopup("player")
            }
        }
    }
}
