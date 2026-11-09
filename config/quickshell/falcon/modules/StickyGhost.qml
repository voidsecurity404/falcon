import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.services

// Frozen pictures of the sticky windows, in their places, while niri slides the workspaces under
// them. See services/Sticky.qml. Takes no input, and exists only during a switch.
PanelWindow {
    id: root

    visible: Sticky.ghostShown
    screen: Quickshell.screens.find(s => s.name === Sticky.ghostOutput) || Quickshell.screens[0]
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
    property int loadedCount: 0

    onVisibleChanged: loadedCount = 0

    Repeater {
        model: root.visible ? Sticky.ghostRects : []

        ClippingRectangle {
            id: frame
            required property var modelData
            x: modelData ? modelData.x : 0
            y: modelData ? modelData.y : 0
            width: modelData ? modelData.w : 0
            height: modelData ? modelData.h : 0
            radius: root.radius
            color: "transparent"

            // The whole screen picture, placed so only this window's part shows through the clip.
            // sourceClipRect is not used: Qt ignores it for PPM and scales the whole picture.
            Image {
                x: frame.modelData ? -frame.modelData.x : 0
                y: frame.modelData ? -frame.modelData.y : 0
                width: root.width
                height: root.height
                source: Sticky.ghostPath ? "file://" + Sticky.ghostPath : ""
                cache: false
                smooth: false
                property bool counted: false
                function check() {
                    if (counted || status !== Image.Ready)
                        return;
                    counted = true;
                    root.loadedCount += 1;
                    if (root.loadedCount >= Sticky.ghostRects.length)
                        painted.restart();
                }
                onStatusChanged: check()
                Component.onCompleted: check()
            }
        }
    }

    // One frame after the pictures are ready they are on screen, and the windows may go.
    Timer {
        id: painted
        interval: 34
        onTriggered: Sticky.ghostReady()
    }
}
