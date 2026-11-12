import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.components
import qs.services

// The farewell before logging out, rebooting or shutting down, one per screen (see Session.leave).
// The screen is pictured and shown frozen; it sinks back, blurs and goes dark, while the falcon of
// the boot screen (Plymouth's own frames, same size and place) beats its wings over a caption.
// Then the falcon and caption fade, and on the black screen Session runs the command. Plymouth's
// shutdown screen shows the same falcon in the same place a moment later.
PanelWindow {
    id: root

    readonly property string outputName: screen ? screen.name : ""
    readonly property string picture: Session.shotDir + "/" + outputName + ".ppm"
    readonly property string frames: "/usr/share/plymouth/themes/falcon/throbber-"
    readonly property bool playing: Session.phase === "play" || Session.phase === "done"
    property real ms: 0
    property int frame: 0
    property bool haveFalcon: false

    function part(a, b, curve) {
        const t = Math.max(0, Math.min(1, (ms - a) / (b - a)));
        if (curve === "out")
            return 1 - Math.pow(1 - t, 3);
        return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
    }

    visible: Session.phase === "grab" || playing
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "falcon-leave"
    // Nothing typed or clicked during the farewell reaches the windows.
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Connections {
        target: Session

        function onPhaseChanged() {
            if (Session.phase === "grab") {
                shot.source = "";
                root.ms = 0;
                grab.running = true;
            } else if (Session.phase === "play") {
                show.restart();
            } else if (Session.phase === "") {
                show.stop();
                root.ms = 0;
                shot.source = "";
            }
        }
    }

    Component.onCompleted: probe.running = true

    // Plymouth's frames are there once falcon-boot has run; without them the caption stays alone.
    Process {
        id: probe

        command: ["test", "-r", root.frames + "00.png"]
        onExited: code => root.haveFalcon = code === 0
    }

    Process {
        id: grab

        command: ["sh", "-c", 'mkdir -p "$(dirname "$2")" && exec grim -t ppm -o "$1" "$2"', "sh", root.outputName, root.picture]
        onExited: code => {
            if (code !== 0)
                Session.screenReady(root.outputName, false);
            else
                shot.source = "file://" + root.picture + "?" + Date.now();
        }
    }

    NumberAnimation {
        id: show

        target: root
        property: "ms"
        from: 0
        to: Session.showLength
        duration: Session.showLength
        onFinished: {
            Quickshell.execDetached(["rm", "-f", root.picture]);
            // Every screen plays the same length; the first one to end runs the command.
            Session.showDone();
        }
    }

    // The wing beat, at the speed Plymouth plays it.
    Timer {
        interval: 33
        repeat: true
        running: root.playing && root.haveFalcon
        onTriggered: root.frame = (root.frame + 1) % 48
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: root.playing ? 1 : 0
    }

    Image {
        id: shot

        anchors.fill: parent
        asynchronous: true
        cache: false
        fillMode: Image.Stretch
        visible: false
        onStatusChanged: {
            if (status === Image.Ready)
                Session.screenReady(root.outputName, true);
            else if (status === Image.Error)
                Session.screenReady(root.outputName, false);
        }
    }

    // The desktop sinks back into the dark.
    MultiEffect {
        source: shot
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        visible: shot.status === Image.Ready && root.ms < 1000
        scale: 1 - 0.08 * root.part(0, 900, "out")
        opacity: 1 - root.part(250, 950)
        blurEnabled: true
        blur: 0.9 * root.part(0, 700, "out")
        blurMax: 48
        brightness: -0.35 * root.part(0, 700)
        saturation: -0.4 * root.part(0, 700)
        autoPaddingEnabled: false
    }

    // Plymouth draws its frames at their own size in the middle, so this one is the same.
    Item {
        id: falcon

        readonly property real shown: root.part(380, 820, "out") * (1 - root.part(1250, 1600))

        width: 300
        height: 360
        anchors.centerIn: parent
        visible: root.haveFalcon && shown > 0
        opacity: shown
        scale: 0.92 + 0.08 * root.part(380, 900, "out")

        Image {
            anchors.fill: parent
            source: root.haveFalcon && root.playing ? root.frames + String(root.frame).padStart(2, "0") + ".png" : ""
            sourceSize: Qt.size(300, 360)
            cache: true
            smooth: true
        }
    }

    Label {
        anchors.horizontalCenter: parent.horizontalCenter
        y: (root.haveFalcon ? parent.height / 2 + 200 : parent.height / 2 - height / 2) + 12 * (1 - root.part(520, 950, "out"))
        opacity: 0.85 * root.part(520, 950, "out") * (1 - root.part(1150, 1450))
        visible: opacity > 0
        text: Session.kind === "reboot" ? Tr.t("Restarting") : Session.kind === "logout" ? Tr.t("Logging out") : Tr.t("Shutting down")
        color: "white"
        size: 17
        font.letterSpacing: 1.5
    }
}
