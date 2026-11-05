pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// niri holati: event stream avval to'liq holatni, keyin faqat o'zgarishlarni yuboradi.
Singleton {
    id: root

    property var workspaces: []
    property var windows: ({})
    property int focusedWindowId: -1
    property string lastAppId: ""
    property string focusedOutput: ""
    property bool overview: false
    property var layoutNames: []
    property int layoutIndex: 0

    readonly property string layoutLabel: {
        const name = (layoutNames[layoutIndex] || "").toLowerCase();
        if (name.startsWith("english"))
            return "EN";
        if (name.startsWith("russian"))
            return "RU";
        if (name.startsWith("uzbek"))
            return "UZ";
        return name.slice(0, 2).toUpperCase();
    }

    signal screenshotTaken(string path)
    signal workspaceFocused(var workspace)
    signal windowOpened(var window)
    signal windowGone(int id)
    signal configFailed

    onFocusedWindowIdChanged: {
        const w = windows[focusedWindowId];
        if (w && w.app_id && w.app_id !== "org.quickshell")
            lastAppId = w.app_id;
    }

    function workspacesOn(output) {
        return workspaces.filter(w => w.output === output).sort((a, b) => a.idx - b.idx);
    }

    function activeWorkspaceOn(output) {
        return workspaces.find(w => w.output === output && w.is_active) || null;
    }

    // Is this workspace fully hidden by one window (fullscreen or maximized)?
    function coveredOn(output, outputWidth, outputHeight) {
        const workspace = activeWorkspaceOn(output);
        if (!workspace)
            return false;
        for (const id in windows) {
            const w = windows[id];
            if (w.workspace_id === workspace.id && !w.is_floating && w.layout && w.layout.tile_size[0] >= outputWidth * 0.95 && w.layout.tile_size[1] >= outputHeight * 0.88)
                return true;
        }
        return false;
    }

    function hasWindows(workspaceId) {
        for (const id in windows) {
            if (windows[id].workspace_id === workspaceId)
                return true;
        }
        return false;
    }

    // Lenta xaritasi uchun: workspace'dagi ustunlar chapdan o'ngga, kengligi ekran ulushida.
    function columnsOf(workspaceId, outputWidth) {
        const columns = {};
        for (const id in windows) {
            const w = windows[id];
            if (w.workspace_id !== workspaceId || w.is_floating)
                continue;
            const pos = w.layout && w.layout.pos_in_scrolling_layout;
            if (!pos)
                continue;
            const width = w.layout.tile_size[0];
            const col = columns[pos[0]] || {
                index: pos[0],
                width: 0,
                focused: false
            };
            col.width = Math.max(col.width, width);
            col.focused = col.focused || w.id === focusedWindowId;
            columns[pos[0]] = col;
        }
        return Object.values(columns).sort((a, b) => a.index - b.index).map(c => ({
                    share: outputWidth > 0 ? c.width / outputWidth : 0.5,
                    focused: c.focused
                }));
    }

    function action(...args) {
        Quickshell.execDetached(["niri", "msg", "action", ...args]);
    }

    // Ko'chirish paytida raqamlar siljishi mumkin, shuning uchun o'zgarmas id ishlatiladi.
    function moveWindowToWorkspaceId(windowId, workspaceId) {
        requests.write(JSON.stringify({
            Action: {
                MoveWindowToWorkspace: {
                    window_id: windowId,
                    reference: {
                        Id: workspaceId
                    },
                    focus: false
                }
            }
        }) + "\n");
        requests.flush();
    }

    function focusWorkspace(index) {
        action("focus-workspace", String(index));
    }

    function nextLayout() {
        action("switch-layout", "next");
    }

    function handle(e) {
        if (e.WorkspacesChanged) {
            workspaces = e.WorkspacesChanged.workspaces;
            const focused = workspaces.find(w => w.is_focused);
            if (focused)
                focusedOutput = focused.output || "";
        } else if (e.WorkspaceActivated) {
            const id = e.WorkspaceActivated.id;
            const target = workspaces.find(w => w.id === id);
            if (!target)
                return;
            workspaces = workspaces.map(w => {
                const copy = Object.assign({}, w);
                if (w.output === target.output)
                    copy.is_active = w.id === id;
                if (e.WorkspaceActivated.focused)
                    copy.is_focused = w.id === id;
                return copy;
            });
            if (e.WorkspaceActivated.focused) {
                focusedOutput = target.output || "";
                workspaceFocused(target);
            }
        } else if (e.WindowsChanged) {
            const next = {};
            focusedWindowId = -1;
            for (const w of e.WindowsChanged.windows) {
                next[w.id] = w;
                if (w.is_focused)
                    focusedWindowId = w.id;
            }
            windows = next;
        } else if (e.WindowOpenedOrChanged) {
            const w = e.WindowOpenedOrChanged.window;
            const isNew = !windows[w.id];
            const next = Object.assign({}, windows);
            next[w.id] = w;
            windows = next;
            if (isNew)
                windowOpened(w);
            if (w.is_focused)
                focusedWindowId = w.id;
        } else if (e.WindowClosed) {
            const next = Object.assign({}, windows);
            delete next[e.WindowClosed.id];
            windows = next;
            if (focusedWindowId === e.WindowClosed.id)
                focusedWindowId = -1;
            windowGone(e.WindowClosed.id);
        } else if (e.WindowFocusChanged) {
            const id = e.WindowFocusChanged.id;
            focusedWindowId = id === null || id === undefined ? -1 : id;
        } else if (e.WindowFocusTimestampChanged) {
            const change = e.WindowFocusTimestampChanged;
            if (windows[change.id]) {
                const next = Object.assign({}, windows);
                next[change.id] = Object.assign({}, next[change.id], {
                    focus_timestamp: change.focus_timestamp
                });
                windows = next;
            }
        } else if (e.WindowLayoutsChanged) {
            const next = Object.assign({}, windows);
            for (const change of e.WindowLayoutsChanged.changes) {
                if (next[change[0]])
                    next[change[0]] = Object.assign({}, next[change[0]], {
                        layout: change[1]
                    });
            }
            windows = next;
        } else if (e.KeyboardLayoutsChanged) {
            layoutNames = e.KeyboardLayoutsChanged.keyboard_layouts.names;
            layoutIndex = e.KeyboardLayoutsChanged.keyboard_layouts.current_idx;
        } else if (e.KeyboardLayoutSwitched) {
            layoutIndex = e.KeyboardLayoutSwitched.idx;
        } else if (e.OverviewOpenedOrClosed) {
            overview = e.OverviewOpenedOrClosed.is_open;
        } else if (e.ScreenshotCaptured) {
            screenshotTaken(e.ScreenshotCaptured.path || "");
        } else if (e.ConfigLoaded && e.ConfigLoaded.failed) {
            configFailed();
        }
    }

    Socket {
        id: events

        path: Quickshell.env("NIRI_SOCKET")
        connected: true
        onConnectedChanged: {
            if (connected) {
                write('"EventStream"\n');
                flush();
            }
        }

        parser: SplitParser {
            onRead: line => {
                try {
                    root.handle(JSON.parse(line));
                } catch (e) {
                    console.warn("Could not parse niri event:", e);
                }
            }
        }
    }

    Socket {
        id: requests

        path: Quickshell.env("NIRI_SOCKET")
        connected: true

        parser: SplitParser {
            onRead: line => {
                if (line.indexOf('"Err"') >= 0)
                    console.warn("niri request rejected:", line);
            }
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: !events.connected || !requests.connected
        onTriggered: {
            events.connected = true;
            requests.connected = true;
        }
    }
}
