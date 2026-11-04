import QtQuick
import QtQuick.Shapes
import Quickshell
import qs.components
import qs.services

// Tepadagi orol: soat, xabarlar, ovoz, yozib olish va dashboard shu bitta joyda ochiladi.
Item {
    id: root

    property bool showDashboard: false
    property alias body: body

    readonly property string mode: showDashboard ? "dashboard" : Toasts.current ? "toast" : "idle"
    readonly property bool showSeconds: Settings.get("panel.clockSeconds", false)
    readonly property bool showDate: Settings.get("panel.clockDate", false)
    readonly property int targetWidth: mode === "dashboard" ? 1040 : mode === "toast" ? 440 : (Ui.recording ? 232 : 186) + (showSeconds ? 28 : 0) + (showDate ? 62 : 0)
    readonly property int targetHeight: mode === "dashboard" ? [470, 470, 560][Ui.dashTab] : mode === "toast" ? 68 : 44

    width: body.width
    height: body.height

    // Ekran chetiga qo'shilib turadigan ichki egilgan burchaklar.
    Shape {
        x: -18
        y: Settings.bottom ? body.height - 18 : 0
        width: 18
        height: 18
        transform: Scale {
            origin.y: 9
            yScale: Settings.bottom ? -1 : 1
        }
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: Theme.glassTop

            PathSvg {
                path: "M0 0 L18 0 L18 18 A18 18 0 0 0 0 0 Z"
            }
        }
    }
    Shape {
        x: body.width
        y: Settings.bottom ? body.height - 18 : 0
        width: 18
        height: 18
        transform: Scale {
            origin.y: 9
            yScale: Settings.bottom ? -1 : 1
        }
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: Theme.glassTop

            PathSvg {
                path: "M18 0 L0 0 L0 18 A18 18 0 0 1 18 0 Z"
            }
        }
    }

    Rectangle {
        id: body

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
        topLeftRadius: Settings.bottom ? 18 : 0
        topRightRadius: Settings.bottom ? 18 : 0
        bottomLeftRadius: Settings.bottom ? 0 : 18
        bottomRightRadius: Settings.bottom ? 0 : 18
        clip: true

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

        // Panel orqasida xiralashgan rasm: fon rasmi, musiqa bo'limida albom.
        Loader {
            anchors.fill: parent
            active: root.mode === "dashboard" || opacity > 0
            opacity: root.mode === "dashboard" ? 1 : 0
            visible: opacity > 0
            sourceComponent: Backdrop {
                art: Ui.dashTab === 1 && Media.player ? Media.player.trackArtUrl : ""
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
                    const time = Ui.pad(clock.hours) + ":" + Ui.pad(clock.minutes) + (root.showSeconds ? ":" + Ui.pad(clock.seconds) : "");
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
                    name: Toasts.current ? Toasts.current.icon : "check"
                    color: Theme.accentText
                    size: 18
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 47
                spacing: 3

                Label {
                    width: parent.width
                    text: Toasts.current ? Toasts.current.title : ""
                    font.weight: Font.Medium
                }
                Label {
                    width: parent.width
                    visible: !!Toasts.current && Toasts.current.value < 0 && Toasts.current.sub !== ""
                    text: Toasts.current ? Toasts.current.sub : ""
                    color: Theme.muted
                    size: 13
                }
                Rectangle {
                    visible: !!Toasts.current && Toasts.current.value >= 0
                    width: parent.width
                    height: 4
                    radius: 2
                    color: Qt.alpha(Theme.text, 0.14)

                    Rectangle {
                        width: parent.width * (Toasts.current ? Math.max(0, Toasts.current.value) : 0)
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
            width: 1040
            height: root.targetHeight
            active: root.mode === "dashboard" || opacity > 0
            opacity: root.mode === "dashboard" ? 1 : 0
            visible: opacity > 0
            sourceComponent: Dashboard {}

            Behavior on opacity {
                NumberAnimation {
                    duration: root.mode === "dashboard" ? 260 : 130
                }
            }
        }
    }
}
