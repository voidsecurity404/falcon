pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Scenes, like macOS Focus: which apps may show notifications, what opens, which wallpaper is on.
// Everything still goes to the notification history, as with Silent mode.
Singleton {
    id: root

    readonly property var ids: ["work", "reading", "personal"]
    readonly property var icons: ({
            work: "chip",
            reading: "note",
            personal: "sun"
        })
    readonly property var list: ids.map(id => {
        const s = Settings.get("scenes." + id, {});
        return {
            id: id,
            icon: icons[id],
            name: Tr.t(s.name || id),
            allow: s.allow || "",
            open: s.open || "",
            wallpaper: s.wallpaper || ""
        };
    })
    property string active: ""
    readonly property var current: list.find(s => s.id === active) || null
    readonly property bool holdsWallpaper: !!current && current.wallpaper !== ""

    function words(text) {
        return String(text || "").split(",").map(w => w.trim()).filter(w => w !== "");
    }

    function allows(appName) {
        if (!current)
            return true;
        const app = String(appName || "").toLowerCase();
        return words(current.allow).some(w => app.indexOf(w.toLowerCase()) >= 0);
    }

    function setWallpaper(path) {
        Quickshell.execDetached({
            command: [Ui.binDir + "niri-desk-wallpaper", path],
            environment: {
                NIRI_DESK_QUIET: "1"
            }
        });
    }

    // Wallpapers keeps a list for the picker that can be behind, so the links themselves are read.
    function withWallpaper(done) {
        afterRead = done;
        wallpaperRead.running = true;
    }

    function leaveWallpaper(shown, next) {
        const scene = current;
        const before = Saved.get("sceneWallpaper", "");
        if (!scene || scene.wallpaper === "" || (next && next.wallpaper !== ""))
            return;
        // A wallpaper chosen by hand during the scene stays.
        if (before !== "" && shown === scene.wallpaper)
            setWallpaper(before);
        Saved.set("sceneWallpaper", "");
    }

    function enterWallpaper(shown, scene) {
        if (scene.wallpaper === "")
            return;
        if (Saved.get("sceneWallpaper", "") === "")
            Saved.set("sceneWallpaper", shown);
        setWallpaper(scene.wallpaper);
    }

    function openApps(scene) {
        for (const name of words(scene.open)) {
            const entry = DesktopEntries.heuristicLookup(name);
            const running = Object.values(Niri.windows).some(w => String(w.app_id || "").toLowerCase().indexOf(name.toLowerCase()) >= 0);
            if (entry && !running)
                entry.execute();
            else if (!entry)
                Toasts.show(Tr.t("App not found"), name, "alert");
        }
    }

    // Pressing the scene that is on turns it off.
    function toggle(id) {
        const next = id === active ? null : list.find(s => s.id === id) || null;
        withWallpaper(shown => {
            leaveWallpaper(shown, next);
            active = next ? next.id : "";
            Saved.set("scene", active);
            if (next) {
                enterWallpaper(shown, next);
                openApps(next);
                Toasts.show(next.name, Tr.t("Scene is on"), next.icon);
            } else {
                Toasts.show(Tr.t("Scene is off"), "", "bell");
            }
        });
    }

    property var afterRead: null

    Process {
        id: wallpaperRead

        command: ["sh", "-c", 'cd "$HOME/.local/state/niri-desk" && { readlink wallpaper-live || readlink wallpaper; }']
        stdout: StdioCollector {
            onStreamFinished: {
                const done = root.afterRead;
                root.afterRead = null;
                if (done)
                    done(text.trim());
            }
        }
    }

    Component.onCompleted: active = Saved.get("scene", "")
}
