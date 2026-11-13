import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.services

// Still pictures of the sticky windows, in their places, while niri slides the workspaces under
// them. See services/Sticky.qml. Mapped while any window is sticky and takes no input.
//
// A switch must not wait for a picture, so while sticky windows are seen they are pictured with
// grim every `period` ms into two files in turn, each decoded in the background, and the newest
// one that is ready is kept. A switch shows it at once if it was taken of the same places, and on
// the next frame lets the windows go. Otherwise it pictures them first, as a fallback.
//
// No ScreencopyView here: Quickshell 0.3.2's screencopy binds its own wl_output, niri then sends
// surface enter events for it, and Qt takes it for one of its screens and crashes in
// QWaylandWindow::handleScreensChanged whenever a window of the shell maps (the region selector
// most often). grim is a separate client, so its outputs never reach the shell.
PanelWindow {
    id: root

    visible: Sticky.emulated
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
    readonly property int period: 250
    // A kept picture older than this is not used. It is of the same places, so an older one only
    // freezes a slightly earlier frame of a video, which beats a switch that waits.
    readonly property int maxAge: 3000
    // Younger than this, a kept picture is used even while a new one is being taken.
    readonly property int freshAge: 400

    // What is pictured now: its key (output and places), box on the output, and which file.
    property string takingKey: ""
    property rect takingBox: Qt.rect(0, 0, 0, 0)
    property int takingSlot: 0
    // The newest decoded picture.
    property int frontSlot: -1
    property string frontKey: ""
    property rect frontBox: Qt.rect(0, 0, 0, 0)
    property real frontTime: 0
    // The pictures of this switch are on screen.
    property bool showing: false

    readonly property var images: [imageA, imageB]
    readonly property Image front: frontSlot === 1 ? imageB : imageA

    function keyOf(output, rects) {
        return output + " " + JSON.stringify(rects);
    }

    function boxOf(rects) {
        const x = Math.floor(Math.min(...rects.map(r => r.x)));
        const y = Math.floor(Math.min(...rects.map(r => r.y)));
        const w = Math.ceil(Math.max(...rects.map(r => r.x + r.w))) - x;
        const h = Math.ceil(Math.max(...rects.map(r => r.y + r.h))) - y;
        return Qt.rect(x, y, w, h);
    }

    function fileOf(slot) {
        return Sticky.shotDir + "/ghost-" + slot + ".ppm";
    }

    function take(output, rects) {
        if (shot.running || rects.length === 0)
            return;
        const screen = Quickshell.screens.find(s => s.name === output);
        if (!screen)
            return;
        const box = boxOf(rects);
        if (box.width <= 0 || box.height <= 0)
            return;
        takingKey = keyOf(output, rects);
        takingBox = box;
        takingSlot = frontSlot === 0 ? 1 : 0;
        shot.command = ["sh", "-c", 'mkdir -m 700 -p "${2%/*}" && exec grim -t ppm -g "$1" "$2"', "sh", `${screen.x + box.x},${screen.y + box.y} ${box.width}x${box.height}`, fileOf(takingSlot)];
        shot.running = true;
    }

    Process {
        id: shot
        onExited: code => {
            const image = root.images[root.takingSlot];
            if (code !== 0) {
                if (Sticky.ghostShown && !root.showing)
                    Sticky.ghostReady(false);
                return;
            }
            image.key = root.takingKey;
            image.box = root.takingBox;
            image.source = "";
            image.source = "file://" + root.fileOf(root.takingSlot);
        }
    }

    // Each picture costs niri and grim about a tenth of a core at this rate, so pictures are taken
    // only while the keyboard or pointer was used in the last seconds. The press of Super itself
    // wakes this, so a fresh picture is ready by the time the number key follows.
    IdleMonitor {
        id: idle
        enabled: Sticky.emulated
        timeout: 2
        respectInhibitors: false
    }

    // Pictures the sticky windows while they are seen and nothing else covers them.
    Timer {
        interval: root.period
        repeat: true
        running: Sticky.emulated && !Sticky.ghostShown && !idle.isIdle && !Niri.overview && !Lock.active && root.visible
        triggeredOnStart: true
        onTriggered: {
            const shown = Sticky.shownNow();
            if (shown && shown.rects.length > 0)
                root.take(shown.output, shown.rects);
        }
    }

    // A hidden item is left out of ShaderEffectSource too, so the pictures stay visible inside an
    // empty clipped box: nothing of them shows on screen, and the sources below can still draw them.
    Item {
        width: 0
        height: 0
        clip: true

        Image {
            id: imageA
            readonly property int slot: 0
            property string key: ""
            property rect box: Qt.rect(0, 0, 0, 0)
            width: box.width
            height: box.height
            asynchronous: true
            cache: false
            onStatusChanged: root.decoded(imageA)
        }
        Image {
            id: imageB
            readonly property int slot: 1
            property string key: ""
            property rect box: Qt.rect(0, 0, 0, 0)
            width: box.width
            height: box.height
            asynchronous: true
            cache: false
            onStatusChanged: root.decoded(imageB)
        }
    }

    function decoded(image) {
        if (image.status !== Image.Ready || image.source == "")
            return;
        // During a switch only a picture of its places counts, and only until one is shown.
        if (Sticky.ghostShown && (showing || image.key !== keyOf(Sticky.ghostOutput, Sticky.ghostRects)))
            return;
        frontSlot = image.slot;
        frontKey = image.key;
        frontBox = image.box;
        frontTime = Date.now();
        if (Sticky.ghostShown)
            present();
    }

    function present() {
        showing = true;
        frames.ticks = 0;
        frames.running = true;
    }

    // The next frame of this window draws the pictures and hands them to niri before the windows go.
    FrameAnimation {
        id: frames
        property int ticks: 0
        onTriggered: {
            ticks += 1;
            if (ticks >= 1) {
                running = false;
                Sticky.ghostReady(true);
            }
        }
    }

    Repeater {
        model: root.showing && Sticky.ghostShown ? Sticky.ghostRects : []

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
                sourceItem: root.front
                sourceRect: frame.modelData ? Qt.rect(frame.modelData.x - root.frontBox.x, frame.modelData.y - root.frontBox.y, frame.modelData.w, frame.modelData.h) : Qt.rect(0, 0, 0, 0)
                live: false
            }
        }
    }

    Connections {
        target: Sticky
        function onGhostShownChanged() {
            frames.running = false;
            root.showing = false;
            if (!Sticky.ghostShown)
                return;
            const key = root.keyOf(Sticky.ghostOutput, Sticky.ghostRects);
            const age = root.frontSlot >= 0 && root.frontKey === key ? Date.now() - root.frontTime : Infinity;
            if (age < root.freshAge) {
                root.present();
                return;
            }
            // A picture of these places being taken now, usually woken by the press of Super, is
            // shown once decoded. Otherwise a kept one, if any, and only then a new one.
            if (shot.running && root.takingKey === key)
                return;
            if (age < root.maxAge) {
                root.present();
                return;
            }
            if (shot.running)
                retake.restart();
            else
                root.take(Sticky.ghostOutput, Sticky.ghostRects);
        }
    }

    Timer {
        id: retake
        interval: 5
        repeat: true
        onTriggered: {
            if (!Sticky.ghostShown) {
                stop();
                return;
            }
            if (!shot.running) {
                stop();
                root.take(Sticky.ghostOutput, Sticky.ghostRects);
            }
        }
    }
}
