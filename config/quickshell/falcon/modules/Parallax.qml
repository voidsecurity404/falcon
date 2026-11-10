import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.services

// The wallpaper drawn by the shell, a little taller than the screen, sliding up as you go
// down the workspaces. It lies in the backdrop over awww's copy and under the widgets. A new
// picture comes in through shaders/wallpaper.frag with the effect chosen in the settings, or a
// random one. With a live wallpaper it stays transparent, so the video and its first frame show
// through.
PanelWindow {
    id: root

    property string outputName: ""
    readonly property real amount: Math.max(0, Math.min(0.2, Settings.get("wallpaper.parallaxAmount", 0.06)))
    readonly property int steps: 4
    readonly property var active: Niri.activeWorkspaceOn(outputName)
    readonly property real place: active ? Math.max(0, Math.min(steps, active.idx - 1)) / steps : 0
    readonly property real tall: height * (1 + amount)

    // The picture on screen and the one coming in.
    property string shown: ""
    property string coming: ""
    property real arrival: 1
    readonly property string effect: Settings.get("wallpaper.transition", "grow")
    // Effects of the shader, in its order. "random" picks one of them for each change.
    readonly property var effects: ["fade", "grow", "wipe", "wave", "dissolve", "pixels", "blocks", "shatter", "glitch", "melt", "ripple", "zoom", "swirl", "blinds", "push"]
    property int effectIndex: 1
    property real seed: 0

    function receive(path) {
        if (!path || path === shown || path === coming)
            return;
        if (shown === "" || effect === "none" || !visible) {
            arrive.stop();
            coming = "";
            shown = path;
            return;
        }
        arrive.stop();
        if (coming !== "")
            shown = coming;
        effectIndex = effect === "random" ? Math.floor(Math.random() * effects.length) : Math.max(0, effects.indexOf(effect));
        seed = Math.random();
        arrival = 0;
        coming = path;
    }

    Component.onCompleted: receive(Wallpapers.shownImage)

    Connections {
        target: Wallpapers

        function onShownImageChanged() {
            root.receive(Wallpapers.shownImage);
        }
    }

    NumberAnimation {
        id: arrive

        target: root
        property: "arrival"
        to: 1
        duration: Math.max(200, Settings.get("wallpaper.duration", 1) * 1000)
        easing.type: Easing.InOutCubic
        onFinished: {
            root.shown = root.coming;
            root.coming = "";
        }
    }

    // Turned on later, it opens above the widgets, so they are opened again on top.
    readonly property bool wanted: Settings.get("wallpaper.parallax", true)
    onWantedChanged: {
        if (wanted)
            Widgets.restack();
    }

    visible: wanted && !Widgets.restackingBack
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "falcon-parallax"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Item {
        id: stage

        width: root.width
        height: root.tall
        y: -root.place * (root.tall - root.height)
        // A new live wallpaper's first frame arrives like any picture, and only then gives way to the
        // video, which starts on that same frame.
        opacity: Wallpapers.shownLive && root.coming === "" ? 0 : 1

        Behavior on y {
            NumberAnimation {
                duration: 420
                easing.type: Easing.OutCubic
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: 300
            }
        }

        Image {
            id: under

            anchors.fill: parent
            source: root.shown ? "file://" + root.shown : ""
            sourceSize: Qt.size(root.width, root.tall)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }

        // The new picture, hidden: the shader below draws both while it arrives.
        Image {
            id: over

            anchors.fill: parent
            visible: false
            source: root.coming ? "file://" + root.coming : ""
            sourceSize: Qt.size(root.width, root.tall)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            onStatusChanged: {
                if (status === Image.Ready && root.coming !== "")
                    arrive.restart();
                else if (status === Image.Error)
                    root.coming = "";
            }
        }
        ShaderEffect {
            // Grow opens from the middle of the bottom edge of the screen, as awww does.
            readonly property real openFromY: root.height + root.place * (root.tall - root.height)

            anchors.fill: parent
            visible: root.coming !== "" && over.status === Image.Ready
            property variant from: under
            property variant to: over
            property real progress: root.arrival
            property real effect: root.effectIndex
            property real seed: root.seed
            property vector2d size: Qt.vector2d(width, height)
            property vector2d origin: Qt.vector2d(0.5, openFromY / Math.max(1, root.tall))
            fragmentShader: Qt.resolvedUrl("../shaders/wallpaper.frag.qsb")
        }
    }
}
