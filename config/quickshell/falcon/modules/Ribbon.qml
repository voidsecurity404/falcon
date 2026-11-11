import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.services

// Workspace raqamlari: joriysi rangli, oynasi borlari yorqin, bo'shlari xira.
// panel.workspaces chooses how they look: numbers, dots, pills, or the icons of their apps.
Rectangle {
    id: root

    property var screenInfo: null
    // A copy drawn in the settings preview takes no clicks.
    property bool preview: false

    readonly property string output: screenInfo ? screenInfo.name : ""
    readonly property string look: Settings.get("panel.workspaces", "numbers")

    // The apps with windows on a workspace, each once, in the order they were opened.
    function appsOn(workspaceId) {
        const all = Niri.windows;
        const list = [];
        for (const id in all) {
            const w = all[id];
            if (w.workspace_id === workspaceId && w.app_id && list.indexOf(w.app_id) < 0)
                list.push(w.app_id);
        }
        return list.slice(0, 3);
    }

    visible: Settings.get("panel.ribbon", true)
    implicitWidth: row.implicitWidth + (Settings.hug ? 26 : 8)
    height: Settings.hug ? 45 : 34
    // In the corner only the free corner stays round. The border on the screen edges lies off the screen.
    topLeftRadius: Settings.hug ? 0 : 11
    bottomLeftRadius: Settings.hug ? 0 : 11
    topRightRadius: Settings.hug ? (Settings.bottom ? 18 : 0) : 11
    bottomRightRadius: Settings.hug ? (Settings.bottom ? 0 : 18) : 11
    gradient: Gradient {
        GradientStop {
            position: 0
            color: Theme.glassTop
        }
        GradientStop {
            position: 1
            color: Theme.panel
        }
    }
    border.width: 1
    border.color: Theme.panelEdge

    Behavior on implicitWidth {
        enabled: !root.preview
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutCubic
        }
    }

    EdgeCurve {
        visible: Settings.hug
        x: root.width
        y: Settings.bottom ? 44 - size : 1
        flipY: Settings.bottom
        color: Settings.bottom ? Theme.panel : Theme.glassTop
    }
    EdgeCurve {
        visible: Settings.hug
        x: 1
        y: Settings.bottom ? -size : root.height
        flipY: Settings.bottom
        color: Settings.bottom ? Theme.glassTop : Theme.panel
    }

    // Joriy workspace belgisi: raqamlar orasida sirpanadi, rangi fon rasmidan. Its shape follows the look.
    Rectangle {
        id: marker

        readonly property var chip: {
            const count = chips.count;
            for (let i = 0; i < count; i++) {
                const item = chips.itemAt(i);
                if (item && item.active)
                    return item;
            }
            return null;
        }

        visible: !!chip
        x: chip ? row.x + chip.x + (chip.width - width) / 2 : 0
        y: (root.height - height) / 2
        width: !chip ? 0 : root.look === "numbers" ? 24 : root.look === "dots" ? chip.width - 6 : chip.width - 4
        height: root.look === "dots" ? 8 : root.look === "apps" ? 28 : 24
        radius: root.look === "numbers" ? 8 : root.look === "apps" ? 10 : height / 2
        color: root.look === "apps" ? Qt.alpha(Theme.accent, 0.28) : Theme.accent
        border.width: root.look === "apps" ? 1 : 0
        border.color: Theme.accent

        Behavior on x {
            NumberAnimation {
                duration: 340
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.3, 1.4, 0.4, 1, 1, 1]
            }
        }
        Behavior on width {
            NumberAnimation {
                duration: 340
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.3, 1.3, 0.4, 1, 1, 1]
            }
        }
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: root.look === "pills" ? 4 : 0

        Repeater {
            id: chips

            model: Niri.workspacesOn(root.output)

            delegate: Item {
                id: chip

                required property var modelData

                readonly property bool active: modelData.is_active
                readonly property bool occupied: Niri.hasWindows(modelData.id)
                readonly property var apps: root.look === "apps" ? root.appsOn(modelData.id) : []
                readonly property color tone: active ? Theme.accentText : chip.modelData.is_urgent ? Theme.error : chip.occupied || chipArea.containsMouse ? Theme.text : Qt.alpha(Theme.text, 0.35)

                visible: active || occupied || !Settings.get("panel.hideEmpty", false)
                width: !visible ? 0 : root.look === "dots" ? (active ? 34 : 16) : root.look === "pills" ? (active ? 44 : 30) : root.look === "apps" ? Math.max(30, apps.length * 21 + 12) : 26
                height: 34

                Behavior on width {
                    enabled: !root.preview
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutCubic
                    }
                }

                // Numbers.
                Label {
                    anchors.centerIn: parent
                    visible: root.look === "numbers" || (root.look === "apps" && chip.apps.length === 0)
                    text: chip.modelData.idx
                    font.family: Theme.mono
                    size: 14
                    font.weight: chip.active ? Font.Bold : Font.Normal
                    color: root.look === "apps" && !chip.active ? Qt.alpha(Theme.text, chipArea.containsMouse ? 0.8 : 0.4) : chip.tone

                    Behavior on color {
                        ColorAnimation {
                            duration: 140
                        }
                    }
                }

                // Dots: a full one where windows are, a ring where there are none.
                Rectangle {
                    anchors.centerIn: parent
                    visible: root.look === "dots" && !chip.active
                    width: 8
                    height: 8
                    radius: 4
                    color: chip.modelData.is_urgent ? Theme.error : chip.occupied ? Qt.alpha(Theme.text, chipArea.containsMouse ? 1 : 0.8) : "transparent"
                    border.width: chip.occupied ? 0 : 1.5
                    border.color: Qt.alpha(Theme.text, chipArea.containsMouse ? 0.8 : 0.4)
                }

                // Pills: a soft capsule under each number.
                Rectangle {
                    anchors.centerIn: parent
                    visible: root.look === "pills" && !chip.active
                    width: parent.width - 4
                    height: 24
                    radius: 12
                    color: Qt.alpha(Theme.text, chipArea.containsMouse ? 0.16 : chip.occupied ? 0.1 : 0.04)

                    Behavior on color {
                        ColorAnimation {
                            duration: 140
                        }
                    }
                }
                Label {
                    anchors.centerIn: parent
                    visible: root.look === "pills"
                    text: chip.modelData.idx
                    font.family: Theme.mono
                    size: 12
                    font.weight: chip.active ? Font.Bold : Font.Medium
                    color: chip.tone
                }

                // Apps: the icons of the windows on it, up to three.
                Row {
                    anchors.centerIn: parent
                    visible: root.look === "apps" && chip.apps.length > 0
                    spacing: 5
                    opacity: chip.active || chipArea.containsMouse ? 1 : 0.6

                    Repeater {
                        model: chip.apps

                        delegate: IconImage {
                            required property string modelData
                            readonly property var entry: DesktopEntries.heuristicLookup(modelData)

                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: 16
                            source: entry ? Quickshell.iconPath(entry.icon, true) : Quickshell.iconPath(modelData, true)
                        }
                    }
                }

                MouseArea {
                    id: chipArea

                    anchors.fill: parent
                    enabled: !root.preview
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Sticky.active ? Sticky.switchTo(chip.modelData.idx) : Niri.focusWorkspace(chip.modelData.idx)
                }
            }
        }
    }
}
