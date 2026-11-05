import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// Oynalar panel va ramka ostiga kirmasligi uchun joy ajratadi. O'zi ko'rinmaydi va bosilmaydi.
// One window per screen edge: the panel's edge reserves the bar too, the others only the frame.
PanelWindow {
    id: root

    property string edge: "top"
    readonly property bool panelEdge: edge === (Settings.bottom ? "bottom" : "top")

    anchors {
        top: edge !== "bottom"
        bottom: edge !== "top"
        left: edge !== "right"
        right: edge !== "left"
    }
    implicitHeight: 1
    implicitWidth: 1
    exclusiveZone: Ui.zen ? 0 : Ui.frameTarget + (panelEdge ? 40 : 0)
    color: "transparent"
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "niri-desk-zone"
}
