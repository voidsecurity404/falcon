import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.services

// Tepadagi orol: soat, xabarlar, ovoz, yozib olish va dashboard shu bitta joyda ochiladi.
Item {
    id: root

    property bool showDashboard: false
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

    readonly property string mode: showDashboard ? "dashboard" : Toasts.current ? "toast" : "idle"
    readonly property bool showSeconds: Settings.get("panel.clockSeconds", false)
    readonly property bool showDate: Settings.get("panel.clockDate", false)
    readonly property bool clock24: Settings.get("panel.clock24", true)
    readonly property int targetWidth: mode === "dashboard" ? 1160 : mode === "toast" ? 440 : (Ui.recording ? 232 : 186) + (showSeconds ? 28 : 0) + (showDate ? 62 : 0) + (clock24 ? 0 : 26)
    readonly property int cornerRadius: mode === "dashboard" ? 32 : 18
    readonly property int targetHeight: mode === "dashboard" ? 580 : mode === "toast" ? 68 : 44

    width: body.width
    height: body.height

    // Ekran chetiga qo'shilib turadigan ichki egilgan burchaklar.
    EdgeCurve {
        x: -size
        y: body.y + (Settings.bottom ? body.height - size : 0)
        flipX: true
        flipY: Settings.bottom
        color: Theme.glassTop
    }
    EdgeCurve {
        x: body.width
        y: body.y + (Settings.bottom ? body.height - size : 0)
        flipY: Settings.bottom
        color: Theme.glassTop
    }

    Rectangle {
        id: body

        y: (Settings.bottom ? 1 : -1) * root.slide * (body.height + 28)
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
        topLeftRadius: Settings.bottom ? animatedRadius : 0
        topRightRadius: Settings.bottom ? animatedRadius : 0
        bottomLeftRadius: Settings.bottom ? 0 : animatedRadius
        bottomRightRadius: Settings.bottom ? 0 : animatedRadius
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
                    Ui.togglePopup("dashboard");
            }
        }

        // Oddiy holat: soat
        Row {
            anchors.centerIn: parent
            spacing: 10
            opacity: root.mode === "idle" ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                }
            }

            SystemClock {
                id: clock

                precision: root.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: Ui.recording
                width: 8
                height: 8
                radius: 4
                color: Theme.error

                SequentialAnimation on opacity {
                    running: Ui.recording
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
                visible: Ui.recording
                text: Ui.pad(Math.floor(Ui.recordSeconds / 60)) + ":" + Ui.pad(Ui.recordSeconds % 60)
                color: Theme.error
                size: 15
                font.weight: Font.Medium
            }
            Label {
                text: {
                    const hours = root.clock24 ? clock.hours : clock.hours % 12 || 12;
                    const time = Ui.pad(hours) + ":" + Ui.pad(clock.minutes) + (root.showSeconds ? ":" + Ui.pad(clock.seconds) : "") + (root.clock24 ? "" : clock.hours < 12 ? " AM" : " PM");
                    return root.showDate ? Ui.pad(clock.date.getDate()) + "." + Ui.pad(clock.date.getMonth() + 1) + "  " + time : time;
                }
                size: 15
                font.weight: Font.Medium
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

        // Light along the free edge of the open panel, in the color of the current page.
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Settings.bottom ? 0 : parent.height - 1
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
