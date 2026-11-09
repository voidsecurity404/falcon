pragma Singleton

import QtQuick
import Quickshell

// Sticky oyna: workspace almashsa ham ko'rinib turadi. Video dars yoki qayd uchun qulay.
// niri has no sticky windows, so the window is moved to each workspace that gets focus. Moved after
// the switch, it would ride the old workspace out and pop onto the new one. So while any window is
// sticky, generated/sticky.kdl binds the workspace keys to falcon-sticky-switch, which moves the
// windows first and then switches: they arrive with the workspace sliding in, and niri's switch
// animation stays on. Other ways of switching (overview, Mod+Tab) still go through follow().
Singleton {
    id: root

    // Window ids mean something only within one niri session, so they are saved with its socket.
    readonly property string session: Quickshell.env("NIRI_SOCKET") || ""
    readonly property string configFile: Quickshell.env("HOME") + "/.config/niri/generated/sticky.kdl"
    property var ids: []
    property bool checked: false
    property bool loaded: false
    // What sticky.kdl holds now, null until this shell wrote it.
    property var written: null
    readonly property string script: Quickshell.env("HOME") + "/.local/bin/falcon-sticky-switch"

    readonly property bool active: ids.length > 0

    // The first value of ids also lands here, and it must not overwrite the saved list.
    onIdsChanged: {
        save();
        writeConfig();
    }

    function save() {
        if (loaded)
            Saved.set("sticky", {
                session: session,
                ids: ids
            });
    }

    // The same keys as in cfg/binds.kdl, which this file overrides while it is not empty.
    readonly property var keys: [["Mod+J", "down"], ["Mod+K", "up"], ["Mod+Down", "down"], ["Mod+Up", "up"], ["Mod+WheelScrollDown cooldown-ms=150", "down"], ["Mod+WheelScrollUp cooldown-ms=150", "up"], ["Mod+1", "1"], ["Mod+2", "2"], ["Mod+3", "3"], ["Mod+4", "4"], ["Mod+5", "5"], ["Mod+6", "6"], ["Mod+7", "7"], ["Mod+8", "8"], ["Mod+9", "9"]]

    function configText() {
        if (!active)
            return "";
        const ids = root.ids.map(id => " \"" + id + "\"").join("");
        const lines = keys.map(k => "    " + k[0] + " { spawn \"" + script + "\" \"" + k[1] + "\"" + ids + "; }");
        return "// sticky\nbinds {\n" + lines.join("\n") + "\n}\n";
    }

    function writeConfig() {
        if (!loaded)
            return;
        const text = configText();
        if (written === text)
            return;
        written = text;
        // niri notices the file itself only about half a second later.
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" > \"$2\" && niri msg action load-config-file", "sh", text, configFile]);
    }

    Component.onCompleted: {
        const saved = Saved.get("sticky", null);
        if (saved && saved.session === session) {
            ids = saved.ids || [];
        }
        loaded = true;
        writeConfig();
    }

    function toggle() {
        const id = Niri.focusedWindowId;
        if (id < 0)
            return;
        if (ids.indexOf(id) >= 0) {
            ids = ids.filter(x => x !== id);
            // Back into its place among the columns. A picture-in-picture window stays floating.
            const w = Niri.windows[id];
            if (!w || w.title !== "Picture-in-Picture")
                Niri.action("move-window-to-tiling", "--id", String(id));
            Toasts.show(Tr.t("Sticky off"), Tr.t("The window stays on this workspace"), "check");
        } else {
            add(id);
            Niri.action("move-window-to-floating", "--id", String(id));
            Toasts.show(Tr.t("Sticky on"), Tr.t("The window shows on all workspaces"), "check");
        }
    }

    function add(id) {
        if (ids.indexOf(id) < 0)
            ids = ids.concat([id]);
    }

    // The panel's workspace numbers, so the window comes along the same way as with the keys.
    function switchTo(index) {
        Quickshell.execDetached([script, String(index), ...ids.map(String)]);
    }

    function follow(workspace) {
        for (const id of ids) {
            const w = Niri.windows[id];
            if (w && w.workspace_id !== workspace.id)
                Niri.moveWindowToWorkspaceId(id, workspace.id);
        }
    }

    Connections {
        target: Niri
        // The first window list drops windows that closed while the shell was down.
        function onWindowsChanged() {
            if (root.checked)
                return;
            root.checked = true;
            root.ids = root.ids.filter(id => Niri.windows[id]);
        }
        function onWorkspaceFocused(workspace) {
            root.follow(workspace);
        }
        function onWindowOpened(window) {
            if (window.title === "Picture-in-Picture")
                root.add(window.id);
        }
        function onWindowGone(id) {
            root.ids = root.ids.filter(x => x !== id);
        }
    }
}
