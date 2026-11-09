pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Sticky oyna: workspace almashsa ham ko'rinib turadi. Video dars yoki qayd uchun qulay.
// niri has no sticky windows: a window belongs to one workspace and slides with it. So while any
// window is sticky, generated/sticky.kdl binds the workspace keys to `desk stickySwitch`, and a
// switch goes: grim takes the screen, StickyGhost shows the sticky windows' pictures in their
// places, a window rule makes the real ones fully transparent, falcon-sticky-switch moves them to
// the new workspace and focuses it, niri slides the workspaces under the still pictures, and when
// the slide ends the rule goes and the pictures with it. Other ways of switching (the overview)
// still go through follow(), where the window rides out and pops in.
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
    readonly property string shotDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/falcon-sticky"

    // The frozen pictures shown by StickyGhost during a switch.
    property bool ghostShown: false
    property string ghostPath: ""
    property string ghostOutput: ""
    property var ghostRects: []
    // While true, sticky.kdl also hides the windows in ghostRects.
    property bool hiding: false
    property var hidden: []
    property bool busy: false
    property int shotCount: 0
    property var pendingGoal: null
    property int lastWorkspace: -1
    property int previousWorkspace: -1

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
    readonly property var keys: [["Mod+Tab", "previous"], ["Mod+J", "down"], ["Mod+K", "up"], ["Mod+Down", "down"], ["Mod+Up", "up"], ["Mod+WheelScrollDown cooldown-ms=150", "down"], ["Mod+WheelScrollUp cooldown-ms=150", "up"], ["Mod+1", "1"], ["Mod+2", "2"], ["Mod+3", "3"], ["Mod+4", "4"], ["Mod+5", "5"], ["Mod+6", "6"], ["Mod+7", "7"], ["Mod+8", "8"], ["Mod+9", "9"]]

    function pattern(text) {
        return "^" + text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "$";
    }

    // niri rules cannot match a window id, so a hidden window is matched by app id and title.
    function hideRule(w) {
        let match = "match is-floating=true app-id=r#\"" + pattern(w.app_id || "") + "\"#";
        const title = pattern(w.title || "");
        if (title.indexOf("\"#") < 0)
            match += " title=r#\"" + title + "\"#";
        return "window-rule {\n    " + match + "\n    opacity 0.0\n}\n";
    }

    function configText() {
        if (!active)
            return "";
        const lines = keys.map(k => "    " + k[0] + " { spawn \"qs\" \"-c\" \"falcon\" \"ipc\" \"call\" \"desk\" \"stickySwitch\" \"" + k[1] + "\"; }");
        let text = "// sticky\nbinds {\n" + lines.join("\n") + "\n}\n";
        if (hiding)
            for (const w of hidden)
                text += hideRule(w);
        return text;
    }

    // `then` runs after niri has loaded the file, with the switch script as $3.
    function writeConfig(then) {
        if (!loaded)
            return;
        const text = configText();
        if (written === text && !then)
            return;
        written = text;
        const after = then ? " && " + then : "";
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" > \"$2\" && niri msg action load-config-file" + after, "sh", text, configFile, script]);
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

    function moveAndFocus(goal) {
        Quickshell.execDetached([script, "id=" + goal.id, ...ids.map(String)]);
    }

    // Keys, and the panel's workspace numbers, while a window is sticky.
    function switchTo(target) {
        const goal = goalFor(String(target));
        if (!goal)
            return;
        if (busy) {
            // Pressed again during a slide: the pictures are still up, so just go on.
            pendingGoal = goal;
            if (hiding) {
                moveAndFocus(goal);
                settle.restart();
            }
            return;
        }
        const current = Niri.workspaces.find(w => w.is_focused);
        const shown = ids.map(id => Niri.windows[id]).filter(w => w && w.is_floating && w.layout && current && w.workspace_id === current.id);
        if (shown.length === 0) {
            moveAndFocus(goal);
            return;
        }
        busy = true;
        pendingGoal = goal;
        hidden = shown.map(w => ({
                    app_id: w.app_id,
                    title: w.title
                }));
        ghostRects = shown.map(w => ({
                    x: w.layout.tile_pos_in_workspace_view[0] + w.layout.window_offset_in_tile[0],
                    y: w.layout.tile_pos_in_workspace_view[1] + w.layout.window_offset_in_tile[1],
                    w: w.layout.window_size[0],
                    h: w.layout.window_size[1]
                }));
        ghostOutput = current.output;
        shotCount += 1;
        shooter.path = shotDir + "/" + shotCount + ".ppm";
        shooter.command = ["sh", "-c", 'mkdir -m 700 -p "$1" && rm -f "$1"/*.ppm && grim -t ppm -o "$2" "$3"', "sh", shotDir, ghostOutput, shooter.path];
        shooter.running = true;
    }

    // StickyGhost calls this once the pictures are on screen.
    function ghostReady() {
        if (!busy || hiding)
            return;
        hiding = true;
        const goal = pendingGoal;
        writeConfig("exec \"$3\" id=" + goal.id + " " + ids.join(" "));
        settle.restart();
    }

    function endSwitch() {
        hiding = false;
        writeConfig();
        unghost.restart();
    }

    Process {
        id: shooter
        property string path: ""
        onExited: code => {
            if (code === 0) {
                root.ghostPath = path;
                root.ghostShown = true;
                failsafe.restart();
            } else {
                root.busy = false;
                root.moveAndFocus(root.pendingGoal);
            }
        }
    }

    // If the pictures never report ready, switch anyway rather than not at all.
    Timer {
        id: failsafe
        interval: 300
        onTriggered: root.ghostReady()
    }

    // niri's switch spring (stiffness 800, critically damped) is visually still after this.
    Timer {
        id: settle
        interval: 480
        onTriggered: root.endSwitch()
    }

    // The real windows are drawn again by now, so the pictures can go without a gap.
    Timer {
        id: unghost
        interval: 90
        onTriggered: {
            root.ghostShown = false;
            root.busy = false;
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
