pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// While falcon-session brings the windows back after login it holds a flag file, and the shell covers
// the screen for that time (modules/SessionCover.qml). falcon-session starts apps only once the cover
// is up, so the windows open and move into place unseen.
Singleton {
    id: root

    readonly property string flag: Quickshell.env("XDG_RUNTIME_DIR") + "/falcon-restoring"
    // A flag older than this was left by a restore that was killed, and is ignored.
    readonly property int staleSeconds: 90
    property bool active: false
    // Once lifted, the cover stays away for the rest of this shell's life.
    property bool done: false
    // falcon-session starts with the session too and may set the flag a moment after the shell
    // looks, so the first seconds are watched as well.
    property bool starting: true

    // Lifts the cover at once. Restoring goes on underneath.
    function finish() {
        done = true;
        active = false;
    }

    Process {
        id: probe

        running: true
        command: ["sh", "-c", "[ -e \"$1\" ] && [ $(( $(date +%s) - $(stat -c %Y \"$1\") )) -lt " + root.staleSeconds + " ]", "sh", root.flag]
        onExited: code => {
            if (root.done)
                return;
            root.active = code === 0;
            if (root.active)
                root.starting = false;
            else if (!root.starting)
                root.finish();
        }
    }

    Timer {
        interval: 6000
        running: true
        onTriggered: {
            root.starting = false;
            if (!root.active)
                root.done = true;
        }
    }

    Timer {
        interval: 150
        repeat: true
        running: !root.done && (root.active || root.starting)
        onTriggered: probe.running = true
    }

    // An app that never opens a window must not keep the desktop hidden.
    Timer {
        interval: 15000
        running: root.active
        onTriggered: root.finish()
    }
}
