pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Sticky oyna: workspace almashsa ham ko'rinib turadi. Video dars yoki qayd uchun qulay.
// niri has no sticky windows: a window belongs to one workspace and slides with it. niri's own
// switch animation always stays on. While any window is sticky, generated/sticky.kdl binds the
// workspace keys to a line written into a FIFO this service reads, and a switch goes: StickyGhost
// pictures the sticky windows with grim and shows the pictures in their places, a window rule makes the real windows transparent, they move to the new workspace
// and it is focused over niri's socket, niri slides the workspaces under the still pictures, and
// when the slide ends the rule and the pictures go. The overview still goes through follow().
Singleton {
    id: root

    // Window ids mean something only within one niri session, so they are saved with its socket.
    readonly property string session: Quickshell.env("NIRI_SOCKET") || ""
    readonly property string configFile: Quickshell.env("HOME") + "/.config/niri/generated/sticky.kdl"
    readonly property string shotDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/falcon-sticky"
    property var ids: []
    property bool checked: false
    property bool loaded: false
    // What sticky.kdl holds now, null until this shell wrote it.
    property var written: null

    readonly property bool active: ids.length > 0

    // The still pictures shown by StickyGhost during a switch.
    property bool ghostShown: false
    property string ghostOutput: ""
    property var ghostRects: []
    readonly property string keyPipe: shotDir + "/keys"
    // While true, sticky.kdl also makes the windows in `hidden` fully transparent.
    property bool hiding: false
    property var hidden: []
    property bool busy: false
    property var pendingGoal: null
    property int lastWorkspace: -1
    property int previousWorkspace: -1

    // The first value of ids also lands here, and it must not overwrite the saved list.
    onIdsChanged: {
        save();
        writeConfig(null);
    }

    function save() {
        if (loaded)
            Saved.set("sticky", {
                session: session,
                ids: ids
            });
    }

    // The same keys as in cfg/binds.kdl, which this file overrides while it is not empty. The last
    // field is the plain niri action, used when the shell does not answer.
    readonly property var keys: [["Mod+Tab", "previous", "focus-workspace-previous"], ["Mod+J", "down", "focus-workspace-down"], ["Mod+K", "up", "focus-workspace-up"], ["Mod+Down", "down", "focus-workspace-down"], ["Mod+Up", "up", "focus-workspace-up"], ["Mod+WheelScrollDown cooldown-ms=150", "down", "focus-workspace-down"], ["Mod+WheelScrollUp cooldown-ms=150", "up", "focus-workspace-up"], ["Mod+1", "1", "focus-workspace 1"], ["Mod+2", "2", "focus-workspace 2"], ["Mod+3", "3", "focus-workspace 3"], ["Mod+4", "4", "focus-workspace 4"], ["Mod+5", "5", "focus-workspace 5"], ["Mod+6", "6", "focus-workspace 6"], ["Mod+7", "7", "focus-workspace 7"], ["Mod+8", "8", "focus-workspace 8"], ["Mod+9", "9", "focus-workspace 9"]]

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
        // ids, not `active`: inside onIdsChanged that binding still holds its old value.
        if (ids.length === 0)
            return "";
        // A FIFO costs about a millisecond where `qs ipc` took 45. timeout and -p keep a dead shell
        // from blocking the key or from turning the pipe into a plain file.
        const lines = keys.map(k => "    " + k[0] + " { spawn-sh \"[ -p '" + keyPipe + "' ] && timeout 0.3 sh -c 'echo " + k[1] + " > \\\"$0\\\"' '" + keyPipe + "' || niri msg action " + k[2] + "\"; }");
        let text = "// sticky\nbinds {\n" + lines.join("\n") + "\n}\n";
        if (hiding)
            for (const w of hidden)
                text += hideRule(w);
        return text;
    }

    // Writes run one at a time, and `then` runs once niri has loaded that text.
    property var writeQueue: []

    function writeConfig(then) {
        if (!loaded)
            return;
        const text = configText();
        if (written === text && !then)
            return;
        written = text;
        writeQueue = writeQueue.concat([{
                text: text,
                then: then
            }]);
        if (!writer.running)
            nextWrite();
    }

    function nextWrite() {
        if (writeQueue.length === 0)
            return;
        const job = writeQueue[0];
        writeQueue = writeQueue.slice(1);
        writer.then = job.then;
        writer.command = ["sh", "-c", "printf '%s' \"$1\" > \"$2\" && niri msg action load-config-file", "sh", job.text, configFile];
        writer.running = true;
    }

    Process {
        id: writer
        property var then: null
        onExited: {
            const then = writer.then;
            writer.then = null;
            if (then)
                then();
            root.nextWrite();
        }
    }

    Component.onCompleted: {
        const saved = Saved.get("sticky", null);
        if (saved && saved.session === session) {
            ids = saved.ids || [];
        }
        loaded = true;
        writeConfig(null);
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

    // Moves first, on the same socket, so the windows are on the workspace when it shows.
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
        if (busy) {
            pendingGoal = goal;
            // Pressed again during a slide: the pictures are still up, so just go on.
            if (hiding) {
                moveAndFocus(goal);
                settle.restart();
            }
            return;
        }
        const current = Niri.workspaces.find(w => w.is_focused);
        const shown = ids.map(id => Niri.windows[id]).filter(w => w && w.is_floating && w.layout && w.layout.tile_pos_in_workspace_view && current && w.workspace_id === current.id);
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
        // StickyGhost pictures the windows and calls ghostReady() once the pictures are drawn.
        ghostShown = true;
        failsafe.restart();
    }

    // StickyGhost calls this once the pictures are on screen.
    function ghostReady() {
        failsafe.stop();
        if (!busy || hiding)
            return;
        hiding = true;
        writeConfig(() => {
            if (root.pendingGoal)
                root.moveAndFocus(root.pendingGoal);
            settle.restart();
        });
    }

    function endSwitch() {
        hiding = false;
        writeConfig(() => unghost.restart());
    }

    // Reads the workspace keys. One cat holds the FIFO open for reading and writing, so it never
    // sees an end, and dies with the shell (pdeathsig): readers left by an earlier shell took keys
    // and dropped them.
    Process {
        id: keyReader
        running: root.loaded && root.active
        command: ["sh", "-c", 'mkdir -m 700 -p "$(dirname "$1")" && { [ -p "$1" ] || { rm -f "$1"; mkfifo -m 600 "$1"; }; } && exec setpriv --pdeathsig KILL cat 0<>"$1"', "sh", root.keyPipe]
        stdout: SplitParser {
            onRead: line => root.switchTo(line.trim())
        }
    }

    // If the pictures never report ready, switch anyway rather than not at all.
    Timer {
        id: failsafe
        interval: 150
        onTriggered: root.ghostReady()
    }

    // niri's switch spring (stiffness 800, critically damped) is still by then.
    Timer {
        id: settle
        interval: 420
        onTriggered: root.endSwitch()
    }

    // The real windows are drawn again by now, so the pictures can go without a gap.
    Timer {
        id: unghost
        interval: 50
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
