pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Dashboard'dagi AI chat. Tarmoq bilan ishlash niri-desk-ai skriptida: u rasmiy SDK'ni ishlatadi.
Singleton {
    id: root

    property var messages: []
    property bool busy: false
    property string pending: ""
    property bool loaded: false

    signal changed

    function load() {
        if (!loaded) {
            loaded = true;
            historyProc.running = true;
        }
    }

    function push(role, text) {
        messages = messages.concat([
            {
                role: role,
                text: text
            }
        ]);
        changed();
    }

    function appendDelta(text) {
        const copy = messages.slice();
        const last = copy[copy.length - 1];
        if (last && last.role === "assistant")
            copy[copy.length - 1] = {
                role: "assistant",
                text: last.text + text
            };
        else
            copy.push({
                role: "assistant",
                text: text
            });
        messages = copy;
        changed();
    }

    function send(text) {
        const clean = text.trim();
        if (clean === "" || busy)
            return false;
        push("user", clean);
        pending = clean;
        busy = true;
        sendProc.running = true;
        return true;
    }

    function stop() {
        if (sendProc.running)
            sendProc.signal(15);
    }

    function clear() {
        stop();
        messages = [];
        clearProc.running = true;
        changed();
    }

    function setKey(key) {
        keyProc.pendingKey = key;
        keyProc.running = true;
    }

    Process {
        id: historyProc

        command: [Ui.binDir + "niri-desk-ai", "history"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    // Tarix o'qilguncha yozilgan xabar yo'qolmasin.
                    root.messages = JSON.parse(text).concat(root.messages);
                    root.changed();
                } catch (e) {
                    root.messages = [];
                }
            }
        }
    }

    Process {
        id: sendProc

        command: [Ui.binDir + "niri-desk-ai", "send"]
        stdinEnabled: true
        onStarted: {
            write(root.pending);
            stdinEnabled = false;
        }
        onExited: {
            root.busy = false;
            stdinEnabled = true;
        }
        stdout: SplitParser {
            onRead: line => {
                try {
                    const m = JSON.parse(line);
                    if (m.t === "delta")
                        root.appendDelta(m.text);
                    else if (m.t === "error")
                        root.push("error", m.message);
                } catch (e) {
                    console.warn("Could not parse AI reply:", line);
                }
            }
        }
    }

    Process {
        id: clearProc

        command: [Ui.binDir + "niri-desk-ai", "clear"]
    }

    Process {
        id: keyProc

        property string pendingKey: ""

        command: [Ui.binDir + "niri-desk-ai", "set-key"]
        stdinEnabled: true
        onStarted: {
            write(pendingKey);
            pendingKey = "";
            stdinEnabled = false;
        }
        onExited: stdinEnabled = true
    }
}
