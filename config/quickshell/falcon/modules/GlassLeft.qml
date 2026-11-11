import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.services

// The left island of the glass bar: the app menu button, the workspaces of this screen and the
// focused window. A workspace with windows is a bright dot, an empty one a faint dot, and the
// current one stretches into a pill with its number.
GlassIsland {
    id: root

    property var screenInfo: null
    readonly property string output: screenInfo ? screenInfo.name : ""
    readonly property bool showWorkspaces: Settings.get("panel.ribbon", true)
    readonly property bool hideEmpty: Settings.get("panel.hideEmpty", false)
    readonly property var focused: {
        const w = Niri.windows[Niri.focusedWindowId];
        return w && w.app_id !== "org.quickshell" ? w : null;
    }
    readonly property int shownDots: showWorkspaces ? Niri.workspacesOn(output).filter(w => w.is_active || Niri.hasWindows(w.id) || !hideEmpty).length : 0
    readonly property var entry: focused ? DesktopEntries.heuristicLookup(focused.app_id) : null

    spacing: 10

    BarButton {
        anchors.verticalCenter: parent.verticalCenter
        objectName: "menu"
        icon: "sparkle"
        lit: Ui.popup === "menu"
        onClicked: Ui.togglePopup("menu")
    }

    BarSeparator {
        visible: root.showWorkspaces
    }

    Row {
        id: dots

        anchors.verticalCenter: parent.verticalCenter
        visible: root.showWorkspaces
        spacing: 0

        Repeater {
            model: Niri.workspacesOn(root.output)

            delegate: Item {
                id: chip

                required property var modelData

                readonly property bool active: modelData.is_active
                readonly property bool occupied: Niri.hasWindows(modelData.id)

                objectName: "dot" + modelData.idx
                visible: active || occupied || !root.hideEmpty
                width: visible ? dot.width + 6 : 0
                height: 30

                Behavior on width {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutCubic
                    }
                }

                Rectangle {
                    id: dot

                    anchors.centerIn: parent
                    width: chip.active ? 28 : 9
                    height: chip.active ? 18 : 9
                    radius: height / 2
                    color: chip.active ? Theme.accent : chip.modelData.is_urgent ? Theme.error : Qt.alpha(Theme.text, chip.occupied ? (area.containsMouse ? 0.85 : 0.62) : (area.containsMouse ? 0.4 : 0.2))

                    Behavior on width {
                        NumberAnimation {
                            duration: 300
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on height {
                        NumberAnimation {
                            duration: 300
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on color {
                        ColorAnimation {
                            duration: 200
                        }
                    }

                    Label {
                        anchors.centerIn: parent
                        text: chip.modelData.idx
                        font.family: Theme.mono
                        size: 11
                        font.weight: Font.Bold
                        color: Theme.accentText
                        opacity: chip.active ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 180
                            }
                        }
                    }
                }

                MouseArea {
                    id: area

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Sticky.active ? Sticky.switchTo(chip.modelData.idx) : Niri.focusWorkspace(chip.modelData.idx)
                }
            }
        }
    }

    BarSeparator {
        visible: !!root.focused
    }

    // The focused window: its app's icon and its title.
    Row {
        anchors.verticalCenter: parent.verticalCenter
        visible: !!root.focused
        spacing: 8

        IconImage {
            anchors.verticalCenter: parent.verticalCenter
            implicitSize: 18
            source: root.entry ? Quickshell.iconPath(root.entry.icon, true) : root.focused ? Quickshell.iconPath(root.focused.app_id, true) : ""
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, 280)
            text: root.focused ? root.focused.title || root.focused.app_id : ""
            elide: Text.ElideRight
            size: 13
            font.weight: Font.Medium
            color: Qt.alpha(Theme.text, 0.88)
        }
        Item {
            width: 2
            height: 1
        }
    }
}
