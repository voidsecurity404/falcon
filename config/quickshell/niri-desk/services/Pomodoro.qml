pragma Singleton

import QtQuick
import Quickshell

// Diqqat taymeri: ish va dam vaqti navbatma-navbat almashadi.
Singleton {
    id: root

    // "idle", "work", "rest"
    property string phase: "idle"
    property bool paused: false
    property int remaining: 0
    property int rounds: 0

    readonly property bool active: phase !== "idle"
    readonly property string label: Ui.pad(Math.floor(remaining / 60)) + ":" + Ui.pad(remaining % 60)

    function minutes(key, fallback) {
        const value = Number(Settings.get("pomodoro." + key, fallback));
        return value > 0 ? value : fallback;
    }

    function start() {
        phase = "work";
        paused = false;
        remaining = Math.round(minutes("work", 25) * 60);
    }

    function togglePause() {
        if (active)
            paused = !paused;
    }

    function reset() {
        phase = "idle";
        paused = false;
        remaining = 0;
        rounds = 0;
    }

    function finish() {
        if (phase === "work") {
            rounds += 1;
            phase = "rest";
            remaining = Math.round(minutes("rest", 5) * 60);
            Toasts.show(Tr.t("Time for a break"), Tr.t("Round {n} finished").replace("{n}", rounds), "bell");
        } else {
            phase = "work";
            remaining = Math.round(minutes("work", 25) * 60);
            Toasts.show(Tr.t("Back to work"), Tr.t("The next round has started"), "bell");
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.active && !root.paused
        onTriggered: {
            if (root.remaining <= 1)
                root.finish();
            else
                root.remaining -= 1;
        }
    }
}
