pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The lock screen of the shell. A flag file in memory-backed storage remembers the lock, so the shell
// locks again at once if it restarts while locked.
Singleton {
    id: root

    readonly property string flag: Quickshell.env("XDG_RUNTIME_DIR") + "/niri-desk-locked"
    property bool active: false
    // Shows the same screen in a normal layer, without locking anything. Esc closes it.
    property bool preview: false

    function lock() {
        Ui.popup = "";
        active = true;
        Quickshell.execDetached(["touch", flag]);
    }

    function unlock() {
        Quickshell.execDetached(["rm", "-f", flag]);
        active = false;
    }

    Process {
        running: true
        command: ["test", "-e", root.flag]
        onExited: code => {
            if (code === 0)
                root.active = true;
        }
    }
}
