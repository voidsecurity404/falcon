pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// One timer or a Pomodoro cycle, shown in the island. The end is kept as a time of day on disk, so it
// survives a shell restart, a reboot and sleep. It cannot wake the laptop: a timer that ended meanwhile
// says so when the laptop is back.
Singleton {
    id: root

    readonly property int maxSeconds: 86400
    readonly property int graceMs: 60000
    // Time of the end while running, in ms. 0 when stopped or paused.
    property real endAt: 0
    // Seconds left while paused.
    property int pausedLeft: 0
    property int left: 0
    // The whole length, for a meter.
    property int total: 0
    property string label: ""
    // "", work, break
    property string phase: ""
    property int round: 1

    readonly property bool active: endAt > 0 || pausedLeft > 0
    readonly property bool paused: pausedLeft > 0
    readonly property string text: format(left)
    readonly property string icon: phase === "work" ? "focus" : phase === "break" ? "coffee" : "timer"

    function format(seconds) {
        const h = Math.floor(seconds / 3600);
        const m = Math.floor(seconds % 3600 / 60);
        const s = seconds % 60;
        return (h > 0 ? h + ":" + Ui.pad(m) : String(m)) + ":" + Ui.pad(s);
    }

    // 25, 25m, 90s, 1h, 1h30m, 1:30 (min:sec), 1:30:00, 1.5. Bare numbers are minutes. Gives 0 for anything else.
    function parse(input) {
        const t = String(input).trim().toLowerCase().replace(",", ".").replace(/\s+/g, "");
        let seconds = 0;
        let m;
        if ((m = /^(\d+):(\d{1,2}):(\d{1,2})$/.exec(t)))
            seconds = +m[1] * 3600 + +m[2] * 60 + +m[3];
        else if ((m = /^(\d+):(\d{1,2})$/.exec(t)))
            seconds = +m[1] * 60 + +m[2];
        else if ((m = /^(\d+(?:\.\d+)?)$/.exec(t)))
            seconds = +m[1] * 60;
        else if ((m = /^(?:(\d+(?:\.\d+)?)(?:h|ч|час|часа|часов))?(?:(\d+(?:\.\d+)?)(?:m|min|м|мин|минут|минуты))?(?:(\d+(?:\.\d+)?)(?:s|sec|с|сек|секунд|секунды))?$/.exec(t)) && t !== "")
            seconds = (+m[1] || 0) * 3600 + (+m[2] || 0) * 60 + (+m[3] || 0);
        seconds = Math.round(seconds);
        return seconds >= 1 && seconds <= maxSeconds ? seconds : 0;
    }

    function start(seconds, name) {
        if (seconds < 1)
            return;
        phase = "";
        round = 1;
        begin(Math.min(seconds, maxSeconds), name || "");
    }

    function begin(seconds, name) {
        label = name;
        pausedLeft = 0;
        endAt = Date.now() + seconds * 1000;
        left = seconds;
        total = seconds;
        save();
    }

    function pomodoro() {
        round = 1;
        startPhase("work");
    }

    function startPhase(next) {
        phase = next;
        const long = round % 4 === 0;
        const minutes = next === "work" ? Settings.get("timer.work", 25) : long ? Settings.get("timer.longBreak", 15) : Settings.get("timer.shortBreak", 5);
        begin(Math.max(1, Number(minutes) || 1) * 60, next === "work" ? Tr.t("Work") : Tr.t("Break"));
    }

    function stop() {
        endAt = 0;
        pausedLeft = 0;
        left = 0;
        total = 0;
        label = "";
        phase = "";
        round = 1;
        save();
    }

    function togglePause() {
        if (paused) {
            endAt = Date.now() + pausedLeft * 1000;
            pausedLeft = 0;
        } else if (active) {
            pausedLeft = Math.max(1, left);
            endAt = 0;
        }
        save();
    }

    function add(seconds) {
        if (paused)
            pausedLeft = Math.min(maxSeconds, pausedLeft + seconds);
        else if (active)
            endAt = Math.min(Date.now() + maxSeconds * 1000, endAt + seconds * 1000);
        total += seconds;
        update();
        save();
    }

    function save() {
        Saved.set("timer", active ? {
            endAt: endAt,
            pausedLeft: pausedLeft,
            total: total,
            label: label,
            phase: phase,
            round: round
        } : null);
    }

    function update() {
        if (paused) {
            left = pausedLeft;
            return;
        }
        if (endAt <= 0)
            return;
        const ms = endAt - Date.now();
        left = Math.max(0, Math.ceil(ms / 1000));
        if (ms <= 0)
            finish(-ms);
    }

    function ring() {
        if (Toasts.doNotDisturb || !Settings.get("timer.sound", true))
            return;
        Quickshell.execDetached(["sh", "-c", 'f=/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga; [ -f "$f" ] && pw-play "$f"']);
    }

    function finish(lateMs) {
        const ended = new Date(endAt);
        const late = lateMs > graceMs;
        const wasPhase = phase;
        const name = label;
        // Away during a Pomodoro: the cycle does not run on by itself over an empty chair.
        if (wasPhase !== "" && !late) {
            if (wasPhase === "work") {
                startPhase("break");
                Toasts.alarm(Tr.t("Time for a break"), Tr.t("{n} min").replace("{n}", Math.round(left / 60)), "coffee");
            } else {
                round++;
                startPhase("work");
                Toasts.alarm(Tr.t("Back to work"), Tr.t("Round {n}").replace("{n}", round), "focus");
            }
            ring();
            return;
        }
        stop();
        const sub = late ? Tr.t("Ended at {t}").replace("{t}", Ui.pad(ended.getHours()) + ":" + Ui.pad(ended.getMinutes())) : name;
        Toasts.alarm(wasPhase !== "" ? Tr.t("Pomodoro stopped") : Tr.t("Time is up"), sub, "timer");
        if (!late)
            ring();
    }

    Component.onCompleted: {
        const s = Saved.get("timer", null);
        if (s && (s.endAt > 0 || s.pausedLeft > 0)) {
            label = s.label || "";
            phase = s.phase || "";
            round = s.round || 1;
            pausedLeft = s.pausedLeft || 0;
            endAt = s.endAt || 0;
            update();
            total = s.total || left;
        }
    }

    Timer {
        interval: 500
        repeat: true
        running: root.active && !root.paused
        onTriggered: root.update()
    }
}
