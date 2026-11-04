import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.components
import qs.services

// Dock: pinned and running apps at the bottom. It hides itself and rises when the pointer touches the bottom edge.
// A click goes to the app's window, or to its next window, or starts the app. A right click pins or unpins it.
PanelWindow {
    id: root

    readonly property bool wanted: Settings.get("dock.enabled", true) && !Ui.zen && Ui.popup !== "menu"
    readonly property int edgeGap: Settings.bottom ? 56 : 8
    readonly property int triggerWidth: 520
    readonly property var pinned: Settings.get("dock.pinned", [])
    property bool hovered: false
    property bool shown: false

    readonly property var running: {
        const groups = {};
        for (const key of Object.keys(Niri.windows)) {
            const w = Niri.windows[key];
            const id = w.app_id || "";
            if (id === "")
                continue;
            (groups[id] = groups[id] || []).push(w);
        }
        return groups;
    }
    // Pinned apps first, in their order, then the other running apps.
    readonly property var items: pinned.concat(Object.keys(running).filter(id => !pinned.includes(id)).sort())

    function open(id) {
        const windows = (running[id] || []).slice().sort((a, b) => a.id - b.id);
        if (windows.length === 0) {
            const entry = DesktopEntries.heuristicLookup(id);
            if (entry)
                entry.execute();
            return;
        }
        const now = windows.findIndex(w => w.is_focused);
        const next = windows[(now + 1) % windows.length];
        Niri.action("focus-window", "--id", String(next.id));
    }

    function togglePin(id) {
        Settings.set("dock.pinned", pinned.includes(id) ? pinned.filter(p => p !== id) : pinned.concat([id]));
    }

    onHoveredChanged: {
        if (hovered) {
            hideTimer.stop();
            shown = true;
        } else {
            hideTimer.restart();
        }
    }
    onWantedChanged: {
        if (!wanted)
            shown = false;
    }

    anchors {
        bottom: true
        left: true
        right: true
    }
    implicitHeight: 96
    visible: Settings.get("dock.enabled", true)
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "niri-desk-dock"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region {
        Region {
            item: root.wanted && !root.shown ? trigger : null
        }
        Region {
            item: root.shown ? body : null
        }
    }
    BackgroundEffect.blurRegion: Region {
        Region {
            item: root.shown || body.y < root.height ? body : null
            radius: 20
        }
    }

    Timer {
        id: hideTimer

        interval: 450
        onTriggered: root.shown = false
    }

    // The thin strip at the bottom edge that wakes the dock.
    MouseArea {
        id: trigger

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: root.triggerWidth
        height: 3
        hoverEnabled: true
        onContainsMouseChanged: root.hovered = containsMouse
    }

    Rectangle {
        id: body

        anchors.horizontalCenter: parent.horizontalCenter
        y: root.shown ? parent.height - height - root.edgeGap : parent.height + 8
        width: icons.implicitWidth + 20
        height: 72
        radius: 20
        color: Theme.panel
        border.width: 1
        border.color: Theme.panelEdge
        visible: y < root.height

        Behavior on y {
            NumberAnimation {
                duration: 300
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]
            }
        }

        HoverHandler {
            onHoveredChanged: root.hovered = hovered
        }

        Row {
            id: icons

            anchors.centerIn: parent
            spacing: 6

            Repeater {
                model: root.items

                delegate: Item {
                    id: slot

                    required property string modelData

                    readonly property var entry: DesktopEntries.heuristicLookup(modelData)
                    readonly property var windows: root.running[modelData] || []
                    readonly property bool focused: windows.some(w => w.is_focused)

                    width: 52
                    height: 56

                    Rectangle {
                        anchors.fill: parent
                        radius: 14
                        color: Qt.alpha(Theme.text, slotArea.containsMouse ? 0.1 : 0)

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }
                    }
                    IconImage {
                        id: picture

                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -2
                        implicitSize: 38
                        source: slot.entry ? Quickshell.iconPath(slot.entry.icon, true) : Quickshell.iconPath(slot.modelData, true)
                        scale: slotArea.pressed ? 0.88 : 1
                        visible: status === Image.Ready

                        Behavior on scale {
                            NumberAnimation {
                                duration: 120
                            }
                        }
                    }
                    Icon {
                        anchors.centerIn: parent
                        visible: picture.status !== Image.Ready
                        name: "windows"
                        size: 26
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 2
                        visible: slot.windows.length > 0
                        width: slot.focused ? 16 : 5
                        height: 4
                        radius: 2
                        color: slot.focused ? Theme.accent : Theme.text
                    }
                    MouseArea {
                        id: slotArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton)
                                root.togglePin(slot.modelData);
                            else
                                root.open(slot.modelData);
                        }
                    }
                }
            }
        }
    }
}
