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
            run: () => root.leave("niri msg action quit --skip-confirmation")
        },
        {
            id: "reboot",
            icon: "reboot",
            name: Tr.t("Reboot"),
            keywords: "reboot restart перезагрузка",
            confirm: true,
            run: () => root.leave("systemctl reboot")
        },
        {
            id: "power",
            icon: "power",
            name: Tr.t("Shut down"),
            keywords: "shutdown poweroff выключение",
            confirm: true,
            run: () => root.leave("systemctl poweroff")
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

    // The open windows are saved first, so they come back exactly as they are now.
    function leave(command) {
        Quickshell.execDetached(["sh", "-c", "\"$HOME/.local/bin/falcon-session\" save; " + command]);
    }
}
