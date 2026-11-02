import QtQuick
import qs.components
import qs.services

// Workspace raqamlari: joriysi rangli, oynasi borlari yorqin, bo'shlari xira.
Rectangle {
    id: root

    property var screenInfo: null

    readonly property string output: screenInfo ? screenInfo.name : ""

    visible: Settings.get("panel.ribbon", true)
    implicitWidth: row.implicitWidth + 8
    height: 34
    radius: 11
    color: Theme.panel

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 0

        Repeater {
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
                    color: chip.active ? Theme.accent : chip.modelData.is_urgent ? Theme.error : chip.occupied || chipArea.containsMouse ? Theme.text : Qt.alpha(Theme.text, 0.35)

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
