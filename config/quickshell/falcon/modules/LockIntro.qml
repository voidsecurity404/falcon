import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.components
import qs.services

// The locking show of Mod+L, one per screen. The screen is pictured first and shown frozen; the
// desktop sinks into blur while the lock background settles over it, a lock badge pops up in the
// middle, snaps shut and stretches into the password field, and the clock rises into place.
// Its last frame is exactly hyprlock's first (same picture from falcon-lock-bg, same places as in
// hyprlock.conf), and hyprlock fades in over it, so the hand-over cannot be seen.
PanelWindow {
    id: root

    readonly property string outputName: screen ? screen.name : ""
    readonly property string picture: Lock.introDir + "/" + outputName + ".ppm"
    readonly property bool playing: Lock.intro === "play" || Lock.intro === "hold"
    // Milliseconds into the show.
    property real ms: 0

    // Eased share of the part of the show between a and b milliseconds.
    function part(a, b, curve) {
        const t = Math.max(0, Math.min(1, (ms - a) / (b - a)));
        switch (curve) {
        case "out":
            return 1 - Math.pow(1 - t, 3);
        case "outQuint":
            return 1 - Math.pow(1 - t, 5);
        case "back":
            const c = 1.9;
            return 1 + (c + 1) * Math.pow(t - 1, 3) + c * Math.pow(t - 1, 2);
        default:
            return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
        }
    }
    function mix(a, b, t) {
        return a + (b - a) * t;
    }

    visible: Lock.intro !== ""
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "falcon-lock-intro"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Connections {
        target: Lock
        function onIntroChanged() {
            if (Lock.intro === "grab") {
                shot.source = "";
                root.ms = 0;
                grab.running = true;
            } else if (Lock.intro === "play") {
                show.restart();
            } else if (Lock.intro === "") {
                show.stop();
                root.ms = 0;
                shot.source = "";
            }
        }
    }

    Process {
        id: grab

        command: ["sh", "-c", 'mkdir -p "$(dirname "$2")" && exec grim -t ppm -o "$1" "$2"', "sh", root.outputName, root.picture]
        onExited: code => {
            if (code !== 0) {
                Lock.screenReady(root.outputName, false);
                return;
            }
            shot.source = "file://" + root.picture + "?" + Date.now();
        }
    }

    NumberAnimation {
        id: show

        target: root
        property: "ms"
        from: 0
        to: Lock.introLength
        duration: Lock.introLength
        onFinished: {
            Lock.introDone();
            Quickshell.execDetached(["rm", "-f", root.picture]);
        }
    }

    // Takes every key and click while it is up.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
    }
    Item {
        focus: true
        Keys.onPressed: event => event.accepted = true
    }

    // The desktop as it was, sinking back into blur and shade.
    Item {
        id: desk

        anchors.fill: parent
        visible: shot.status === Image.Ready
        scale: root.mix(1, 1.07, root.part(0, 900, "inOut"))

        Image {
            id: shot

            anchors.fill: parent
            cache: false
            asynchronous: true
            visible: false
            onStatusChanged: {
                if (status === Image.Ready)
                    Lock.screenReady(root.outputName, true);
                else if (status === Image.Error)
                    Lock.screenReady(root.outputName, false);
            }
        }
        MultiEffect {
            anchors.fill: parent
            source: shot
            blurEnabled: true
            blurMax: 64
            blur: root.part(0, 650, "out")
            brightness: -0.3 * root.part(0, 700, "inOut")
            saturation: 0.2 * root.part(0, 700, "inOut")
        }
    }

    // hyprlock's background, settling from a little closer.
    Image {
        anchors.fill: parent
        source: root.visible ? "file://" + Lock.background : ""
        cache: false
        asynchronous: false
        fillMode: Image.PreserveAspectCrop
        opacity: root.part(120, 640, "inOut")
        scale: root.mix(1.12, 1, root.part(120, 1000, "outQuint"))
        visible: root.playing
    }

    // A glow that breathes out from the middle as the badge lands.
    Rectangle {
        anchors.centerIn: parent
        width: root.mix(80, Math.max(root.width, root.height) * 1.4, root.part(260, 950, "out"))
        height: width
        radius: width / 2
        color: "transparent"
        border.width: root.mix(18, 1, root.part(260, 950, "out"))
        border.color: Theme.accent
        opacity: 0.35 * (1 - root.part(260, 950, "inOut")) * (root.ms > 260 ? 1 : 0)
        visible: root.playing
    }

    // hyprlock.conf places its parts from the middle of the screen, y upward.
    Item {
        id: stage

        anchors.fill: parent
        visible: root.playing
        readonly property real cy: height / 2

        // The clock, $TIME at 0, 170, Geist Light 132.
        Text {
            id: time

            readonly property real rise: root.part(520, 980, "out")
            text: Qt.formatTime(new Date(), "HH:mm")
            color: Theme.text
            font.family: "Geist"
            font.weight: Font.Light
            font.pixelSize: 176
            font.letterSpacing: root.mix(30, 2.2, rise)
            renderType: Text.NativeRendering
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: 2
            y: stage.cy - 171 - height / 2 + root.mix(46, 0, rise)
            opacity: rise
        }

        // The date at 0, 66, Geist 19.
        Text {
            readonly property real rise: root.part(640, 1060, "out")
            text: Qt.formatDate(new Date(), "dd.MM.yyyy")
            color: Theme.text
            font.family: "Geist"
            font.pixelSize: 25
            font.letterSpacing: 0.3
            renderType: Text.NativeRendering
            anchors.horizontalCenter: parent.horizontalCenter
            y: stage.cy - 66 - height / 2 + root.mix(24, 0, rise)
            opacity: rise
        }

        // The lock badge, which becomes the password field at 0, -40 (300x46, rounding 13).
        Rectangle {
            id: field

            readonly property real pop: root.part(150, 470, "back")
            readonly property real morph: root.part(560, 900, "inOut")
            readonly property real side: 96
            width: root.mix(side, 300, morph)
            height: root.mix(side, 46, morph)
            radius: root.mix(side / 2, 13, morph)
            x: (parent.width - width) / 2
            y: root.mix(stage.cy - side / 2 - 20, stage.cy + 40 - 23, morph)
            scale: pop
            color: Qt.tint(Theme.accent, Qt.alpha(Theme.pill, morph))
            antialiasing: true

            // A lock drawn by hand, so its shackle can snap shut.
            Item {
                id: padlock

                readonly property real shut: root.part(380, 520, "back")
                width: 34
                height: 38
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 1
                opacity: 1 - root.part(560, 700, "inOut")
                scale: 1.3 - 0.6 * root.part(560, 700, "inOut")

                Shape {
                    x: 7
                    y: root.mix(-7, 0, padlock.shut)
                    width: 20
                    height: 20
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: Theme.accentText
                        strokeWidth: 4
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        startX: 2
                        startY: 20
                        PathLine {
                            x: 2
                            y: 10
                        }
                        PathArc {
                            x: 18
                            y: 10
                            radiusX: 8
                            radiusY: 8
                        }
                        PathLine {
                            x: 18
                            y: root.mix(14, 20, padlock.shut)
                        }
                    }
                }
                Rectangle {
                    y: 17
                    width: 34
                    height: 21
                    radius: 6
                    color: Theme.accentText
                    Rectangle {
                        anchors.centerIn: parent
                        width: 4
                        height: 8
                        radius: 2
                        color: Theme.accent
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                text: Tr.t("Password")
                color: Theme.text
                font.family: "Geist"
                font.pixelSize: 15
                renderType: Text.NativeRendering
                opacity: root.part(780, 1080, "out")
            }
        }

        // The keyboard layout at 0, -92, Geist Mono 13.
        Text {
            readonly property real rise: root.part(820, 1120, "out")
            text: Niri.layoutLabel === "RU" ? "RU" : "EN"
            color: Theme.text
            font.family: "Geist Mono"
            font.pixelSize: 17
            renderType: Text.NativeRendering
            anchors.horizontalCenter: parent.horizontalCenter
            y: stage.cy + 91 - height / 2 + root.mix(14, 0, rise)
            opacity: rise
        }
    }
}
