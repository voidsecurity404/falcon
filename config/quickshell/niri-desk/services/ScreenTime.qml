pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Screen Time: seconds per app per day, only app names. It stays on this computer, 31 days long.
Singleton {
    id: root

    readonly property bool enabled: Settings.get("screentime.enabled", true)
    readonly property int keepDays: 31
    property var days: ({})
    property real lastTick: Date.now()
    property bool dirty: false
    property bool loaded: false
    property bool otherLock: false
    readonly property var focused: Niri.windows[Niri.focusedWindowId] || null
    readonly property string dateKey: dateOf(new Date(nowTick))
    property real nowTick: Date.now()

    readonly property var today: days[dateKey] || ({})
    readonly property int todaySeconds: sum(today)
    readonly property var apps: Object.keys(today).map(app => {
        const entry = DesktopEntries.heuristicLookup(app);
        return {
            app: app,
            name: entry ? entry.name : app,
            icon: entry ? entry.icon : app,
            seconds: today[app]
        };
    }).sort((a, b) => b.seconds - a.seconds)
    readonly property var week: {
        const out = [];
        for (let back = 6; back >= 0; back--) {
            const day = new Date(nowTick - back * 86400000);
            const key = dateOf(day);
            out.push({
                date: key,
                label: Tr.capitalized(day.toLocaleDateString(Tr.locale, "ddd")),
                full: day.toLocaleDateString(Tr.locale, "d MMMM"),
                seconds: sum(days[key] || {}),
                today: back === 0
            });
        }
        return out;
    }
    readonly property int weekAverage: {
        const used = week.filter(d => d.seconds > 0);
        return used.length === 0 ? 0 : Math.round(used.reduce((all, d) => all + d.seconds, 0) / used.length);
    }

    function dateOf(day) {
        return Qt.formatDate(day, "yyyy-MM-dd");
    }

    function sum(day) {
        return Object.values(day).reduce((all, s) => all + s, 0);
    }

    function format(seconds) {
        const minutes = Math.round(seconds / 60);
        if (minutes < 60)
            return Tr.t("{n} min").replace("{n}", minutes);
        return Tr.t("{h} h {m} min").replace("{h}", Math.floor(minutes / 60)).replace("{m}", minutes % 60);
    }

    // A window in focus counts while someone works, or while it plays something to watch.
    function counting() {
        if (!enabled || !focused || !focused.app_id || focused.app_id === "org.quickshell" || Lock.active)
            return false;
        if (!idle.isIdle)
            return true;
        return !!Media.player && Media.player.isPlaying && !otherLock;
    }

    function tick() {
        const now = Date.now();
        const passed = (now - lastTick) / 1000;
        lastTick = now;
        nowTick = now;
        // A longer gap means the computer slept.
        if (passed > 30 || passed <= 0 || !counting())
            return;
        const key = dateOf(new Date(now));
        const next = Object.assign({}, days);
        const day = Object.assign({}, next[key] || {});
        day[focused.app_id] = (day[focused.app_id] || 0) + passed;
        next[key] = day;
        days = next;
        dirty = true;
        if (idle.isIdle)
            lockCheck.running = true;
    }

    function save() {
        if (!loaded || !dirty)
            return;
        const oldest = dateOf(new Date(Date.now() - keepDays * 86400000));
        const kept = {};
        for (const key of Object.keys(days)) {
            if (key >= oldest)
                kept[key] = days[key];
        }
        file.setText(JSON.stringify(kept) + "\n");
        dirty = false;
    }

    IdleMonitor {
        id: idle

        timeout: 120
        respectInhibitors: false
    }

    Process {
        id: lockCheck

        command: ["pgrep", "-x", "hyprlock"]
        onExited: code => root.otherLock = code === 0
    }

    Timer {
        interval: 10000
        repeat: true
        running: root.loaded
        onTriggered: root.tick()
    }
    Timer {
        interval: 60000
        repeat: true
        running: root.loaded
        onTriggered: root.save()
    }

    FileView {
        id: file

        path: Quickshell.env("HOME") + "/.local/state/niri-desk/screentime.json"
        printErrors: false
        atomicWrites: true
        onLoaded: {
            try {
                root.days = JSON.parse(text() || "{}");
            } catch (e) {
                root.days = {};
            }
            root.loaded = true;
        }
        onLoadFailed: root.loaded = true
    }

    Component.onDestruction: save()
}
