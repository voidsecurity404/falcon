import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// The cover over the screen while falcon-session brings the windows back after login. It is its own
// small Quickshell config, started by falcon-session as `qs -p`, because it is up in about 0.1 s while
// the whole shell takes most of a second, and apps start only once it is on screen. It shows the
// wallpaper that is underneath with a clock, and when the flag file goes it fades away and quits,
// revealing the desktop with every window already in place. A click lifts it early.
ShellRoot {
    id: root

    readonly property string flag: Quickshell.env("FALCON_COVER_FLAG") || (Quickshell.env("XDG_RUNTIME_DIR") + "/falcon-restoring")
    readonly property string caption: Quickshell.env("FALCON_COVER_TEXT") || "Restoring your windows"
    readonly property string wallpaper: Quickshell.env("HOME") + "/.local/state/falcon/wallpaper"
    property bool leaving: false

    function leave() {
        leaving = true;
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
        interval: 100
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

    Timer {
        interval: 420
        running: root.leaving
        onTriggered: Qt.quit()
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

                Item {
                    id: veil

                    anchors.fill: parent
                    opacity: root.leaving ? 0 : 1

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 380
                            easing.type: Easing.InOutCubic
                        }
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
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(0, 0, 0, 0.28)
                    }

                    Column {
                        id: middle

                        property real intro: 0

                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: (1 - intro) * 14 + (1 - veil.opacity) * -10
                        spacing: 14
                        opacity: intro
                        scale: 0.96 + 0.04 * intro
                        // A soft shadow keeps the text readable over a busy picture.
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: "black"
                            shadowOpacity: 0.6
                            shadowBlur: 1
                            blurMax: 40
                            shadowVerticalOffset: 2
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
