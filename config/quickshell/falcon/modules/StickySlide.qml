import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.services

// The workspace change while a window is sticky. niri's own slide is off then (see
// services/Sticky.qml), so this shows a picture of the old workspace, grabbed straight into
// memory, with holes where the sticky windows are, and lets it drift away and fade while the new
// workspace is already underneath. The sticky windows are never covered, so a video keeps playing.
// Mapped while any window is sticky, so a switch does not wait for the layer to appear.
PanelWindow {
    id: root

    visible: Sticky.active
    screen: Quickshell.screens.find(s => s.name === (Sticky.output || Niri.focusedOutput)) || Quickshell.screens[0]
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "falcon-sticky-slide"
    mask: Region {}

    readonly property real radius: Settings.get("windows.radius", 13)
    // The panel stays where it is, so its strip is left out of the picture.
    readonly property int panelBand: 64
    readonly property bool panelBottom: Settings.get("panel.position", "top") === "bottom"
    property real progress: 0
    property bool showing: false

    Connections {
        target: Sticky
        function onCaptureRequested() {
            root.showing = false;
            slide.stop();
            root.progress = 0;
            if (grab.active && grab.item) {
                grab.item.captureFrame();
                arrived.restart();
            } else {
                // The first view takes its frame when it is made.
                grab.active = true;
            }
        }
    }

    // captureFrame() reports nothing when the frame lands; it takes about one frame.
    Timer {
        id: arrived
        interval: 40
        onTriggered: {
            root.showing = true;
            shown.restart();
        }
    }

    // The picture is drawn by now, so the switch under it is not seen.
    Timer {
        id: shown
        interval: 16
        onTriggered: {
            Sticky.captured();
            slide.restart();
        }
    }

    NumberAnimation {
        id: slide
        target: root
        property: "progress"
        from: 0
        to: 1
        duration: 300
        easing.type: Easing.OutCubic
        onFinished: {
            root.showing = false;
            Sticky.finished();
        }
    }

    Item {
        id: picture
        anchors.fill: parent
        visible: false
        layer.enabled: true

        Item {
            y: -Sticky.direction * root.progress * root.height * 0.07
            width: root.width
            height: root.height

            // Made once and kept: destroying a ScreencopyView and making another crashed
            // Quickshell 0.3.2 in its Wayland dispatch.
            Loader {
                id: grab
                active: false
                sourceComponent: ScreencopyView {
                    width: root.width
                    height: root.height
                    captureSource: root.screen
                    live: false
                    paintCursor: false
                    onHasContentChanged: {
                        if (hasContent) {
                            root.showing = true;
                            shown.restart();
                        }
                    }
                }
            }
        }
    }

    // White where the picture must not cover: the sticky windows and the panel.
    Item {
        id: holes
        anchors.fill: parent
        visible: false
        layer.enabled: true

        Rectangle {
            width: parent.width
            height: root.panelBand
            y: root.panelBottom ? parent.height - root.panelBand : 0
            color: "white"
        }

        Repeater {
            model: Sticky.holes
            Rectangle {
                required property var modelData
                x: modelData.x
                y: modelData.y
                width: modelData.w
                height: modelData.h
                radius: root.radius
                color: "white"
                antialiasing: true
            }
        }
    }

    MultiEffect {
        anchors.fill: parent
        visible: root.showing
        source: picture
        opacity: 1 - root.progress
        maskEnabled: true
        maskInverted: true
        maskSource: holes
        maskThresholdMin: 0.5
        maskSpreadAtMin: 0.1
    }
}
