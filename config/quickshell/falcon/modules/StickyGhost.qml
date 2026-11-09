import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.services

// Still pictures of the sticky windows, in their places, while niri slides the workspaces under
// them. See services/Sticky.qml. Mapped while any window is sticky and takes no input. A switch
// pictures the sticky windows with grim, shows them, and only then lets the windows go.
//
// No ScreencopyView here: Quickshell 0.3.2's screencopy binds its own wl_output, niri then sends
// surface enter events for it, and Qt takes it for one of its screens and crashes in
// QWaylandWindow::handleScreensChanged whenever a window of the shell maps (the region selector
// most often). grim is a separate client, so its outputs never reach the shell.
PanelWindow {
    id: root

    visible: Sticky.active
    screen: Quickshell.screens.find(s => s.name === (Sticky.ghostOutput || Niri.focusedOutput)) || Quickshell.screens[0]
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "falcon-sticky-ghost"
    mask: Region {}

    readonly property real radius: Settings.get("windows.radius", 13)
    readonly property string picture: Sticky.shotDir + "/ghost.ppm"
    // The box around all sticky windows, pictured by one grim: two in parallel slowed each other.
    property rect box: Qt.rect(0, 0, 0, 0)
    // The picture of this switch is decoded.
    readonly property bool pictured: shotImage.status === Image.Ready && shotImage.source != ""

    Process {
        id: shot
        onExited: code => {
            if (code !== 0 || !Sticky.ghostShown) {
                Sticky.ghostReady();
                return;
            }
            shotImage.source = "file://" + root.picture;
        }
    }

    // A hidden item is left out of ShaderEffectSource too, so the picture stays visible inside an
    // empty clipped box: nothing of it shows on screen, and the sources below can still draw it.
    Item {
        width: 0
        height: 0
        clip: true

        Image {
            id: shotImage
            width: root.box.width
            height: root.box.height
            asynchronous: false
            cache: false
            onStatusChanged: {
                if (status === Image.Ready && source != "" && Sticky.ghostShown)
                    drawn.restart();
            }
        }
    }

    Repeater {
        model: root.pictured && Sticky.ghostShown ? Sticky.ghostRects : []

        ClippingRectangle {
            id: frame
            required property var modelData
            x: modelData ? modelData.x : 0
            y: modelData ? modelData.y : 0
            width: modelData ? modelData.w : 0
            height: modelData ? modelData.h : 0
            radius: root.radius
            color: "transparent"

            ShaderEffectSource {
                anchors.fill: parent
                sourceItem: shotImage
                sourceRect: frame.modelData ? Qt.rect(frame.modelData.x - root.box.x, frame.modelData.y - root.box.y, frame.modelData.w, frame.modelData.h) : Qt.rect(0, 0, 0, 0)
                live: false
            }
        }
    }

    Connections {
        target: Sticky
        function onGhostShownChanged() {
            shotImage.source = "";
            if (!Sticky.ghostShown)
                return;
            const rects = Sticky.ghostRects;
            const x = Math.floor(Math.min(...rects.map(r => r.x)));
            const y = Math.floor(Math.min(...rects.map(r => r.y)));
            const w = Math.ceil(Math.max(...rects.map(r => r.x + r.w))) - x;
            const h = Math.ceil(Math.max(...rects.map(r => r.y + r.h))) - y;
            root.box = Qt.rect(x, y, w, h);
            shot.command = ["sh", "-c", 'mkdir -m 700 -p "${2%/*}" && exec grim -t ppm -g "$1" "$2"', "sh", `${root.screen.x + x},${root.screen.y + y} ${w}x${h}`, root.picture];
            shot.running = true;
        }
    }

    // The pictures are drawn on the next frame, and only then may the windows go.
    Timer {
        id: drawn
        interval: 17
        onTriggered: Sticky.ghostReady()
    }
}
