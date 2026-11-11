import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.services

// Tepadagi orol: soat, xabarlar, ovoz, yozib olish va dashboard shu bitta joyda ochiladi.
Item {
    id: root

    property bool showDashboard: false
    signal releaseFocus

    // How far the island has left the screen edge, for focus mode. 0 is in place.
    property real slide: 0
    // The last message stays here while the island closes, so its text and icon leave with it.
    property var shownToast: null
    readonly property var currentToast: Toasts.current
    onCurrentToastChanged: {
        if (currentToast)
            shownToast = currentToast;
    }
    property alias body: body
    signal scrolled(real x, int step)

    readonly property string mode: showDashboard ? "dashboard" : Toasts.current ? "toast" : "idle"
    readonly property bool showSeconds: Settings.get("panel.clockSeconds", false)
    readonly property bool showDate: Settings.get("panel.clockDate", false)
    readonly property bool clock24: Settings.get("panel.clock24", true)
    readonly property bool showResources: Settings.get("panel.resources", true)
    readonly property bool showMedia: Settings.get("panel.media", true) && !!Media.player
    readonly property int targetWidth: mode === "dashboard" ? 1160 : mode === "toast" ? 440 : idleRow.implicitWidth + 26
    readonly property int cornerRadius: mode === "dashboard" ? 32 : mode === "toast" ? 24 : 15
    readonly property int targetHeight: mode === "dashboard" ? 580 : mode === "toast" ? 68 : 42

    width: body.width
    height: body.height

    Rectangle {
        id: body

        y: -root.slide * (body.height + 28)

        width: root.targetWidth
        height: root.targetHeight
        border.width: 1
        border.color: root.mode === "dashboard" ? "transparent" : Theme.panelEdge
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Theme.glassTop
            }
            GradientStop {
                position: 1
                color: Theme.panel
            }
        }
        radius: animatedRadius
        clip: true

        property real animatedRadius: root.cornerRadius

        Behavior on animatedRadius {
            NumberAnimation {
                duration: 420
                easing.type: Easing.OutCubic
            }
        }

        // Ochilishda avval kengayadi, keyin yumshoq sakrab pastga tushadi. Yopilish tez va sakrashsiz.
        Behavior on width {
            NumberAnimation {
                duration: root.mode === "dashboard" ? 460 : 340
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.mode === "dashboard" ? [0.2, 1.05, 0.3, 1, 1, 1] : [0.35, 0, 0.1, 1, 1, 1]
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: root.mode === "dashboard" ? 600 : 320
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.mode === "dashboard" ? [0.24, 1.22, 0.36, 1, 1, 1] : [0.35, 0, 0.1, 1, 1, 1]
            }
        }

        // Panel shishasi ustidagi sahna: har bo'limning rangi, musiqa bo'limida albom.
        Loader {
            anchors.fill: parent
            asynchronous: true
            opacity: root.mode === "dashboard" ? 1 : 0
            visible: opacity > 0
            sourceComponent: Backdrop {
                page: Ui.dashTab === 1 ? 1 : 0
                art: Ui.dashTab === 1 ? Media.art : ""
                playing: !!Media.player && Media.player.isPlaying
                bottomRadius: body.animatedRadius
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: root.mode === "dashboard" ? 300 : 120
                }
            }
        }

        // Bosish: soatda dashboard'ni ochadi, xabarda uni bajaradi.
        MouseArea {
            anchors.fill: parent
            cursorShape: root.mode === "dashboard" ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: {
                if (root.mode === "toast")
                    Toasts.activate();
                else if (root.mode === "idle")
                    Ui.openDashboard(0);
            }
        }

        // Idle: resource rings, the clock and the music, each opening its dashboard tab.
        Row {
            id: idleRow

            anchors.centerIn: parent
            spacing: 10
            opacity: root.mode === "idle" ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                }
            }

            // CPU, memory and temperature. Opens the System tab.
            BarButton {
                anchors.verticalCenter: parent.verticalCenter
                objectName: "rings"
                visible: root.showResources
                padding: 3
                lit: Ui.popup === "dashboard" && Ui.dashTab === 2
                onClicked: Ui.openDashboard(2)

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

            SystemClock {
                id: clock

                precision: root.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: Ui.recordBusy
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
            // The timer. A click pauses it, a right click stops it.
            Item {
                id: timerPart

                anchors.verticalCenter: parent.verticalCenter
                visible: Countdown.active
                width: timerRow.implicitWidth + 14
                height: 30

                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: Qt.alpha(Theme.text, timerArea.containsMouse ? 0.14 : 0.07)
                }
                Row {
                    id: timerRow

                    anchors.centerIn: parent
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
                        size: 14
                        font.weight: Font.Medium
                        font.features: {
                            "tnum": 1
                        }
                    }
                }
                MouseArea {
                    id: timerArea

                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton)
                            Countdown.stop();
                        else
                            Countdown.togglePause();
                    }
                }
            }
            // Recording time, or the seconds before a delayed one starts. A click stops it.
            Label {
                visible: Ui.recordBusy
                text: Ui.recording ? Ui.pad(Math.floor(Ui.recordSeconds / 60)) + ":" + Ui.pad(Ui.recordSeconds % 60) : String(Ui.recordCountdown)
                color: Theme.error
                size: 15
                font.weight: Font.Medium
                font.features: {
                    "tnum": 1
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Ui.toggleRecording()
                }
            }
            // The clock, with the date beside it. Opens the Today tab.
            BarButton {
                anchors.verticalCenter: parent.verticalCenter
                objectName: "clock"
                padding: 8
                lit: Ui.popup === "dashboard" && Ui.dashTab === 0
                onClicked: Ui.openDashboard(0)

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

            // The music: play or pause, the title and how far it has played. The title opens the
            // Music tab.
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
                        color: mediaArea.containsMouse ? Theme.accent : Theme.text
                    }
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
                        onClicked: Ui.openDashboard(1)
                    }
                }
            }
        }

        // Xabar yoki ovoz/yorqinlik darajasi
        Row {
            anchors.verticalCenter: parent.verticalCenter
            x: 20
            width: 400
            spacing: 13
            opacity: root.mode === "toast" ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 34
                height: 34
                radius: 10
                color: Theme.accent

                Icon {
                    anchors.centerIn: parent
                    visible: toastImage.status !== Image.Ready
                    name: root.shownToast ? root.shownToast.icon : "check"
                    color: Theme.accentText
                    size: 18
                }

                // A picture sent with a notification, such as a chat avatar, replaces the icon.
                ClippingRectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    visible: toastImage.status === Image.Ready

                    Image {
                        id: toastImage

                        anchors.fill: parent
                        source: root.currentToast && root.currentToast.image ? root.currentToast.image : ""
                        sourceSize: Qt.size(68, 68)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                    }
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 47
                spacing: 3

                Label {
                    width: parent.width
                    text: root.shownToast ? root.shownToast.title : ""
                    font.weight: Font.Medium
                }
                Label {
                    width: parent.width
                    visible: !!root.shownToast && root.shownToast.value < 0 && root.shownToast.sub !== ""
                    text: root.shownToast ? root.shownToast.sub : ""
                    color: Theme.muted
                    size: 13
                }
                Rectangle {
                    visible: !!root.shownToast && root.shownToast.value >= 0
                    width: parent.width
                    height: 4
                    radius: 2
                    color: Qt.alpha(Theme.text, 0.14)

                    Rectangle {
                        width: parent.width * (root.shownToast ? Math.max(0, root.shownToast.value) : 0)
                        height: parent.height
                        radius: 2
                        color: Theme.accent

                        Behavior on width {
                            NumberAnimation {
                                duration: 120
                            }
                        }
                    }
                }
            }
        }

        Loader {
            width: 1160
            height: root.targetHeight
            // Stays loaded after the first start: opening the panel creates nothing.
            asynchronous: true
            opacity: root.mode === "dashboard" ? 1 : 0
            visible: opacity > 0
            sourceComponent: Dashboard {}

            Behavior on opacity {
                NumberAnimation {
                    duration: root.mode === "dashboard" ? 260 : 130
                }
            }
        }

        // The wheel over the idle island: brightness left of the screen's middle, volume right of it.
        Item {
            anchors.fill: parent
            z: 10
            enabled: root.mode === "idle"

            WheelHandler {
                property real rest: 0

                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    rest += event.angleDelta.y !== 0 ? event.angleDelta.y : event.pixelDelta.y * 4;
                    while (Math.abs(rest) >= 120) {
                        const step = rest > 0 ? 1 : -1;
                        rest -= step * 120;
                        root.scrolled(point.position.x, step);
                    }
                }
            }
        }

        // Light along the free edge of the open panel, in the color of the current page.
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - 1
            width: parent.width * 0.7
            height: 1
            opacity: root.mode === "dashboard" ? 1 : 0
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: "transparent"
                }
                GradientStop {
                    position: 0.5
                    color: Ui.dashTab === 1 ? Media.artAccent : Theme.accent
                }
                GradientStop {
                    position: 1
                    color: "transparent"
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 300
                }
            }
        }
    }
}
