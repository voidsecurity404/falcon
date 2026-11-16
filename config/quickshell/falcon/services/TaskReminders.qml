pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Deadlines of the tasks widget (~/.config/falcon/todo.json). A task may carry "due" (ms); when
// it passes and the task is still open, a notification says so once ("notified"). Runs whether or
// not the widget is on screen, since the widget's content is destroyed while hidden.
Singleton {
    id: root

    property var tasks: []
    // Open tasks with a deadline still to come.
    readonly property int waiting: tasks.filter(t => !t.done && t.due > Date.now()).length

    function pad(n) {
        return (n < 10 ? "0" : "") + n;
    }

    // Reads a deadline written after "@" at the end of a task: @18:00, @tomorrow, @tomorrow 9:00,
    // @30m, @2h, @1h30m, @20.11, @20.11 14:00, also in Russian and Uzbek (завтра, ertaga, м, ч).
    // Returns { text, due } with the marker taken out, due 0 when there is none or it cannot be read.
    function parse(raw, nowMs) {
        const text = String(raw || "");
        const at = text.lastIndexOf("@");
        if (at < 0)
            return { text: text.trim(), due: 0 };
        const spec = text.slice(at + 1).trim().toLowerCase();
        const rest = text.slice(0, at).trim();
        const now = new Date(nowMs || Date.now());
        let due = null;
        let m;
        const time = s => {
            const t = s.match(/^(\d{1,2})(?::(\d{2}))?$/);
            return t && Number(t[1]) < 24 && Number(t[2] || 0) < 60 ? [Number(t[1]), Number(t[2] || 0)] : null;
        };
        if ((m = spec.match(/^(?:(\d+)\s*(?:h|ч|soat))?\s*(?:(\d+)\s*(?:m|min|м|мин|daq))?$/)) && (m[1] || m[2])) {
            due = new Date(now.getTime() + ((Number(m[1]) || 0) * 60 + (Number(m[2]) || 0)) * 60000);
        } else if ((m = spec.match(/^(tomorrow|завтра|ertaga)(?:\s+(.+))?$/))) {
            const t = m[2] ? time(m[2]) : [9, 0];
            if (t)
                due = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1, t[0], t[1]);
        } else if ((m = spec.match(/^(\d{1,2})\.(\d{1,2})(?:\s+(.+))?$/))) {
            const t = m[3] ? time(m[3]) : [9, 0];
            if (t && Number(m[2]) >= 1 && Number(m[2]) <= 12) {
                due = new Date(now.getFullYear(), Number(m[2]) - 1, Number(m[1]), t[0], t[1]);
                if (due.getTime() < now.getTime() - 86400000)
                    due.setFullYear(due.getFullYear() + 1);
            }
        } else {
            const t = time(spec);
            if (t) {
                due = new Date(now.getFullYear(), now.getMonth(), now.getDate(), t[0], t[1]);
                if (due.getTime() <= now.getTime())
                    due.setDate(due.getDate() + 1);
            }
        }
        if (!due || isNaN(due.getTime()) || rest === "")
            return { text: text.trim(), due: 0 };
        return { text: rest, due: due.getTime() };
    }

    // How a deadline reads in the list: the time today, "Tomorrow 9:00", or the date.
    function label(due, nowMs) {
        if (!due)
            return "";
        const d = new Date(due);
        const now = new Date(nowMs || Date.now());
        const clock = pad(d.getHours()) + ":" + pad(d.getMinutes());
        const days = Math.round((new Date(d.getFullYear(), d.getMonth(), d.getDate()) - new Date(now.getFullYear(), now.getMonth(), now.getDate())) / 86400000);
        if (days === 0)
            return clock;
        if (days === 1)
            return Tr.t("Tomorrow") + " " + clock;
        if (days === -1)
            return Tr.t("Yesterday") + " " + clock;
        return Qt.locale().toString(d, "d MMM") + " " + clock;
    }

    function check() {
        const now = Date.now();
        let changed = false;
        const next = tasks.map(t => {
            if (t.done || !t.due || t.notified || t.due > now)
                return t;
            changed = true;
            // Long past ones (the computer was off) are marked without a card.
            if (now - t.due < 6 * 3600000)
                Toasts.show(Tr.t("Task is due"), t.text, "check");
            return Object.assign({}, t, { notified: true });
        });
        if (changed) {
            tasks = next;
            file.setText(JSON.stringify(next, null, 1) + "\n");
        }
    }

    FileView {
        id: file

        path: Quickshell.env("HOME") + "/.config/falcon/todo.json"
        printErrors: false
        atomicWrites: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const list = JSON.parse(text());
                root.tasks = Array.isArray(list) ? list.filter(t => t && typeof t.text === "string") : [];
            } catch (e) {
                root.tasks = [];
            }
            root.check();
        }
    }
    Timer {
        interval: 15000
        running: root.tasks.some(t => !t.done && t.due && !t.notified)
        repeat: true
        onTriggered: root.check()
    }
}
