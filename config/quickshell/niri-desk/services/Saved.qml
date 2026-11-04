pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Quick toggles and the notification history, which must outlive a shell restart. They live
// outside settings.json, so a change does not rewrite the niri, kitty and hypridle files.
Singleton {
    id: root

    property var cache: null

    function all() {
        if (cache === null) {
            try {
                cache = JSON.parse(file.text() || "{}");
            } catch (e) {
                cache = {};
            }
        }
        return cache;
    }

    function get(key, fallback) {
        const value = all()[key];
        return value === undefined ? fallback : value;
    }

    function set(key, value) {
        if (JSON.stringify(all()[key]) === JSON.stringify(value))
            return;
        const next = Object.assign({}, cache);
        next[key] = value;
        cache = next;
        file.setText(JSON.stringify(next, null, 2) + "\n");
    }

    FileView {
        id: file

        path: Quickshell.env("HOME") + "/.local/state/niri-desk/toggles.json"
        blockLoading: true
        printErrors: false
        atomicWrites: true
    }
}
