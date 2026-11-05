pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Wayland

// Changes the wallpaper by itself: a slideshow, or one picture for the day and one for the night.
// A change waits while nobody is looking or something is being done with the wallpaper.
Singleton {
    id: root

    readonly property string mode: Settings.get("wallpaper.auto", "off")
    readonly property real everyMs: Math.max(60, Number(Settings.get("wallpaper.slideshowEvery", 3600)) || 3600) * 1000
    property real last: 0
    property string phase: ""
    property var bag: []
    property var failed: ({})
    property string changing: ""
    property bool started: false

    readonly property bool busy: changer.running || Ui.pickerAlive || Ui.regionPhase !== "" || Widgets.editMode || Lock.active || idle.isIdle || Scenes.holdsWallpaper
    readonly property bool canSlide: Settings.get("wallpaper.slideshowOnBattery", false) || !UPower.onBattery

    function keep() {
        Saved.set("wallpaperAuto", {
            last: last,
            phase: phase,
            bag: bag
        });
    }

    function shuffled(list) {
        const out = list.slice();
        for (let i = out.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [out[i], out[j]] = [out[j], out[i]];
        }
        return out;
    }

    function nextImage() {
        const files = Wallpapers.imageFiles.filter(f => !failed[f]);
        const current = Wallpapers.currentImage;
        if (files.filter(f => f !== current).length === 0)
            return "";
        if (Settings.get("wallpaper.slideshowOrder", "random") === "name") {
            const sorted = files.slice().sort();
            return sorted[(sorted.indexOf(current) + 1) % sorted.length] || sorted[0];
        }
        // Every picture comes once before any comes again. Deleted ones drop out, new ones join next round.
        let rest = bag.filter(f => files.includes(f) && f !== current);
        if (rest.length === 0)
            rest = shuffled(files.filter(f => f !== current));
        const pick = rest[0];
        bag = rest.slice(1);
        return pick;
    }

    function change(path) {
        if (!path)
            return;
        changing = path;
        changer.command = ["env", "NIRI_DESK_QUIET=1", Ui.binDir + "niri-desk-wallpaper", path];
        changer.running = true;
    }

    function expand(path) {
        return String(path || "").replace(/^~/, Ui.home);
    }

    function useCurrentFor(key) {
        const path = Wallpapers.currentLive || Wallpapers.currentImage;
        if (path)
            Settings.set("wallpaper." + key, path);
    }

    function check() {
        if (!started || busy)
            return;
        if (mode === "slideshow") {
            // A live wallpaper was chosen on purpose, so it stays until another is chosen.
            if (Wallpapers.currentLive !== "" || !canSlide)
                return;
            const age = Date.now() - last;
            if (age >= everyMs || age < 0)
                change(nextImage());
        } else if (mode === "dayNight") {
            const now = Schedule.wantedMode(new Date()) === "light" ? "day" : "night";
            // Only the change of day and night acts, so a wallpaper chosen by hand stays until the next one.
            if (now === phase)
                return;
            const path = expand(Settings.get("wallpaper." + now, ""));
            phase = now;
            keep();
            change(path);
        }
    }

    onModeChanged: {
        if (!started)
            return;
        // A slideshow counts from now. Day and night apply at once.
        last = Date.now();
        phase = "";
        keep();
        check();
    }

    Component.onCompleted: {
        const s = Saved.get("wallpaperAuto", null);
        if (s) {
            last = s.last || 0;
            phase = s.phase || "";
            bag = s.bag || [];
        }
    }

    IdleMonitor {
        id: idle

        timeout: 120
        respectInhibitors: false
    }

    // Waits for the lists of wallpapers, which arrive after the settings.
    Timer {
        interval: 8000
        running: Settings.loaded
        onTriggered: {
            if (root.last === 0) {
                root.last = Date.now();
                root.keep();
            }
            root.started = true;
            root.check();
        }
    }
    Timer {
        interval: 30000
        repeat: true
        running: root.started && root.mode !== "off"
        onTriggered: root.check()
    }

    Connections {
        target: Wallpapers
        function onCurrentChanged() {
            // Also when chosen by hand: the next picture of a slideshow gets its full time on screen.
            root.last = Date.now();
            root.keep();
        }
    }

    Process {
        id: changer

        onExited: code => {
            const path = root.changing;
            root.changing = "";
            if (code === 0) {
                Wallpapers.chosen(path, /\.(mp4|webm|mkv|mov)$/i.test(path));
                Wallpapers.refresh();
                return;
            }
            if (!root.failed[path]) {
                const next = Object.assign({}, root.failed);
                next[path] = true;
                root.failed = next;
                Toasts.show(Tr.t("Wallpaper could not be set"), path.split("/").pop(), "alert");
            }
        }
    }
}
