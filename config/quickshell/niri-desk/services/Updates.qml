pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// How many system updates wait. A failed check keeps the last count, because no network says nothing
// about it. Time is measured on the wall clock, so a laptop that slept checks soon after it wakes.
Singleton {
    id: root

    readonly property bool enabled: Settings.get("updates.enabled", true)
    readonly property real everyMs: Math.max(1, Number(Settings.get("updates.hours", 6)) || 6) * 3600000
    readonly property real retryMs: 900000
    property int count: 0
    property var packages: []
    property bool rebootNeeded: false
    property bool available: true
    property bool failed: false
    property real lastTry: 0
    property real lastGood: 0
    property bool loaded: false

    function check() {
        if (enabled && !proc.running)
            proc.running = true;
    }

    function open() {
        if (!available) {
            Toasts.show(Tr.t("Update check needs pacman-contrib"), "sudo pacman -S pacman-contrib", "alert");
            return;
        }
        Quickshell.execDetached([Ui.binDir + "niri-desk-updates", "open"]);
    }

    function clicked() {
        if (count > 0) {
            open();
        } else if (rebootNeeded) {
            Toasts.show(Tr.t("Reboot to finish the update"), Tr.t("A new kernel is installed"), "update", () => Ui.popup = "power");
        }
    }

    function due() {
        const age = Date.now() - lastTry;
        return age >= (failed ? retryMs : everyMs) || age < 0;
    }

    function saveState() {
        Saved.set("updates", {
            count: count,
            packages: packages,
            lastTry: lastTry,
            lastGood: lastGood,
            failed: failed
        });
    }

    Component.onCompleted: {
        const s = Saved.get("updates", null);
        if (s) {
            count = s.count || 0;
            packages = s.packages || [];
            lastTry = s.lastTry || 0;
            lastGood = s.lastGood || 0;
            failed = !!s.failed;
        }
        loaded = true;
    }

    onEnabledChanged: {
        if (enabled && due())
            check();
    }

    Timer {
        // Five minutes keeps the waking up check close. The first one waits for the network after login.
        interval: 300000
        repeat: true
        running: root.enabled
        onTriggered: {
            if (root.due())
                root.check();
        }
    }
    Timer {
        interval: 60000
        running: root.enabled && root.loaded
        onTriggered: {
            if (root.due())
                root.check();
            else
                reboot.running = true;
        }
    }

    Process {
        id: reboot

        command: ["sh", "-c", '[ -d "/usr/lib/modules/$(uname -r)" ] || echo yes']
        stdout: StdioCollector {
            onStreamFinished: root.rebootNeeded = text.trim() === "yes"
        }
    }

    Process {
        id: proc

        command: [Ui.binDir + "niri-desk-updates", "check"]
        stdout: StdioCollector {
            onStreamFinished: {
                let r = {};
                try {
                    r = JSON.parse(text);
                } catch (e) {}
                root.lastTry = Date.now();
                root.failed = !r.ok;
                root.available = r.reason !== "missing";
                root.rebootNeeded = !!r.reboot;
                if (r.ok) {
                    root.count = r.count;
                    root.packages = r.packages;
                    root.lastGood = root.lastTry;
                }
                root.saveState();
            }
        }
    }
}
