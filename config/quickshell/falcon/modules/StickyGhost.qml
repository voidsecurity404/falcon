import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.services

// Still pictures of the sticky windows, in their places, while niri slides the workspaces under
// them. See services/Sticky.qml. Mapped while any window is sticky, and keeps a live copy of the
// screen, so a switch needs no capture: the copy is frozen and shown at once. Takes no input.
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

    // Made once and never destroyed: making a new ScreencopyView after destroying one crashed
    // Quickshell 0.3.2. Live only while nothing is shown, so the copy never contains the pictures,
    // and screencopy waits for damage, so a still screen costs nothing.
    // A hidden item is left out of ShaderEffectSource too, so the copy stays visible inside an
    // empty clipped box: nothing of it shows on screen, and the sources below can still draw it.
    Item {
        width: 0
        height: 0
        clip: true

        ScreencopyView {
            id: copy
            width: root.width
            height: root.height
            captureSource: root.screen
            live: false
            paintCursor: false
        }
    }

    // A fresh copy ten times a second while nothing is shown: a live copy cost niri a third of a
    // core during a video. A switch shows the newest one at once, at most 100 ms old.
    Timer {
        interval: 100
        repeat: true
        running: root.visible && !Sticky.ghostShown
        onTriggered: copy.captureFrame()
    }

    Repeater {
        model: Sticky.ghostShown ? Sticky.ghostRects : []

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
                sourceItem: copy
                sourceRect: frame.modelData ? Qt.rect(frame.modelData.x, frame.modelData.y, frame.modelData.w, frame.modelData.h) : Qt.rect(0, 0, 0, 0)
                live: false
            }
        }
    }

    // The pictures are drawn on the next frame, and only then may the windows go.
    Connections {
        target: Sticky
        function onGhostShownChanged() {
            if (Sticky.ghostShown)
                drawn.restart();
        }
    }

    Timer {
        id: drawn
        interval: 17
        onTriggered: Sticky.ghostReady()
    }
}
