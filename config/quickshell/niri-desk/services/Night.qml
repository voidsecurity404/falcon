pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Tungi yorug'lik: wlsunset ishlab turganda ekran iliqroq bo'ladi.
Singleton {
    id: root

    readonly property alias enabled: proc.running
    readonly property bool auto: Settings.get("nightlight.auto", false)
    readonly property bool settingsLoaded: Settings.loaded
    property bool started: false

    function setEnabled(on) {
        proc.running = on;
        Saved.set("night", on);
    }

    function toggle() {
        setEnabled(!proc.running);
    }

    // The saved choice wins. Without one, the schedule decides. The process command
    // reads the settings, so nothing starts before the user's file is in.
    function start() {
        if (started || !settingsLoaded)
            return;
        started = true;
        leftover.running = true;
    }

    onSettingsLoadedChanged: start()
    Component.onCompleted: start()

    onAutoChanged: {
        if (started && auto)
            setEnabled(true);
    }

    // A shell that was killed leaves its wlsunset running, and nothing could stop that one later.
    Process {
        id: leftover

        command: ["pkill", "-x", "wlsunset"]
        onExited: proc.running = Saved.get("night", root.auto)
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
