pragma Singleton

import QtQuick
import Quickshell

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
            run: () => Quickshell.execDetached(["loginctl", "lock-session"])
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

    // The open windows are saved first, so they come back exactly as they are now.
    function leave(command) {
        Quickshell.execDetached(["sh", "-c", "\"$HOME/.local/bin/niri-desk-session\" save; " + command]);
    }
}
