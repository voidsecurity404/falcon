pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Time Machine: makes backups on time. The script does the work and outlives a shell restart.
Singleton {
    id: root

    readonly property bool enabled: Settings.get("backups.enabled", false)
    readonly property string repo: Settings.get("backups.repo", "")
    readonly property real everyMs: Math.max(1, Number(Settings.get("backups.hours", 1)) || 1) * 3600000
    property var status: ({})
    property string toldError: ""
    readonly property bool running: !!status.running
    readonly property string lastText: status.last ? new Date(status.last * 1000).toLocaleString(Tr.locale, "d MMMM, hh:mm") : Tr.t("Never")

    function refresh() {
        reader.running = true;
    }

    function runNow() {
        if (repo.trim() === "") {
            Toasts.show(Tr.t("Choose where backups go first"), "", "alert");
            return;
        }
        Ui.run("niri-desk-timemachine", "run");
        again.restart();
    }

    function due() {
        if (!enabled || repo.trim() === "" || running || !status.installed || !status.reachable)
            return false;
        if (UPower.onBattery && !Settings.get("backups.onBattery", false))
            return false;
        return Date.now() - (status.last || 0) * 1000 >= everyMs;
    }

    Component.onCompleted: refresh()
    onRepoChanged: refresh()

    // Compares the wall clock, so a laptop that slept makes up for it soon after waking.
    Timer {
        interval: 300000
        repeat: true
        running: true
        onTriggered: {
            root.refresh();
            if (root.due())
                root.runNow();
        }
    }
    Timer {
        id: again

        interval: 1500
        onTriggered: root.refresh()
    }

    Process {
        id: reader

        command: [Ui.binDir + "niri-desk-timemachine", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                let parsed = {};
                try {
                    parsed = JSON.parse(text);
                } catch (e) {
                    return;
                }
                root.status = parsed;
                const error = parsed.lastError || "";
                if (error !== "" && error !== root.toldError && parsed.reachable)
                    Toasts.show(Tr.t("Backup failed"), error, "alert");
                root.toldError = error;
            }
        }
    }
}
