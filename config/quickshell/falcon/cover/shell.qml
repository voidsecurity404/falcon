import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// The cover over the screen while falcon-session brings the windows back after login. It is its own
// small Quickshell config, started by falcon-session as `qs -p`, because it is up in about 0.1 s while
// the whole shell takes most of a second, and apps start only once it is on screen. It shows the
// wallpaper that is underneath with a clock, and when the flag file goes it fades away and quits,
// revealing the desktop with every window already in place. A click lifts it early.
//
// Leaving is one value, `out`, from 0 to 1: the clock and caption float up and blur away, then a
// soft round opening grows from the middle of the screen and shows the windows under it, while the
// picture around it swells a little and blurs, as if the desktop came through a lens.
ShellRoot {
    id: root

    readonly property string flag: Quickshell.env("FALCON_COVER_FLAG") || (Quickshell.env("XDG_RUNTIME_DIR") + "/falcon-restoring")
    readonly property string caption: Quickshell.env("FALCON_COVER_TEXT") || "Restoring your windows"
    readonly property string wallpaper: Quickshell.env("HOME") + "/.local/state/falcon/wallpaper"
    property bool leaving: false
    property real out: 0
    // The login screen ends in black, so the cover comes up out of black too.
    property real dawn: 0

    NumberAnimation on dawn {
        from: 0
        to: 1
        duration: 700
        easing.type: Easing.InOutQuad
    }

    function leave() {
        if (leaving)
            return;
        leaving = true;
        outAnimation.start();
    }

    // A part of `out` from a to b, eased out, or in and out with `smooth`.
    function part(a, b, smooth) {
        const t = Math.max(0, Math.min(1, (out - a) / (b - a)));
        if (smooth)
            return t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2;
        return 1 - Math.pow(1 - t, 3);
    }

    NumberAnimation {
        id: outAnimation

        target: root
        property: "out"
        from: 0
        to: 1
        duration: 1000
        onFinished: Qt.quit()
    }

    Process {
        id: probe

        command: ["test", "-e", root.flag]
        onExited: code => {
            if (code !== 0)
                root.leave();
        }
    }

    Timer {
        interval: 50
        repeat: true
        running: !root.leaving
        onTriggered: probe.running = true
    }

    // An app that never opens a window must not keep the desktop hidden.
    Timer {
        interval: 15000
        running: true
        onTriggered: root.leave()
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: win

                required property ShellScreen modelData

                screen: modelData
                anchors {
                    top: true
                    bottom: true
                    left: true
                    right: true
                }
                exclusionMode: ExclusionMode.Ignore
                color: "transparent"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "falcon-cover"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

                // The opening: one soft disc drawn once and only scaled, so each frame costs no new
                // drawing. Its edge is a quarter of its radius, so it stays soft as it grows.
                readonly property real reach: Math.sqrt(width * width + height * height) / 2 / 0.75 + 40
                readonly property real hole: root.part(0.1, 0.92, true) * reach

                Item {
                    id: opening

                    anchors.fill: parent
                    visible: false
                    layer.enabled: root.leaving

                    Shape {
                        width: 1000
                        height: 1000
                        anchors.centerIn: parent
                        scale: win.hole / 500

                        ShapePath {
                            strokeColor: "transparent"
                            fillGradient: RadialGradient {
                                centerX: 500
                                centerY: 500
                                centerRadius: 500
                                focalX: 500
                                focalY: 500

                                GradientStop {
                                    position: 0
                                    color: "white"
                                }
                                GradientStop {
                                    position: 0.72
                                    color: "white"
                                }
                                GradientStop {
                                    position: 1
                                    color: "transparent"
                                }
                            }
                            startX: 0
                            startY: 0

                            PathLine {
                                x: 1000
                                y: 0
                            }
                            PathLine {
                                x: 1000
                                y: 1000
                            }
                            PathLine {
                                x: 0
                                y: 1000
                            }
                            PathLine {
                                x: 0
                                y: 0
                            }
                        }
                    }
                }

                Item {
                    id: veil

                    anchors.fill: parent
                    // A last fade, so no edge of the opening is left in a corner.
                    opacity: 1 - root.part(0.85, 1, true)
                    layer.enabled: root.leaving
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: opening
                        maskInverted: true
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 0.5
                        blurEnabled: true
                        blur: root.part(0.05, 0.9) * 0.7
                        blurMax: 48
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "black"
                    }

                    // Loaded before the first frame, so the cover never flashes black.
                    Image {
                        anchors.fill: parent
                        source: "file://" + root.wallpaper
                        sourceSize: Qt.size(win.width || 1920, win.height || 1080)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: false
                        cache: false
                        scale: 1 + 0.07 * root.part(0, 1)
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(0, 0, 0, 0.28 + 0.12 * root.part(0, 0.5))
                    }

                    Column {
                        id: middle

                        property real intro: 0

                        readonly property real gone: root.part(0, 0.34)

                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: (1 - intro) * 14 - gone * 34
                        spacing: 14
                        opacity: intro * (1 - gone)
                        scale: (0.96 + 0.04 * intro) * (1 + 0.08 * gone)
                        // A soft shadow keeps the text readable over a busy picture.
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: "black"
                            shadowOpacity: 0.6
                            shadowBlur: 1
                            blurMax: 40
                            shadowVerticalOffset: 2
                            blurEnabled: middle.gone > 0
                            blur: middle.gone
                        }

                        NumberAnimation on intro {
                            from: 0
                            to: 1
                            duration: 450
                            easing.type: Easing.OutCubic
                        }

                        Text {
                            id: clock

                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.formatTime(new Date(), "HH:mm")
                            color: "white"
                            font.family: "Unbounded"
                            font.pixelSize: 104
                            font.features: {
                                "tnum": 1
                            }

                            Timer {
                                interval: 1000
                                repeat: true
                                running: true
                                onTriggered: clock.text = Qt.formatTime(new Date(), "HH:mm")
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.caption
                            visible: text.trim() !== ""
                            color: Qt.rgba(1, 1, 1, 0.78)
                            font.family: Quickshell.env("FALCON_COVER_FONT") || "Geist"
                            font.pixelSize: 15
                            renderType: Text.NativeRendering
                        }

                        Row {
                            id: dots

                            property real phase: 0

                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 8
                            topPadding: 4

                            NumberAnimation on phase {
                                from: 0
                                to: 3
                                duration: 1200
                                loops: Animation.Infinite
                            }

                            Repeater {
                                model: 3

                                Rectangle {
                                    required property int index
                                    // Each dot brightens as the wave passes it.
                                    readonly property real near: Math.max(0, 1 - Math.abs(((dots.phase - index + 4.5) % 3) - 1.5))

                                    width: 6
                                    height: 6
                                    radius: 3
                                    color: "white"
                                    opacity: 0.3 + 0.7 * near
                                    scale: 0.85 + 0.3 * near
                                }
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "black"
                        opacity: 1 - root.dawn
                        visible: opacity > 0
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !root.leaving
                    onClicked: root.leave()
                }
            }
        }
    }
}
