pragma Singleton

import QtQuick
import Quickshell

// Sticky oyna: workspace almashsa ham ko'rinib turadi. Video dars yoki qayd uchun qulay.
// niri has no sticky windows, so the window is moved to each workspace that gets focus. A window
// belongs to its workspace and would slide away and back with it, so while any window is sticky
// generated/sticky.kdl turns the workspace switch animation off, and the window seems to stay put.
Singleton {
    id: root

    // Window ids mean something only within one niri session, so they are saved with its socket.
    readonly property string session: Quickshell.env("NIRI_SOCKET") || ""
    readonly property string configFile: Quickshell.env("HOME") + "/.config/niri/generated/sticky.kdl"
    property var ids: []
    // Windows that were tiled before they became sticky, so turning it off puts them back.
    property var tiled: []
    property bool checked: false
    property bool loaded: false
    // What sticky.kdl holds now: -1 not written by this shell yet, 0 animation on, 1 off.
    property int written: -1

    readonly property bool active: ids.length > 0

    // The first value of ids also lands here, and it must not overwrite the saved list.
    onIdsChanged: save()
    onTiledChanged: save()
    onActiveChanged: writeConfig()

    function save() {
        if (loaded)
            Saved.set("sticky", {
                session: session,
                ids: ids,
                tiled: tiled
            });
    }

    function writeConfig() {
        if (!loaded || written === (active ? 1 : 0))
            return;
        written = active ? 1 : 0;
        const text = active ? "// sticky\nanimations {\n    workspace-switch {\n        off\n    }\n}\n" : "";
        // niri notices the file itself only about half a second later.
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" > \"$2\" && niri msg action load-config-file", "sh", text, configFile]);
    }

    Component.onCompleted: {
        const saved = Saved.get("sticky", null);
        if (saved && saved.session === session) {
            ids = saved.ids || [];
            tiled = saved.tiled || [];
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
            if (tiled.indexOf(id) >= 0) {
                tiled = tiled.filter(x => x !== id);
                Niri.action("move-window-to-tiling", "--id", String(id));
            }
            Toasts.show(Tr.t("Sticky off"), Tr.t("The window stays on this workspace"), "check");
        } else {
            const w = Niri.windows[id];
            if (w && !w.is_floating)
                tiled = tiled.concat([id]);
            add(id);
            Niri.action("move-window-to-floating", "--id", String(id));
            Toasts.show(Tr.t("Sticky on"), Tr.t("The window shows on all workspaces"), "check");
        }
    }

    function add(id) {
        if (ids.indexOf(id) < 0)
            ids = ids.concat([id]);
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
            root.tiled = root.tiled.filter(id => root.ids.indexOf(id) >= 0);
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
            root.tiled = root.tiled.filter(x => x !== id);
        }
    }
}
