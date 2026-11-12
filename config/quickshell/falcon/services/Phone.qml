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
    // Notification ids already counted, so a refresh does not count them again.
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

    onNotificationsChanged: {
        // New phone notifications raise the unread count of the phone tab.
        const next = {};
        let fresh = 0;
        for (const n of notifications) {
            next[n.id] = true;
            if (!counted[n.id])
                fresh += 1;
        }
        const before = counted;
        counted = next;
        // What the phone already had when it (re)connected is not news. It sends those a few
        // seconds after the link is up, so the first seconds only set what counts as seen.
        if (!initialised || !connected || settling.running)
            return;
        // A card for each new one; a click opens the bell's Phone tab.
        for (const n of notifications.filter(n => !before[n.id]).slice(0, 3).reverse())
            Toasts.passing(n.title || n.app, (n.title && n.app && n.title !== n.app ? n.app + " · " : "") + n.text, "phone", n.icon ? "file://" + n.icon : "", () => {
                Ui.notificationsTab = 1;
                Ui.popup = "notifications";
            });
        if (Ui.popup === "notifications" && Ui.notificationsTab === 1)
            return;
        unread += fresh;
    }
    property bool initialised: false
    onConnectedChanged: {
        if (connected)
            settling.restart();
    }

    Timer {
        id: settling

        interval: 8000
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
            if (e.ok && e.path)
                Quickshell.execDetached(["xdg-open", e.path]);
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
