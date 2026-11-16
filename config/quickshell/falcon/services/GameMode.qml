pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Game mode, one switch for playing: niri's animations, shadows and hot corner off
// (bin/falcon-game), the performance power mode, Silent, and an idle lock so a game played with a
// gamepad does not lock the screen. It also clears the computer for the game, each part by its own
// switch in Settings (`game.*`): every other app is asked to close, the widgets and the music
// waves leave the desktop, the wallpaper (a live one's player too) gives way to black, and the
// shell's background helpers wait. Only on the charger: on battery it refuses, and pulling the
// cable ends it. What it changed comes back when it ends: the power mode and Silent only if it
// switched them, the wallpaper, the widgets and the helpers always; closed apps stay closed.
// The state is kept by Saved as `gameMode`, so it survives a shell restart.
Singleton {
    id: root

    property bool enabled: false
    property bool loaded: false
    // What was there before: { profile, dnd }.
    property var before: null
    // The power mode game mode chose, so ending it only undoes its own choice.
    property int ownProfile: -1
    // The parts that clear the computer. Read only once the settings are in: at a shell restart
    // the defaults would otherwise switch a part on for a moment that the user turned off.
    readonly property bool hidesWidgets: enabled && Settings.loaded && Settings.get("game.hideWidgets", true)
    readonly property bool black: enabled && Settings.loaded && Settings.get("game.blackBackground", true)
    readonly property bool quiet: enabled && Settings.loaded && Settings.get("game.pauseServices", true)

    onBlackChanged: Quickshell.execDetached([Ui.binDir + "falcon-game", "black", black ? "on" : "off"])
    onQuietChanged: Quickshell.execDetached([Ui.binDir + "falcon-game", "services", quiet ? "stop" : "start"])

    function toggle() {
        if (enabled)
            stop(true);
        else
            start();
    }

    function start() {
        if (enabled)
            return;
        if (UPower.onBattery) {
            Toasts.show(Tr.t("Game mode needs the charger"), Tr.t("On battery it would only drain it faster"), "game");
            return;
        }
        before = {
            profile: PowerProfiles.profile,
            dnd: Toasts.doNotDisturb
        };
        enabled = true;
        apply();
        // The shell's own windows and menus go first, then everyone else's.
        Ui.popup = "";
        Ui.settingsOpen = false;
        if (Settings.get("game.closeApps", true)) {
            closer.command = [Ui.binDir + "falcon-game", "close", "--keep", String(Settings.get("game.keep", ""))];
            closer.running = true;
        }
        Toasts.show(Tr.t("Game mode on"), Tr.t("Everything else is off, full power for the game"), "game");
    }

    // `restore` is false when the cable was pulled: the battery's own power mode takes over then.
    function stop(restore) {
        if (!enabled)
            return;
        enabled = false;
        Quickshell.execDetached([Ui.binDir + "falcon-game", "off"]);
        const old = before || {};
        if (restore && old.profile !== undefined && PowerProfiles.profile === ownProfile)
            PowerProfiles.profile = old.profile;
        ownProfile = -1;
        if (old.dnd === false)
            Toasts.doNotDisturb = false;
        before = null;
        save();
        Toasts.show(Tr.t("Game mode off"), restore ? Tr.t("Everything is back as it was") : Tr.t("The charger was unplugged"), "game");
    }

    function apply() {
        Quickshell.execDetached([Ui.binDir + "falcon-game", "on"]);
        ownProfile = PowerProfiles.hasPerformanceProfile ? PowerProfile.Performance : PowerProfile.Balanced;
        PowerProfiles.profile = ownProfile;
        Toasts.doNotDisturb = true;
        save();
    }

    function save() {
        if (loaded)
            Saved.set("gameMode", enabled ? { on: true, profile: before ? before.profile : PowerProfile.Balanced, dnd: before ? before.dnd : false } : null);
    }

    // The battery and the power modes arrive after the shell starts, so a saved game mode is
    // taken up again a moment later; it holds the idle lock meanwhile.
    Component.onCompleted: {
        const kept = Saved.get("gameMode", null);
        loaded = true;
        if (kept && kept.on) {
            before = { profile: kept.profile, dnd: kept.dnd };
            enabled = true;
            resume.start();
        } else {
            // What a shell that died while on left behind is cleared: the niri file, the black
            // wallpaper and the stopped helpers (the last two do nothing without their marks).
            Quickshell.execDetached([Ui.binDir + "falcon-game", "off"]);
            Quickshell.execDetached([Ui.binDir + "falcon-game", "black", "off"]);
            Quickshell.execDetached([Ui.binDir + "falcon-game", "services", "start"]);
        }
    }

    Timer {
        id: resume

        interval: 2500
        onTriggered: {
            if (!root.enabled)
                return;
            // The niri file is still there; the power mode and Silent are set again in case they moved.
            if (UPower.onBattery)
                root.stop(false);
            else
                root.apply();
        }
    }

    Connections {
        target: UPower

        // A loose cable that comes back within 3 s changes nothing, as in Power.
        function onOnBatteryChanged() {
            if (UPower.onBattery && root.enabled)
                unplugged.restart();
            else
                unplugged.stop();
        }
    }
    Timer {
        id: unplugged

        interval: 3000
        onTriggered: {
            if (UPower.onBattery)
                root.stop(false);
        }
    }

    // Other apps are closed once, when game mode is switched on by hand: never when a restarted
    // shell takes it up again, which would close what was opened on purpose meanwhile.
    Process {
        id: closer

        stdout: StdioCollector {
            onStreamFinished: {
                let report;
                try {
                    report = JSON.parse(text);
                } catch (e) {
                    return;
                }
                const count = (report.closed || []).length;
                if (count > 0)
                    console.log("Game mode closed", count, "windows:", report.closed.join(", "));
            }
        }
    }

    Process {
        id: lock

        // Like Caffeine's: the child waits on a pipe from the shell, so nothing stays behind.
        command: ["systemd-inhibit", "--what=idle", "--who=falcon", "--why=Game mode", "--mode=block", "sh", "-c", "cat >/dev/null"]
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
