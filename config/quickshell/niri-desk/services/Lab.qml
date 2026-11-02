pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Pentest nishoni: portlar ochiqmi va VPN yoqilganmi. Sozlamasi settings.json faylida.
Singleton {
    id: root

    property var ports: []
    property string vpnAddress: ""
    readonly property bool configured: Settings.labTarget.length > 0
    readonly property bool allOpen: ports.length > 0 && ports.every(p => p.open)

    function refresh() {
        if (!configured || checker.running)
            return;
        const list = Settings.labPorts.map(p => String(p.port));
        checker.command = [Ui.binDir + "niri-desk-lab", Settings.labTarget, Settings.vpnInterface, ...list];
        checker.running = true;
    }

    Process {
        id: checker

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    root.vpnAddress = r.vpn || "";
                    root.ports = Settings.labPorts.map(p => ({
                                port: p.port,
                                name: p.name,
                                open: r.open.indexOf(p.port) >= 0
                            }));
                } catch (e) {
                    console.warn("Could not read lab status:", e);
                }
            }
        }
    }

    Timer {
        interval: Ui.popup === "dashboard" ? 5000 : 30000
        repeat: true
        running: root.configured
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Connections {
        target: Settings
        function onLabPortsChanged() {
            root.refresh();
        }
        function onLabTargetChanged() {
            root.refresh();
        }
    }
}
