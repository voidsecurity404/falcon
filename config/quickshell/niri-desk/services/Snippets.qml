pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Text snippets: a short name and the text it stands for, typed into the window in focus.
Singleton {
    id: root

    // [{trigger, text}]
    property var items: []

    function load(content) {
        try {
            const parsed = JSON.parse(content || "[]");
            items = Array.isArray(parsed) ? parsed.filter(s => s && typeof s.trigger === "string" && typeof s.text === "string") : [];
        } catch (e) {
            items = [];
        }
    }

    function store(next) {
        items = next;
        file.setText(JSON.stringify(next, null, 2) + "\n");
    }

    function add() {
        store(items.concat([{ trigger: "", text: "" }]));
    }

    function change(index, key, value) {
        const next = JSON.parse(JSON.stringify(items));
        if (!next[index] || next[index][key] === value)
            return;
        next[index][key] = value;
        store(next);
    }

    function remove(index) {
        store(items.filter((_, i) => i !== index));
    }

    function expand(text) {
        const now = new Date();
        return String(text).replace(/\{date\}/g, Qt.formatDate(now, "yyyy-MM-dd")).replace(/\{time\}/g, Qt.formatTime(now, "hh:mm")).replace(/\{clipboard\}/g, Quickshell.clipboardText);
    }

    function insert(snippet) {
        Ui.run("niri-desk-type", expand(snippet.text));
    }

    FileView {
        id: file

        path: Quickshell.env("HOME") + "/.config/niri-desk/snippets.json"
        printErrors: false
        atomicWrites: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.load(text())
    }
}
