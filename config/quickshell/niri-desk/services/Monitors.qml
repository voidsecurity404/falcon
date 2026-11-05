pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Reacts to displays being plugged in and out. The decisions are in bin/niri-desk-monitors.
Singleton {
    id: root

    property bool wantConnect: true
    property string lastMonitors: ""

    function step() {
        if (proc.running || !Settings.loaded)
            return;
        proc.command = [Ui.binDir + "niri-desk-monitors", wantConnect ? "connect" : "remember"];
        wantConnect = false;
        proc.running = true;
    }

    function handle(r) {
        if (!r.ok)
            return;
        if (r.forcedOn)
            Toasts.show(Tr.t("The display stays on"), Tr.t("It is the only one left"), "monitor");
        for (const item of r.added) {
            if (item.known)
                Toasts.show(Tr.t("Display connected"), item.title + " · " + Tr.t("settings restored"), "monitor");
            else
                Toasts.show(Tr.t("New display"), item.title + " · " + Tr.t("click to set up"), "monitor", () => {
                    Ui.settingsPage = Ui.pageMonitors;
                    Ui.settingsOpen = true;
                });
            if (Settings.get("monitorConnect", "stay") === "move")
                moveWorkspace(item.name);
        }
        if (r.added.length > 0)
            Quickshell.execDetached([Ui.binDir + "niri-desk-wallpaper", "--reshow"]);
        for (const title of r.removed)
            Toasts.show(Tr.t("Display disconnected"), title, "monitor");
    }

    function moveWorkspace(output) {
        const workspace = Niri.activeWorkspaceOn(Niri.focusedOutput);
        // An empty workspace is not worth showing on the new display.
        if (!workspace || Object.values(Niri.windows).every(w => w.workspace_id !== workspace.id))
            return;
        Quickshell.execDetached(["niri", "msg", "action", "move-workspace-to-monitor", output]);
    }

    // Plugging in can flicker while the display wakes up, so it settles first.
    Connections {
        target: Quickshell
        function onScreensChanged() {
            root.wantConnect = true;
            delay.restart();
        }
    }
    Connections {
        target: Settings
        function onDataChanged() {
            const now = JSON.stringify(Settings.get("monitors", {}));
            if (now !== root.lastMonitors) {
                root.lastMonitors = now;
                delay.restart();
            }
        }
    }

    Timer {
        id: delay

        interval: 1500
        running: Settings.loaded
        onTriggered: root.step()
    }

    Process {
        id: proc

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.handle(JSON.parse(text));
                } catch (e) {}
            }
        }
        onExited: {
            if (root.wantConnect)
                delay.restart();
        }
    }
}
