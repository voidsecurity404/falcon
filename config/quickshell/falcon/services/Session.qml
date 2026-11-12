pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The five session actions, shared by the power menu and the ">" commands of the app menu.
Singleton {
    id: root

    // Fixed on purpose: the user asked for red, so it does not follow the wallpaper.
    readonly property color red: "#e5343a"

    readonly property var items: [
        {
            id: "lock",
            icon: "lock",
            name: Tr.t("Lock screen"),
            keywords: "lock блокировка",
            confirm: false,
            run: () => Lock.animate()
        },
        {
            id: "sleep",
            icon: "moon",
            name: Tr.t("Sleep"),
            keywords: "sleep suspend сон",
            confirm: false,
            run: () => Quickshell.execDetached(["systemctl", "suspend"])
        },
        {
            id: "logout",
            icon: "logout",
            name: Tr.t("Log out"),
            keywords: "logout quit выход",
            confirm: true,
            run: () => root.leave("niri msg action quit --skip-confirmation", "logout")
        },
        {
            id: "reboot",
            icon: "reboot",
            name: Tr.t("Reboot"),
            keywords: "reboot restart перезагрузка",
            confirm: true,
            run: () => root.leave("systemctl reboot", "reboot")
        },
        {
            id: "power",
            icon: "power",
            name: Tr.t("Shut down"),
            keywords: "shutdown poweroff выключение",
            confirm: true,
            run: () => root.leave("systemctl poweroff", "power")
        }
    ]

    // What would be lost by leaving now: a package update or an unfinished download.
    // Looked for every 2 s while the power menu or the app menu is open.
    property string warning: ""
    readonly property bool watching: Ui.popup === "power" || Ui.popup === "menu"

    function describe(lines) {
        if (lines.indexOf("update") >= 0)
            return Tr.t("A package update is running. Turning off now can break the system");
        const file = lines.find(l => l.startsWith("file:"));
        if (file)
            return Tr.t("A download is not finished: {name}").replace("{name}", file.slice(5).replace(/\.(part|crdownload|aria2|download)$/, ""));
        if (lines.indexOf("download") >= 0)
            return Tr.t("A download is still running");
        return "";
    }

    Timer {
        running: root.watching
        interval: 2000
        repeat: true
        triggeredOnStart: true
        onTriggered: check.running = true
    }
    onWatchingChanged: {
        if (!watching)
            warning = "";
    }

    // pacman holds its lock only while it changes packages. checkupdates uses its own database,
    // so it never counts. Files count only while they still grow.
    Process {
        id: check

        command: ["sh", "-c", `
            { [ -e /var/lib/pacman/db.lck ] || pgrep -x 'paru|yay|pamac|makepkg|pikaur|trizen' >/dev/null; } && echo update
            pgrep -x 'wget|aria2c|yt-dlp' >/dev/null && echo download
            for d in "$(xdg-user-dir DOWNLOAD 2>/dev/null)" "$HOME/Downloads"; do
                [ -d "$d" ] && find "$d" -maxdepth 1 -type f \\( -name '*.part' -o -name '*.crdownload' -o -name '*.aria2' -o -name '*.download' \\) -mmin -2 -printf 'file:%f\n'
            done 2>/dev/null | head -3
            true`]
        stdout: StdioCollector {
            onStreamFinished: root.warning = root.watching ? root.describe(text.trim().split("\n")) : ""
        }
    }

    // Leaving plays a farewell first (modules/LeaveShow.qml): the desktop is pictured, sinks
    // back into black and the falcon of the boot screen beats its wings over a caption, then fades,
    // and only on that black screen does the command run. Plymouth's shutdown screen then shows
    // the same falcon in the same place. Meanwhile the open windows are saved, so they come back
    // exactly as they are now.
    //   phase: "" idle, "wait" for open menus to close, "grab" picturing the screens, "play" the farewell, "done" command sent.
    property string phase: ""
    property string kind: ""
    property string command: ""
    readonly property int showLength: 1650
    property var shots: ({})
    readonly property string shotDir: Quickshell.env("XDG_RUNTIME_DIR") + "/falcon-leave"

    function leave(cmd, what) {
        if (phase !== "")
            return;
        Ui.popup = "";
        save.running = true;
        if (!Settings.get("windows.animations", true)) {
            command = cmd;
            run();
            return;
        }
        command = cmd;
        kind = what || "power";
        shots = {};
        // The power menu closes first, so it is not in the picture.
        phase = "wait";
        settle.restart();
    }

    // Each screen reports its picture; the farewell starts once all have, or without them.
    function screenReady(name, ok) {
        const next = Object.assign({}, shots);
        next[name] = ok;
        shots = next;
        if (phase === "grab" && Quickshell.screens.every(s => shots[s.name] !== undefined))
            phase = "play";
    }

    // Called by a screen's show when it has faded to black.
    function showDone() {
        if (phase === "play")
            run();
    }

    function run() {
        // A preview (desk leavePreview) has no command: the desktop just comes back.
        if (!command) {
            phase = "";
            return;
        }
        phase = "done";
        // Saving is quick; the command waits for it, so it is never cut short.
        Quickshell.execDetached(["sh", "-c", "i=0; while pgrep -f 'falcon-sessio[n] save' >/dev/null && [ $i -lt 60 ]; do sleep 0.05; i=$((i+1)); done; " + command]);
        stuck.restart();
    }

    Process {
        id: save

        command: [Quickshell.env("HOME") + "/.local/bin/falcon-session", "save"]
    }

    Timer {
        id: settle

        interval: 260
        onTriggered: {
            root.phase = "grab";
            failsafe.restart();
        }
    }
    // No picture in time: the farewell plays on black.
    Timer {
        id: failsafe

        interval: 1200
        onTriggered: {
            if (root.phase === "grab")
                root.phase = "play";
        }
    }
    // The system refused (an inhibitor, a policy): the desktop comes back.
    Timer {
        id: stuck

        interval: 7000
        onTriggered: {
            if (root.phase === "done" && root.kind !== "logout") {
                root.phase = "";
                Toasts.show(Tr.t("Could not turn off"), Tr.t("The system refused the request"), "power");
            } else if (root.phase === "done") {
                root.phase = "";
            }
        }
    }
}
