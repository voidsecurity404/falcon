pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Tungi yorug'lik: wlsunset ishlab turganda ekran iliqroq bo'ladi.
Singleton {
    id: root

    property alias enabled: proc.running

    function toggle() {
        proc.running = !proc.running;
    }

    // Jadval yoqilgan bo'lsa, tungi rejim sessiya boshida o'zi ishga tushadi.
    Connections {
        target: Settings
        function onReadyChanged() {
            if (Settings.ready && Settings.get("nightlight.auto", false))
                proc.running = true;
        }
    }

    Process {
        id: proc

        command: {
            const t = Settings.get("nightlight.temperature", 4000);
            if (Settings.get("nightlight.auto", false))
                return ["wlsunset", "-T", "6500", "-t", String(t), "-S", String(Settings.get("nightlight.to", "07:00")), "-s", String(Settings.get("nightlight.from", "20:00"))];
            return ["wlsunset", "-T", String(t), "-t", String(t - 1)];
        }
    }
}
