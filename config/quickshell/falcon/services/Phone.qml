pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The phone through KDE Connect: bin/falcon-phone talks to kdeconnectd over D-Bus and prints
// its state as JSON lines, and takes commands on stdin. Pairing, battery, the phone's
// notifications, SMS, its media player, files and the rest come from there.
Singleton {
    id: root

    property bool installed: true
    property bool running: false
    property string pcName: ""
    property var devices: []
    // The phone the window shows: the one picked, or the first paired and reachable one.
    property string chosenId: ""
    readonly property var device: {
        const pick = devices.find(d => d.id === chosenId);
        return pick || devices.find(d => d.paired && d.reachable) || devices.find(d => d.paired) || devices[0] || null;
    }
    readonly property bool connected: !!device && device.paired && device.reachable
    readonly property var notifications: connected && device.notifications ? device.notifications : []
    readonly property var battery: connected ? device.battery || null : null
    readonly property var media: connected ? device.media || null : null
    readonly property var conversations: connected && device.conversations ? device.conversations : []
    readonly property var pairRequests: devices.filter(d => d.pairRequestedByPeer)
    // The open SMS conversation: {thread, messages}.
    property var thread: null
    property int unread: 0
    // The phone's notification ids with the text last seen for each.
    property var counted: ({})

    function has(plugin) {
        return connected && device.plugins.includes("kdeconnect_" + plugin);
    }

    function send(op, extra) {
        if (!helper.running)
            return;
        const cmd = Object.assign({
            op: op,
            device: device ? device.id : ""
        }, extra || {});
        helper.write(JSON.stringify(cmd) + "\n");
    }

    function ring() {
        send("ring");
        Toasts.show(Tr.t("Ringing the phone"), device ? device.name : "", "bell");
    }
    function ping() {
        send("ping");
    }
    function sendClipboard() {
        send("clipboard");
        Toasts.show(Tr.t("Clipboard sent"), device ? device.name : "", "copy");
    }
    function shareText(text) {
        if (text.trim() !== "")
            send("shareText", {
                text: text
            });
    }
    function shareFiles(paths) {
        if (paths.length > 0)
            send("share", {
                paths: paths
            });
    }
    // A file chooser from zenity; its answer is shared when it comes.
    function pickFiles() {
        picker.running = true;
    }
    function browse() {
        send("mount", {
            tag: "browse"
        });
    }
    function dismiss(ids) {
        send("dismiss", {
            ids: ids
        });
    }
    function reply(replyId, text) {
        send("reply", {
            replyId: replyId,
            text: text
        });
    }
    function mediaAction(action) {
        send("media", {
            action: action
        });
    }
    function openThread(id) {
        thread = {
            thread: id,
            messages: []
        };
        send("openThread", {
            thread: id
        });
    }
    function closeThread() {
        thread = null;
        send("closeThread");
    }

    // Every notification the phone has sent, newest first, kept until the user clears it here
    // (closing it on the phone leaves it). Entries: {id, nid, device, app, title, text, icon,
    // replyId, time, date, active}; `nid` is the phone's id while it is still on the phone.
    property var history: []
    property int nextId: 1
    property bool historyLoaded: false
    onHistoryChanged: saveHistory()
    onUnreadChanged: saveHistory()

    function saveHistory() {
        if (historyLoaded)
            Saved.set("phoneNotifications", {
                history: history,
                unread: unread
            });
    }

    // Removes entries here and closes the ones still on the phone.
    function forget(ids) {
        const gone = history.filter(h => ids.includes(h.id));
        const onPhone = gone.filter(h => h.active && device && h.device === device.id).map(h => h.nid);
        if (onPhone.length > 0)
            dismiss(onPhone);
        history = history.filter(h => !ids.includes(h.id));
        if (history.length === 0)
            unread = 0;
    }

    function signature(n) {
        return [n.app, n.title, n.text].join("\u0001");
    }

    onNotificationsChanged: {
        const dev = device ? device.id : "";
        const now = new Date();
        const fresh = [];
        const next = {};
        for (const n of notifications) {
            const sig = signature(n);
            next[n.id] = sig;
            // New, or the same notification with new text (a chat that got another message).
            if (counted[n.id] !== sig)
                fresh.push(n);
        }
        counted = next;
        if (!historyLoaded)
            return;
        // What the phone already had when it (re)connected only goes into the list if it is not
        // there yet; it arrives up to about 20 seconds after the link is up, and is not news.
        const quiet = !initialised || !connected || settling.running;
        // An entry is on the phone while the phone still shows that id with that text. Ids are
        // handed out again when kdeconnectd restarts, so the text decides, not the id alone.
        let list = history.map(h => {
            const on = h.device === dev && next[h.nid] === signature(h);
            return on === h.active ? h : Object.assign({}, h, {
                active: on
            });
        });
        const added = [];
        for (const n of fresh.slice().reverse()) {
            const sig = signature(n);
            // Already listed under this id (after a shell restart, the saved list has it).
            if (list.some(h => h.device === dev && h.nid === n.id && signature(h) === sig))
                continue;
            // Sent again after a reconnect and already in the list: it is on the phone again.
            const known = quiet ? list.findIndex(h => h.device === dev && !h.active && signature(h) === sig) : -1;
            if (known >= 0) {
                list[known] = Object.assign({}, list[known], {
                    nid: n.id,
                    active: true,
                    replyId: n.replyId
                });
                continue;
            }
            const entry = {
                id: "p" + (nextId++),
                nid: n.id,
                device: dev,
                app: n.app,
                title: n.title || n.app,
                text: n.text,
                icon: n.icon,
                replyId: n.replyId,
                time: Qt.formatTime(now, "hh:mm"),
                date: Qt.formatDate(now, "yyyy-MM-dd"),
                active: true
            };
            list = [entry].concat(list);
            // A notification that came while the list was being caught up is not news either.
            if (!quiet)
                added.push(entry);
        }
        history = list;
        if (quiet || added.length === 0)
            return;
        // Each new one comes in as a card like this computer's, and flies into the bell.
        for (const e of added.slice(-3))
            Toasts.passing(e.title, (e.app && e.title !== e.app ? e.app + " · " : "") + e.text, "phone", e.icon ? "file://" + e.icon : "", () => {
                Ui.notificationsTab = 1;
                Ui.popup = "notifications";
            });
        if (!(Ui.popup === "notifications" && Ui.notificationsTab === 1))
            unread += added.length;
    }
    property bool initialised: false
    Component.onCompleted: {
        const saved = Saved.get("phoneNotifications", null);
        if (saved && Array.isArray(saved.history)) {
            // Nothing is on the phone until it says so again.
            history = saved.history.map(h => Object.assign({}, h, {
                    active: false
                }));
            unread = saved.unread || 0;
            nextId = history.reduce((top, h) => Math.max(top, parseInt(String(h.id).slice(1)) || 0), 0) + 1;
        }
        historyLoaded = true;
    }
    onConnectedChanged: {
        if (connected)
            settling.restart();
    }

    Timer {
        id: settling

        interval: 20000
    }

    Connections {
        target: Ui
        function onPopupChanged() {
            if (Ui.popup === "notifications" && Ui.notificationsTab === 1)
                root.unread = 0;
        }
        function onNotificationsTabChanged() {
            if (Ui.popup === "notifications" && Ui.notificationsTab === 1)
                root.unread = 0;
        }
    }

    Process {
        id: helper

        command: [Ui.binDir + "falcon-phone", "serve"]
        running: Settings.loaded
        stdinEnabled: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                let e;
                try {
                    e = JSON.parse(line);
                } catch (err) {
                    return;
                }
                if (e.type === "state") {
                    root.installed = e.installed;
                    root.running = e.running;
                    root.pcName = e.name || "";
                    root.devices = e.devices || [];
                    if (!root.initialised)
                        Qt.callLater(() => root.initialised = true);
                } else if (e.type === "thread") {
                    if (root.thread && root.thread.thread === e.thread)
                        root.thread = {
                            thread: e.thread,
                            messages: e.messages
                        };
                } else if (e.type === "result") {
                    root.result(e);
                }
            }
        }
        onExited: retry.restart()
    }
    Timer {
        id: retry

        interval: 5000
        onTriggered: helper.running = Settings.loaded
    }

    signal finished(var result)

    function result(e) {
        finished(e);
        if (e.op === "mount") {
            // A file manager on purpose: folders open in the terminal by default here.
            if (e.ok && e.path)
                Quickshell.execDetached(["sh", "-c", 'if command -v nautilus >/dev/null; then exec nautilus --new-window "$1"; else exec xdg-open "$1"; fi', "sh", e.path]);
            else
                Toasts.show(Tr.t("Could not open the phone's files"), e.error || "", "alert");
        } else if (e.op === "share" && e.ok) {
            Toasts.show(Tr.t("Sent to the phone"), Tr.t("{n} files").replace("{n}", e.count), "send");
        } else if (!e.ok && e.op !== "") {
            Toasts.show(Tr.t("Phone"), e.error || Tr.t("It did not work"), "alert");
        }
    }

    Process {
        id: picker

        command: ["zenity", "--file-selection", "--multiple", "--separator=\n", "--title=" + Tr.t("Send to the phone")]
        stdout: StdioCollector {
            onStreamFinished: {
                const paths = text.split("\n").filter(p => p !== "");
                root.shareFiles(paths);
            }
        }
    }
}
