import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.services

// The wallpaper drawn by the shell, a little taller than the screen, sliding up as you go
// down the workspaces. It lies in the backdrop over awww's copy and under the widgets. A new
// picture comes in with the same effect as awww's (grow, fade, wipe). With a live wallpaper
// it stays transparent, so the video and its first frame show through.
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

        // The new picture, revealed by the chosen effect once it has loaded.
        ClippingRectangle {
            id: reveal

            readonly property bool growing: root.effect === "grow" || root.effect === "wave"
            readonly property bool wiping: root.effect === "wipe"
            // Grow opens a circle from the middle of the bottom edge, as awww does.
            readonly property real reach: Math.sqrt(Math.pow(root.width / 2, 2) + Math.pow(root.height, 2)) + 2
            readonly property real r: reach * root.arrival
            readonly property real openFromY: root.height + root.place * (root.tall - root.height)

            visible: root.coming !== ""
            color: "transparent"
            x: growing ? root.width / 2 - r : 0
            y: growing ? openFromY - r : 0
            width: growing ? r * 2 : wiping ? root.width * root.arrival : root.width
            height: growing ? r * 2 : root.tall
            radius: growing ? r : 0
            opacity: growing || wiping ? 1 : root.arrival

            Image {
                id: over

                x: -reveal.x
                y: -reveal.y
                width: root.width
                height: root.tall
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
        }
    }
}
