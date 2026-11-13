pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Sticky oyna: workspace almashsa ham ko'rinib turadi. Video dars yoki qayd uchun qulay.
// niri has no sticky windows: a window belongs to one workspace and slides with it. niri's own
// switch animation always stays on. While any window is sticky, generated/sticky.kdl binds the
// workspace keys to a line written into a FIFO this service reads, and holds a window rule with
// `opacity 0.0` for floating windows of the sticky apps. Every window that rule matches is told to
// ignore it (toggle-window-rule-opacity), so it looks as usual, and hiding a sticky window for a
// switch is one more toggle: no config reload on the way. A switch goes: StickyGhost shows its
// latest picture of the sticky windows in their places (it pictures them a few times a second
// while nothing happens), on the next frame the windows are hidden, moved to the new workspace and
// it is focused, all over niri's socket in that order, niri slides the workspaces under the still
// pictures, and when the slide is still the windows show again and the pictures go.
// The overview still goes through follow().
//
// niri-falcon (~/Downloads/niri-falcon) has real sticky windows: it keeps them on the shown
// workspace and draws them still during the slide. When niri reports `is_sticky` on its windows
// (`nativeSticky`), all of the above is off: Mod+S sends toggle-window-sticky over the socket, `ids`
// is read from the windows, and the keys, the rules and the pictures are not used.
Singleton {
    id: root

    // niri-falcon reports is_sticky on every window, stock niri on none.
    property bool nativeSticky: false
    // The workaround above is running.
    readonly property bool emulated: active && !nativeSticky

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
    // While true, the windows in `hiddenIds` are made transparent.
    property bool hiding: false
    property var hiddenIds: []
    property bool busy: false
    property var pendingGoal: null
    property int lastWorkspace: -1
    property int previousWorkspace: -1

    // App ids whose rule niri has loaded, and per window whether it was told to ignore that rule.
    // niri forgets the toggle whenever the rule stops matching the window, so it starts hidden
    // each time a rule starts matching it again, and reconcile() shows it.
    property var ruledApps: []
    property var ignoring: ({})

    // How long niri's switch spring (stiffness 800, critically damped) takes to come within a
    // pixel, at the animation speed of the settings. Without animations the switch is instant.
    readonly property int settleTime: {
        if (!Settings.get("windows.animations", true) || GameMode.enabled)
            return 60;
        const speed = Math.max(0.1, Number(Settings.get("windows.animationSpeed", 1)) || 1);
        return Math.round(380 / speed);
    }

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

    // App ids of the sticky windows. The rule matches by app id only, so a title change never
    // makes it stop matching.
    function stickyApps() {
        const apps = [];
        for (const id of ids) {
            const w = Niri.windows[id];
            if (w && w.app_id && apps.indexOf(w.app_id) < 0 && pattern(w.app_id).indexOf("\"#") < 0)
                apps.push(w.app_id);
        }
        return apps.sort();
    }

    function configText(apps) {
        // ids, not `active`: inside onIdsChanged that binding still holds its old value.
        if (ids.length === 0)
            return "";
        // A FIFO costs about a millisecond where `qs ipc` took 45. timeout and -p keep a dead shell
        // from blocking the key or from turning the pipe into a plain file.
        const lines = keys.map(k => "    " + k[0] + " { spawn-sh \"[ -p '" + keyPipe + "' ] && timeout 0.3 sh -c 'echo " + k[1] + " > \\\"$0\\\"' '" + keyPipe + "' || niri msg action " + k[2] + "\"; }");
        let text = "// sticky\nbinds {\n" + lines.join("\n") + "\n}\n";
        for (const app of apps)
            text += "window-rule {\n    match is-floating=true app-id=r#\"" + pattern(app) + "\"#\n    opacity 0.0\n}\n";
        return text;
    }

    // Writes run one at a time. Each loads through niri's socket right after the file is written.
    // niri applies it a moment later and then reports ConfigLoaded, and only then do the toggles
    // for windows the new rules match go out, or they would be lost. `then` runs after that.
    property var writeQueue: []
    property var loadingJob: null
    // Process.running turns true only once the process started, so it cannot guard the queue.
    property bool writing: false

    function writeConfig(then, forced) {
        if (!loaded)
            return;
        // niri-falcon needs no keys and no rules: keep the file empty.
        if (nativeSticky && forced === undefined)
            forced = "";
        const apps = forced !== undefined ? [] : stickyApps();
        const text = forced !== undefined ? forced : configText(apps);
        if (written === text && !then)
            return;
        written = text;
        writeQueue = writeQueue.concat([{
                text: text,
                apps: apps,
                then: then
            }]);
        if (!writing && !loadingJob)
            nextWrite();
    }

    function nextWrite() {
        if (writeQueue.length === 0)
            return;
        const job = writeQueue[0];
        writeQueue = writeQueue.slice(1);
        writing = true;
        writer.job = job;
        writer.command = ["sh", "-c", "printf '%s' \"$1\" > \"$2\"", "sh", job.text, configFile];
        writer.running = true;
    }

    Process {
        id: writer
        property var job: null
        onExited: {
            root.writing = false;
            root.loadingJob = writer.job;
            writer.job = null;
            loadWait.restart();
            Niri.loadConfigFile();
        }
    }

    function loadDone() {
        loadWait.stop();
        const job = loadingJob;
        loadingJob = null;
        if (job)
            ruledApps = job.apps;
        reconcile();
        if (job && job.then)
            job.then();
        nextWrite();
    }

    // In case niri never reports the load.
    Timer {
        id: loadWait
        interval: 1000
        onTriggered: root.loadDone()
    }

    // Brings niri's per-window toggles in line with what should be seen: every window the rule
    // matches ignores it, except the sticky windows hidden for a switch.
    function reconcile() {
        const next = {};
        let changed = false;
        for (const key in Niri.windows) {
            const w = Niri.windows[key];
            const matched = w.is_floating && ruledApps.indexOf(w.app_id) >= 0;
            if (!matched) {
                if (ignoring[w.id])
                    changed = true;
                continue;
            }
            const want = !(hiding && hiddenIds.indexOf(w.id) >= 0);
            const now = !!ignoring[w.id];
            if (want !== now) {
                Niri.toggleRuleOpacity(w.id);
                changed = true;
            }
            if (want)
                next[w.id] = true;
        }
        if (changed || Object.keys(next).length !== Object.keys(ignoring).length)
            ignoring = next;
    }

    Component.onCompleted: {
        const saved = Saved.get("sticky", null);
        if (saved && saved.session === session) {
            ids = saved.ids || [];
        }
        pipPlace = Saved.get("pipPlace", null);
        loaded = true;
        // A shell reloaded in place left its rules loaded and its toggles set, which this one
        // cannot know. Emptying the file first makes niri forget them.
        writeConfig(null, "");
        writeConfig(null);
    }

    // Firefox names the window after the interface language.
    function isPip(title) {
        return /^(Picture-in-Picture|Картинка в картинке)$/i.test(title || "");
    }

    // The last place of a picture-in-picture window, so the next one opens there, also after a
    // reboot. Remembered a moment after it stops moving, not while niri first places it.
    property var pipPlace: null
    property double pipSettledAt: 0

    function pipMoved() {
        if (Date.now() < pipSettledAt)
            return;
        for (const id in Niri.windows) {
            const w = Niri.windows[id];
            const where = w && w.is_floating && w.layout && w.layout.tile_pos_in_workspace_view;
            if (!where || !isPip(w.title))
                continue;
            const size = w.layout.window_size || w.layout.tile_size || [0, 0];
            const next = { x: Math.round(where[0]), y: Math.round(where[1]), w: Math.round(size[0]), h: Math.round(size[1]) };
            const old = pipPlace;
            if (!old || old.x !== next.x || old.y !== next.y || old.w !== next.w || old.h !== next.h) {
                pipPlace = next;
                pipSave.restart();
            }
            return;
        }
    }

    function placePip(id) {
        const p = pipPlace;
        // Ignored while niri and the shell put it in place.
        pipSettledAt = Date.now() + 900;
        if (!p || !(p.w > 40) || !(p.h > 40))
            return;
        Niri.action("set-window-width", "--id", String(id), String(p.w));
        Niri.action("set-window-height", "--id", String(id), String(p.h));
        Niri.action("move-floating-window", "--id", String(id), "-x", String(p.x), "-y", String(p.y));
        // Once more after the app took the new size, which niri may answer by moving it.
        pipAgain.windowId = id;
        pipAgain.restart();
    }

    Timer {
        id: pipAgain

        property int windowId: -1

        interval: 350
        // niri takes the place inside the working area (below the panel's reserved strip) but
        // reports it in the whole view, so the first move lands off by that strip; it is read
        // back and corrected by the difference.
        onTriggered: {
            const p = root.pipPlace;
            const w = Niri.windows[windowId];
            const where = w && w.layout && w.layout.tile_pos_in_workspace_view;
            if (!p || !where)
                return;
            const dx = Math.round(where[0]) - p.x;
            const dy = Math.round(where[1]) - p.y;
            if (dx !== 0 || dy !== 0) {
                root.pipSettledAt = Date.now() + 600;
                Niri.action("move-floating-window", "--id", String(windowId), "-x", String(p.x - dx), "-y", String(p.y - dy));
            }
        }
    }

    Timer {
        id: pipSave

        interval: 800
        onTriggered: Saved.set("pipPlace", root.pipPlace)
    }

    function toggle() {
        const id = Niri.focusedWindowId;
        if (id < 0)
            return;
        if (nativeSticky) {
            const w = Niri.windows[id];
            const was = !!(w && w.is_sticky);
            Niri.toggleSticky(id);
            // Back into its place among the columns. A picture-in-picture window stays floating.
            if (was && !(w && root.isPip(w.title)))
                Niri.action("move-window-to-tiling", "--id", String(id));
            if (was)
                Toasts.show(Tr.t("Sticky off"), Tr.t("The window stays on this workspace"), "check");
            else
                Toasts.show(Tr.t("Sticky on"), Tr.t("The window shows on all workspaces"), "check");
            return;
        }
        if (ids.indexOf(id) >= 0) {
            ids = ids.filter(x => x !== id);
            // Back into its place among the columns. A picture-in-picture window stays floating.
            const w = Niri.windows[id];
            if (!w || !root.isPip(w.title))
                Niri.action("move-window-to-tiling", "--id", String(id));
            Toasts.show(Tr.t("Sticky off"), Tr.t("The window stays on this workspace"), "check");
        } else {
            add(id);
            Niri.action("move-window-to-floating", "--id", String(id));
            Toasts.show(Tr.t("Sticky on"), Tr.t("The window shows on all workspaces"), "check");
        }
    }

    function add(id) {
        if (nativeSticky) {
            const w = Niri.windows[id];
            if (w && !w.is_sticky)
                Niri.toggleSticky(id);
            return;
        }
        if (ids.indexOf(id) < 0)
            ids = ids.concat([id]);
    }

    // niri-falcon: the sticky list is whatever niri says.
    function readNative() {
        const list = [];
        for (const key in Niri.windows)
            if (Niri.windows[key].is_sticky)
                list.push(Niri.windows[key].id);
        list.sort((a, b) => a - b);
        if (JSON.stringify(list) !== JSON.stringify(ids))
            ids = list;
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

    // The sticky windows seen on the focused workspace now, with their places on its output.
    function shownNow() {
        const current = Niri.workspaces.find(w => w.is_focused);
        if (!current)
            return null;
        const shown = ids.map(id => Niri.windows[id]).filter(w => w && w.is_floating && w.layout && w.layout.tile_pos_in_workspace_view && w.workspace_id === current.id);
        return {
            output: current.output || "",
            ids: shown.map(w => w.id),
            rects: shown.map(w => ({
                        x: w.layout.tile_pos_in_workspace_view[0] + w.layout.window_offset_in_tile[0],
                        y: w.layout.tile_pos_in_workspace_view[1] + w.layout.window_offset_in_tile[1],
                        w: w.layout.window_size[0],
                        h: w.layout.window_size[1]
                    }))
        };
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
        if (nativeSticky) {
            Niri.focusWorkspaceId(goal.id);
            return;
        }
        if (busy) {
            pendingGoal = goal;
            // Pressed again during a slide: the pictures are still up, so just go on.
            if (hiding) {
                moveAndFocus(goal);
                settle.restart();
            }
            return;
        }
        const shown = shownNow();
        // Hiding works only through the rule, so a window it does not match just slides.
        const hideable = shown ? shown.ids.filter(id => ignoring[id]) : [];
        if (!shown || hideable.length !== shown.ids.length || shown.ids.length === 0) {
            moveAndFocus(goal);
            return;
        }
        busy = true;
        pendingGoal = goal;
        hiddenIds = shown.ids;
        ghostRects = shown.rects;
        ghostOutput = shown.output;
        // StickyGhost shows its pictures and calls ghostReady() once they are on screen.
        ghostShown = true;
        failsafe.restart();
    }

    // StickyGhost calls this once the pictures are on screen, and with `pictured` false when it
    // has none: then the windows are never hidden, they just slide with the workspace.
    function ghostReady(pictured) {
        failsafe.stop();
        if (!busy || hiding)
            return;
        if (pictured === false) {
            if (pendingGoal)
                moveAndFocus(pendingGoal);
            pendingGoal = null;
            hiddenIds = [];
            ghostShown = false;
            busy = false;
            return;
        }
        hiding = true;
        reconcile();
        if (pendingGoal)
            moveAndFocus(pendingGoal);
        settle.restart();
    }

    function endSwitch() {
        hiding = false;
        reconcile();
        hiddenIds = [];
        unghost.restart();
    }

    // Reads the workspace keys. One cat holds the FIFO open for reading and writing, so it never
    // sees an end, and dies with the shell (pdeathsig): readers left by an earlier shell took keys
    // and dropped them.
    Process {
        id: keyReader
        running: root.loaded && root.emulated
        command: ["sh", "-c", 'mkdir -m 700 -p "$(dirname "$1")" && { [ -p "$1" ] || { rm -f "$1"; mkfifo -m 600 "$1"; }; } && exec setpriv --pdeathsig KILL cat 0<>"$1"', "sh", root.keyPipe]
        stdout: SplitParser {
            onRead: line => root.switchTo(line.trim())
        }
    }

    // If the pictures never report ready, switch anyway rather than not at all, without hiding.
    Timer {
        id: failsafe
        interval: 150
        onTriggered: root.ghostReady(false)
    }

    // niri's switch spring is still by then.
    Timer {
        id: settle
        interval: root.settleTime
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
        if (nativeSticky)
            return;
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
            for (const key in Niri.windows) {
                const isNative = Niri.windows[key].is_sticky !== undefined;
                if (isNative !== root.nativeSticky) {
                    root.nativeSticky = isNative;
                    // Rules and keys of the workaround go once niri does it itself.
                    root.writeConfig(null);
                }
                break;
            }
            if (root.nativeSticky) {
                root.checked = true;
                root.readNative();
                root.pipMoved();
                return;
            }
            if (!root.checked) {
                root.checked = true;
                root.ids = root.ids.filter(id => Niri.windows[id]);
            }
            // A window that turned floating, opened, or closed may start or stop matching the rule.
            root.reconcile();
            root.pipMoved();
            // The app ids are known only once windows are listed.
            root.writeConfig(null);
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
        // Also loads niri made by itself, which change nothing here: reconcile() is then a no-op.
        function onConfigLoaded() {
            if (root.loadingJob)
                root.loadDone();
            else
                root.reconcile();
        }
        function onConfigFailed() {
            if (root.loadingJob)
                root.loadDone();
        }
        function onWindowOpened(window) {
            if (root.isPip(window.title)) {
                root.placePip(window.id);
                root.add(window.id);
            }
        }
        function onWindowGone(id) {
            root.ids = root.ids.filter(x => x !== id);
        }
    }
}
