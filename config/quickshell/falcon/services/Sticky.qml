pragma Singleton

import QtQuick
import Quickshell

// Sticky oyna: workspace almashsa ham ko'rinib turadi. Video dars yoki qayd uchun qulay.
// niri has no sticky windows: a window belongs to one workspace, and niri's switch slides it with
// the workspace. A still picture over it froze the video, so while any window is sticky,
// generated/sticky.kdl turns niri's switch animation off and binds the workspace keys to
// `desk stickySwitch`. A switch then goes: StickySlide grabs the screen into memory, shows that
// picture with holes where the sticky windows are, the windows move to the new workspace and it is
// focused at once, and the picture of the old workspace drifts away and fades. The sticky windows
// stay live and never move. The overview still goes through follow().
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

    readonly property bool active: ids.length > 0

    // A switch in progress, read by StickySlide.
    property bool switching: false
    property var pendingGoal: null
    // 1 when the new workspace is below the old one, -1 above.
    property int direction: 1
    property var holes: []
    property string output: ""
    property int lastWorkspace: -1
    property int previousWorkspace: -1

    // StickySlide takes a picture on this and calls captured() once it is on screen.
    signal captureRequested

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

    // The same keys as in cfg/binds.kdl, which this file overrides while it is not empty. The last
    // field is the plain niri action, used if the shell does not answer.
    readonly property var keys: [["Mod+Tab", "previous", "focus-workspace-previous"], ["Mod+J", "down", "focus-workspace-down"], ["Mod+K", "up", "focus-workspace-up"], ["Mod+Down", "down", "focus-workspace-down"], ["Mod+Up", "up", "focus-workspace-up"], ["Mod+WheelScrollDown cooldown-ms=150", "down", "focus-workspace-down"], ["Mod+WheelScrollUp cooldown-ms=150", "up", "focus-workspace-up"], ["Mod+1", "1", "focus-workspace 1"], ["Mod+2", "2", "focus-workspace 2"], ["Mod+3", "3", "focus-workspace 3"], ["Mod+4", "4", "focus-workspace 4"], ["Mod+5", "5", "focus-workspace 5"], ["Mod+6", "6", "focus-workspace 6"], ["Mod+7", "7", "focus-workspace 7"], ["Mod+8", "8", "focus-workspace 8"], ["Mod+9", "9", "focus-workspace 9"]]

    function configText() {
        if (!active)
            return "";
        const lines = keys.map(k => "    " + k[0] + " { spawn-sh \"qs -c falcon ipc call desk stickySwitch " + k[1] + " || niri msg action " + k[2] + "\"; }");
        return "// sticky\nanimations {\n    workspace-switch {\n        off\n    }\n}\nbinds {\n" + lines.join("\n") + "\n}\n";
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

    function goalFor(target) {
        const current = Niri.workspaces.find(w => w.is_focused);
        if (!current)
            return null;
        const mine = Niri.workspacesOn(current.output);
        let goal = null;
        if (target === "up")
            goal = mine.filter(w => w.idx < current.idx).pop() || null;
        else if (target === "down")
            goal = mine.find(w => w.idx > current.idx) || null;
        else if (target === "previous")
            goal = Niri.workspaces.find(w => w.id === previousWorkspace) || null;
        else if (/^\d+$/.test(target))
            goal = mine.find(w => w.idx === Number(target)) || mine[mine.length - 1] || null;
        return goal && goal.id !== current.id ? goal : null;
    }

    // Moves first, on the same socket, so the windows are there when the workspace shows.
    function moveAndFocus(goal) {
        for (const id of ids) {
            const w = Niri.windows[id];
            if (w && w.workspace_id !== goal.id)
                Niri.moveWindowToWorkspaceId(id, goal.id);
        }
        Niri.focusWorkspaceId(goal.id);
    }

    // Keys, and the panel's workspace numbers, while a window is sticky.
    function switchTo(target) {
        const goal = goalFor(String(target));
        if (!goal)
            return;
        // Pressed again while the old picture still fades: go on at once.
        if (switching) {
            moveAndFocus(goal);
            return;
        }
        const current = Niri.workspaces.find(w => w.is_focused);
        holes = ids.map(id => Niri.windows[id]).filter(w => w && w.is_floating && w.layout && w.layout.tile_pos_in_workspace_view && w.workspace_id === current.id).map(w => ({
                    x: w.layout.tile_pos_in_workspace_view[0] + w.layout.window_offset_in_tile[0],
                    y: w.layout.tile_pos_in_workspace_view[1] + w.layout.window_offset_in_tile[1],
                    w: w.layout.window_size[0],
                    h: w.layout.window_size[1]
                }));
        direction = goal.idx > current.idx ? 1 : -1;
        output = current.output;
        pendingGoal = goal;
        switching = true;
        failsafe.restart();
        captureRequested();
    }

    // StickySlide shows the picture of the old workspace, so the switch can happen under it.
    function captured() {
        failsafe.stop();
        if (pendingGoal)
            moveAndFocus(pendingGoal);
        pendingGoal = null;
    }

    function finished() {
        switching = false;
    }

    // If no picture comes, switch anyway rather than not at all.
    Timer {
        id: failsafe
        interval: 250
        onTriggered: {
            root.captured();
            root.switching = false;
        }
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
        function onWorkspacesChanged() {
            if (root.lastWorkspace < 0) {
                const focused = Niri.workspaces.find(w => w.is_focused);
                if (focused)
                    root.lastWorkspace = focused.id;
            }
        }
        function onWorkspaceFocused(workspace) {
            if (root.lastWorkspace !== workspace.id) {
                root.previousWorkspace = root.lastWorkspace;
                root.lastWorkspace = workspace.id;
            }
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
