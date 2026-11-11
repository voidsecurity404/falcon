import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// Oynalar panel ostiga kirmasligi uchun joy ajratadi. O'zi ko'rinmaydi va bosilmaydi.
PanelWindow {
    readonly property bool rail: Settings.layout === "rail"

    // The rail takes room along the left edge, the others along the top or bottom.
    anchors {
        top: rail || !Settings.bottom
        bottom: rail || Settings.bottom
        left: true
        right: !rail
    }
    implicitHeight: 1
    implicitWidth: 1
    exclusiveZone: Ui.zen ? 0 : rail ? 64 : ({
            halo: 44,
            windows: 48,
            macos: 30,
            terminal: 28,
            orbit: 60
        })[Settings.layout] || 40
    color: "transparent"
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "falcon-zone"
}
