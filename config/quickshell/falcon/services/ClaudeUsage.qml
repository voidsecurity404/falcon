pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Claude subscription limits. falcon-claude-usage fetches them while they are on screen,
// falcon-claude-status saves them while Claude Code runs.
Singleton {
    id: root

    property var data: ({})
    property real now: Date.now() / 1000

    readonly property bool hasData: !!data.five_hour || !!data.seven_day
    readonly property real updated: data.updated || 0
    // A window past its reset time has started again, whatever the last saved value says.
    readonly property real fiveHour: used(data.five_hour)
    readonly property real weekly: used(data.seven_day)
    readonly property string fiveHourReset: resetText(data.five_hour)
    readonly property string weeklyReset: resetText(data.seven_day)
    readonly property string updatedText: {
        if (!updated)
            return "";
        const minutes = Math.floor((now - updated) / 60);
        return minutes < 1 ? Tr.t("Updated just now") : Tr.t("Updated {time} ago").replace("{time}", span(minutes * 60));
    }

    function used(window) {
        if (!window)
            return 0;
        return window.resets && window.resets <= now ? 0 : Math.max(0, Math.min(100, Number(window.used) || 0));
    }

    function span(seconds) {
        const total = Math.max(0, Math.round(seconds / 60));
        const days = Math.floor(total / 1440);
        const hours = Math.floor(total % 1440 / 60);
        const minutes = total % 60;
        if (days > 0)
            return Tr.t("{d} d {h} h").replace("{d}", days).replace("{h}", hours);
        if (hours > 0)
            return Tr.t("{h} h {m} min").replace("{h}", hours).replace("{m}", minutes);
        return Tr.t("{m} min").replace("{m}", Math.max(1, minutes));
    }

    function resetText(window) {
        if (!window || !window.resets)
            return "";
        if (window.resets <= now)
            return Tr.t("Limit has reset");
        return Tr.t("Resets in {time}").replace("{time}", span(window.resets - now));
    }

    // Only while the numbers are on screen.
    readonly property bool checking: Ui.popup === "claude"

    // Seconds until the next fetch. Stays at 0 while a fetch runs.
    property int countdown: 0
    property bool failed: false
    // The countdown while fetches work, otherwise the real age of the numbers.
    readonly property string statusText: checking && !failed ? Tr.t("Updating in {s} s").replace("{s}", countdown) : updatedText

    function refresh() {
        countdown = 0;
        fetch.running = true;
    }

    onCheckingChanged: {
        if (checking)
            refresh();
    }

    Process {
        id: fetch

        command: ["falcon-claude-usage"]
        onExited: code => {
            root.failed = code !== 0;
            root.countdown = 10;
        }
    }

    Timer {
        interval: 1000
        running: root.checking && !fetch.running
        repeat: true
        onTriggered: {
            if (root.countdown <= 1)
                root.refresh();
            else
                root.countdown--;
        }
    }

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/falcon/claude-usage.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.data = JSON.parse(text());
            } catch (e) {
                root.data = {};
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.now = Date.now() / 1000
    }
}
