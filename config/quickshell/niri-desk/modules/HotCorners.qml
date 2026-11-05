import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// Hot corners. Each is a very small layer in a corner of the screen, below fullscreen windows.
// The pointer must stay a moment, and must leave before the corner works again.
Scope {
    id: root

    required property ShellScreen screen

    function run(action) {
        switch (action) {
        case "overview":
            Niri.action("toggle-overview");
            break;
        case "apps":
            Ui.togglePopup("menu");
            break;
        case "dashboard":
            Ui.togglePopup("dashboard");
            break;
        case "control":
            Ui.togglePopup("control");
            break;
        case "note":
            Ui.togglePopup("note");
            break;
        case "wallpapers":
            Ui.togglePopup("wallpapers");
            break;
        case "stages":
            Ui.stagesOn = !Ui.stagesOn;
            break;
        case "lock":
            Quickshell.execDetached(["loginctl", "lock-session"]);
            break;
        }
    }

    Variants {
        model: [
            { key: "topLeft", top: true, left: true },
            { key: "topRight", top: true, left: false },
            { key: "bottomLeft", top: false, left: true },
            { key: "bottomRight", top: false, left: false }
        ]

        delegate: PanelWindow {
            id: corner

            required property var modelData
            readonly property string action: Settings.get("corners." + modelData.key, "none")

            screen: root.screen
            visible: action !== "none" && !Widgets.editMode
            anchors {
                top: modelData.top
                bottom: !modelData.top
                left: modelData.left
                right: !modelData.left
            }
            implicitWidth: 2
            implicitHeight: 2
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "niri-desk-corner"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onContainsMouseChanged: {
                    if (containsMouse)
                        dwell.restart();
                    else
                        dwell.stop();
                }
            }
            Timer {
                id: dwell

                interval: 90
                onTriggered: root.run(corner.action)
            }
        }
    }
}
