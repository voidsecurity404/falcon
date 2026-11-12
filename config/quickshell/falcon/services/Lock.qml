pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The lock screen of the shell. A flag file in memory-backed storage remembers the lock, so the shell
// locks again at once if it restarts while locked.
// animate() is the locking of Mod+L: LockIntro plays over the desktop and ends on exactly the
// picture hyprlock shows first, then the session is locked and hyprlock fades in over it.
// The show stays under hyprlock while locked; when hyprlock ends it plays backward ("out").
// A lock started elsewhere (idle, sleep) reports itself through lockStarted(), and the show is put
// under hyprlock at its last frame, so every unlock is animated.
Singleton {
    id: root

    readonly property string flag: Quickshell.env("XDG_RUNTIME_DIR") + "/falcon-locked"
    readonly property string introDir: Quickshell.env("XDG_RUNTIME_DIR") + "/falcon-lock"
    readonly property string background: Quickshell.env("HOME") + "/.local/state/falcon/lock-bg.jpg"
    property bool active: false
    // Shows the same screen in a normal layer, without locking anything. Esc closes it.
    property bool preview: false

    // "", "wait" (panels closing), "grab" (pictures of the screens), "play", "hold" (under hyprlock),
    // "out" (playing backward after the unlock)
    property string intro: ""
    property var introReady: ({})
    readonly property int introLength: 1150
    readonly property int outroLength: 1050

    function lock() {
        Ui.popup = "";
        active = true;
        Quickshell.execDetached(["touch", flag]);
    }

    function unlock() {
        Quickshell.execDetached(["rm", "-f", flag]);
        active = false;
    }

    function animate() {
        if (intro !== "" || active)
            return;
        if (Settings.get("session.lockScreen", "hyprlock") === "shell") {
            lock();
            return;
        }
        if (!Settings.get("windows.animations", true)) {
            lockSession();
            return;
        }
        const panelOpen = Ui.popup !== "";
        Ui.popup = "";
        introReady = {};
        intro = "wait";
        grabDelay.interval = panelOpen ? 280 : 1;
        grabDelay.restart();
        failsafe.restart();
    }

    // Each screen's LockIntro reports its picture. Any failure locks at once, without the show.
    function screenReady(name, ok) {
        if (intro !== "grab")
            return;
        if (!ok) {
            lockSession();
            intro = "";
            return;
        }
        const ready = Object.assign({}, introReady);
        ready[name] = true;
        introReady = ready;
        if (Quickshell.screens.every(s => ready[s.name]))
            intro = "play";
    }

    function introDone() {
        if (intro !== "play")
            return;
        intro = "hold";
        lockSession();
        watch.tries = 0;
        watch.restart();
    }

    // hypridle's lock_cmd calls this before hyprlock. Once hyprlock is up, the show waits under it.
    function lockStarted() {
        if (intro !== "" || active || Settings.get("session.lockScreen", "hyprlock") === "shell")
            return;
        watch.tries = 0;
        watch.restart();
    }

    function outroDone() {
        if (intro === "out")
            intro = "";
    }

    function lockSession() {
        failsafe.stop();
        // hypridle runs hyprlock for lock-session; if it is not running, hyprlock is started here.
        Quickshell.execDetached(["sh", "-c", 'loginctl lock-session; sleep 1.5; pgrep -u "$(id -u)" -x hyprlock >/dev/null || exec hyprlock']);
    }

    // Keeps the background picture current, so the show and hyprlock end on the same pixels.
    function refreshBackground() {
        Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/falcon-lock-bg"]);
    }

    Component.onCompleted: refreshBackground()

    Connections {
        target: Wallpapers
        function onShownImageChanged() {
            bgDelay.restart();
        }
    }

    Timer {
        id: bgDelay
        interval: 1500
        onTriggered: root.refreshBackground()
    }

    Timer {
        id: grabDelay
        onTriggered: root.intro = "grab"
    }

    // A picture that never arrives must not keep the session open.
    Timer {
        id: failsafe
        interval: 1500
        onTriggered: {
            if (root.intro === "wait" || root.intro === "grab") {
                root.lockSession();
                root.intro = "";
            }
        }
    }

    // Finds hyprlock, then waits for it to end.
    Timer {
        id: watch
        property int tries: 0
        interval: 200
        onTriggered: {
            tries++;
            hyprlockCheck.running = true;
        }
    }

    Process {
        id: hyprlockCheck
        command: ["pgrep", "-u", Quickshell.env("USER"), "-x", "hyprlock"]
        onExited: code => {
            if (code === 0) {
                if (root.intro === "")
                    root.intro = "hold";
                if (root.intro === "hold")
                    waiter.running = true;
            } else if (watch.tries > 25) {
                if (root.intro === "hold")
                    root.intro = "";
            } else {
                watch.restart();
            }
        }
    }

    // Ends with hyprlock: the unlock. hyprlock has already faded out over the show by then.
    Process {
        id: waiter
        command: ["sh", "-c", 'pidwait -u "$(id -u)" -x hyprlock 2>/dev/null || while pgrep -u "$(id -u)" -x hyprlock >/dev/null; do sleep 0.3; done']
        onExited: {
            if (root.intro === "hold")
                root.intro = Settings.get("windows.animations", true) ? "out" : "";
        }
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
