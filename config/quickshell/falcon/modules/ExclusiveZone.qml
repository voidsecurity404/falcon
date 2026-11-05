import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// Oynalar panel ostiga kirmasligi uchun joy ajratadi. O'zi ko'rinmaydi va bosilmaydi.
PanelWindow {
    anchors {
        top: !Settings.bottom
        bottom: Settings.bottom
        left: true
        right: true
    }
    implicitHeight: 1
    exclusiveZone: Ui.zen ? 0 : 40
    color: "transparent"
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "falcon-zone"
}
