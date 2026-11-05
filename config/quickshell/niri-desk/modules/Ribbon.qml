import QtQuick
import qs.components
import qs.services

// Workspace raqamlari: joriysi rangli, oynasi borlari yorqin, bo'shlari xira.
Rectangle {
    id: root

    property var screenInfo: null

    readonly property string output: screenInfo ? screenInfo.name : ""

    visible: Settings.get("panel.ribbon", true)
    implicitWidth: row.implicitWidth + (Settings.framed ? 18 : 8)
    height: Settings.framed ? 36 : 34
    // In a frame the panel fills its corner, so only the corner facing the desktop stays round.
    readonly property int floatRadius: Settings.framed ? 0 : 11
    topLeftRadius: floatRadius
    bottomLeftRadius: floatRadius
    topRightRadius: Settings.framed ? (Settings.bottom ? 14 : 0) : 11
    bottomRightRadius: Settings.framed ? (Settings.bottom ? 0 : 14) : 11
    gradient: Gradient {
        GradientStop {
            position: 0
            color: Theme.glassTop
        }
        GradientStop {
            position: 1
            // In a frame it has the strip's color, so nothing shows where they meet.
            color: Settings.framed ? Theme.glassTop : Theme.panel
        }
    }
    // In a frame a border would draw a line where the panel meets it.
    border.width: Settings.framed ? 0 : 1
    border.color: Theme.panelEdge

    EdgeCurve {
        visible: Settings.framed
        size: 14
        x: root.width
        y: Settings.bottom ? root.height - size : 0
        flipY: Settings.bottom
        color: Theme.glassTop
    }
    EdgeCurve {
        visible: Settings.framed
        size: 14
        x: 0
        y: Settings.bottom ? -size : root.height
        flipY: Settings.bottom
        color: Theme.glassTop
    }

    // Joriy raqam tagidagi rangli belgi: raqamlar orasida sirpanadi, rangi fon rasmidan.
    Rectangle {
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
        x: chip ? row.x + chip.x + 1 : 0
        y: (root.height - height) / 2
        width: 24
        height: 24
        radius: 8
        color: Theme.accent

        Behavior on x {
            NumberAnimation {
                duration: 340
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.3, 1.4, 0.4, 1, 1, 1]
            }
        }
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 0

        Repeater {
            id: chips

            model: Niri.workspacesOn(root.output)

            delegate: Item {
                id: chip

                required property var modelData

                readonly property bool active: modelData.is_active
                readonly property bool occupied: Niri.hasWindows(modelData.id)

                visible: active || occupied || !Settings.get("panel.hideEmpty", false)
                width: visible ? 26 : 0
                height: 34

                Label {
                    anchors.centerIn: parent
                    text: chip.modelData.idx
                    font.family: Theme.mono
                    size: 14
                    font.weight: chip.active ? Font.Bold : Font.Normal
                    color: chip.active ? Theme.accentText : chip.modelData.is_urgent ? Theme.error : chip.occupied || chipArea.containsMouse ? Theme.text : Qt.alpha(Theme.text, 0.35)

                    Behavior on color {
                        ColorAnimation {
                            duration: 140
                        }
                    }
                }

                MouseArea {
                    id: chipArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Niri.focusWorkspace(chip.modelData.idx)
                }
            }
        }
    }
}
