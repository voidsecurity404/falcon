pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Kofe rejimi: yoqilganda ekran o'chmaydi, bloklanmaydi va kompyuter uxlamaydi.
// Two locks hold it. TopLayer's IdleInhibitor counts only while the panel is drawn, so it ends once the
// session is locked. This one is logind's idle lock, which hypridle obeys in any state. It covers idle
// only, so the sleep button and the lid still work.
Singleton {
    id: root

    property bool enabled: false

    onEnabledChanged: Saved.set("caffeine", enabled)
    Component.onCompleted: enabled = Saved.get("caffeine", false)

    Process {
        id: lock

        // The child waits on a pipe from the shell, so nothing stays behind if the shell is killed.
        command: ["systemd-inhibit", "--what=idle", "--who=niri-desk", "--why=Caffeine", "--mode=block", "sh", "-c", "cat >/dev/null"]
        running: root.enabled
        stdinEnabled: true
        onExited: {
            if (root.enabled)
                retry.restart();
        }
    }
    Timer {
        id: retry

        interval: 5000
        onTriggered: lock.running = root.enabled
    }
}
