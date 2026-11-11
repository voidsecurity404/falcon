import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// Oynalar panel ostiga kirmasligi uchun joy ajratadi. O'zi ko'rinmaydi va bosilmaydi.
// The islands float under the top edge (BarLayout's edge gap and height), and niri's gaps add the rest.
PanelWindow {
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 1
    exclusiveZone: Ui.zen ? 0 : BarLayout.reserved
    color: "transparent"
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "falcon-zone"
}
