pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Barcha sozlamalar: defaults.json ustiga settings.json. Fayl qo'lda o'zgarsa ham darhol qo'llanadi.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string dir: home + "/.config/niri-desk/"

    property var defaults: ({})
    property var user: ({})
    property var data: ({})
    property string lastError: ""
    property bool ready: false

    readonly property real weatherLat: get("weather.lat", 41.31)
    readonly property real weatherLon: get("weather.lon", 69.28)
    readonly property string labTarget: get("lab.target", "")
    readonly property var labPorts: get("lab.ports", [])
    readonly property string vpnInterface: get("lab.vpnInterface", "tun0")
    readonly property string vpnUp: get("vpn.up", "")
    readonly property string vpnDown: get("vpn.down", "")
    readonly property string wallpaperDir: String(get("wallpaperDir", "~/Pictures/Wallpapers")).replace(/^~/, home)
    readonly property bool bottom: get("panel.position", "top") === "bottom"

    function merge(base, over) {
        const out = Object.assign({}, base);
        for (const key in over) {
            const value = over[key];
            if (value && typeof value === "object" && !Array.isArray(value) && out[key] && typeof out[key] === "object" && !Array.isArray(out[key]))
                out[key] = merge(out[key], value);
            else
                out[key] = value;
        }
        return out;
    }

    function get(path, fallback) {
        let node = data;
        for (const key of path.split(".")) {
            if (node === undefined || node === null)
                return fallback;
            node = node[key];
        }
        return node === undefined || node === null ? fallback : node;
    }

    function set(path, value) {
        const copy = JSON.parse(JSON.stringify(user));
        const keys = path.split(".");
        let node = copy;
        for (const key of keys.slice(0, -1)) {
            if (!node[key] || typeof node[key] !== "object")
                node[key] = {};
            node = node[key];
        }
        node[keys[keys.length - 1]] = value;
        write(copy);
    }

    function resetAll() {
        const copy = {};
        // Shaxsiy ma'lumotlar saqlanadi: nishon, VPN va ob-havo joyi.
        for (const key of ["lab", "vpn", "weather", "wallpaperDir"]) {
            if (user[key] !== undefined)
                copy[key] = user[key];
        }
        write(copy);
    }

    function write(next) {
        user = next;
        data = merge(defaults, next);
        userFile.setText(JSON.stringify(next, null, 2) + "\n");
        debounce.restart();
    }

    FileView {
        id: defaultsFile

        path: root.dir + "defaults.json"
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                root.defaults = JSON.parse(text());
                root.data = root.merge(root.defaults, root.user);
                root.ready = true;
            } catch (e) {
                console.warn("Could not read defaults.json:", e);
            }
        }
    }

    FileView {
        id: userFile

        path: root.dir + "settings.json"
        watchChanges: true
        printErrors: false
        atomicWrites: true
        onFileChanged: reload()
        onLoaded: {
            const before = JSON.stringify(root.user);
            try {
                const parsed = JSON.parse(text() || "{}");
                const now = JSON.stringify(parsed);
                root.user = parsed;
                root.data = root.merge(root.defaults, parsed);
                if (root.ready && now !== before)
                    debounce.restart();
            } catch (e) {
                root.lastError = "settings.json: " + e;
                Toasts.show(Tr.t("The settings file is invalid"), Tr.t("The previous settings stay active"), "alert");
            }
        }
    }

    Timer {
        id: debounce

        interval: 250
        onTriggered: {
            if (apply.running)
                restart();
            else
                apply.running = true;
        }
    }

    Process {
        id: apply

        command: [root.home + "/.local/bin/niri-desk-apply"]
        stderr: StdioCollector {
            onStreamFinished: {
                root.lastError = text.trim();
                if (root.lastError !== "")
                    Toasts.show(Tr.t("Setting not applied"), root.lastError, "alert");
            }
        }
    }
}
