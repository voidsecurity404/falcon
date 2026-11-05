pragma Singleton

import QtQuick
import Quickshell

// Yorug' va qorong'i rejim vaqtga qarab o'zi almashadi.
Singleton {
    id: root

    function minutesOf(text, fallback) {
        const m = /^(\d{1,2}):(\d{2})$/.exec(String(text));
        return m ? Number(m[1]) * 60 + Number(m[2]) : fallback;
    }

    function wantedMode(now) {
        const light = minutesOf(Settings.get("schedule.lightFrom", "07:00"), 420);
        const dark = minutesOf(Settings.get("schedule.darkFrom", "19:00"), 1140);
        const t = now.getHours() * 60 + now.getMinutes();
        const isLight = light < dark ? t >= light && t < dark : t >= light || t < dark;
        return isLight ? "light" : "dark";
    }

    function check() {
        if (!Settings.ready || !Settings.get("schedule.mode", false))
            return;
        const mode = wantedMode(new Date());
        if (Settings.get("appearance.mode", "dark") !== mode)
            Settings.set("appearance.mode", mode, true);
    }

    Timer {
        interval: 30000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.check()
    }

    Connections {
        target: Settings
        function onDataChanged() {
            root.check();
        }
    }
}
