pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Events for the calendar menu from `calendar.sources` (iCal links or .ics files) through
// bin/falcon-calendar, which caches links for 15 minutes. Asked again every 15 minutes, when the
// sources change, and when the menu opens on data older than 5 minutes.
Singleton {
    id: root

    readonly property string sources: String(Settings.get("calendar.sources", "") || "")
    readonly property bool configured: sources.trim() !== ""
    property var events: []
    property var errors: []
    property var byDay: ({})
    property double fetchedAt: 0
    property bool loading: proc.running

    function key(d) {
        return d.getFullYear() + "-" + (d.getMonth() + 1) + "-" + d.getDate();
    }

    function eventsOn(d) {
        return byDay[key(d)] || [];
    }

    function refresh(force) {
        if (!configured) {
            events = [];
            byDay = {};
            errors = [];
            return;
        }
        if (proc.running)
            return;
        proc.command = [Ui.binDir + "falcon-calendar", "events"].concat(force ? ["--force"] : []);
        proc.running = true;
    }

    function refreshIfStale() {
        if (Date.now() - fetchedAt > 5 * 60 * 1000)
            refresh(false);
    }

    function colorOf(source) {
        return source === 0 ? Theme.accent : Theme.hueShift(Theme.accent, source * 0.21);
    }

    // Each day an event touches gets it; an all-day end is exclusive, as in iCal.
    function index(list) {
        const days = {};
        for (const e of list) {
            const start = new Date(e.start);
            const end = new Date(e.end);
            const day = new Date(start.getFullYear(), start.getMonth(), start.getDate());
            let guard = 0;
            do {
                const k = key(day);
                (days[k] = days[k] || []).push(e);
                day.setDate(day.getDate() + 1);
            } while (day < end && guard++ < 60);
        }
        return days;
    }

    onSourcesChanged: debounce.restart()
    Component.onCompleted: refresh(false)

    Timer {
        id: debounce

        interval: 900
        onTriggered: root.refresh(true)
    }
    Timer {
        interval: 15 * 60 * 1000
        running: root.configured
        repeat: true
        onTriggered: root.refresh(false)
    }

    Process {
        id: proc

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    root.events = d.events || [];
                    root.errors = d.errors || [];
                    root.byDay = root.index(root.events);
                    root.fetchedAt = Date.now();
                } catch (e) {}
            }
        }
    }
}
