pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Game mode, one switch for playing: niri's animations and shadows off (bin/falcon-game),
// the performance power mode, Silent, and an idle lock so a game played with a gamepad does not
// lock the screen. Only on the charger: on battery it refuses, and pulling the cable ends it.
// What it changed comes back when it ends: the power mode and Silent only if it switched them.
// The state is kept by Saved as `gameMode`, so it survives a shell restart.
Singleton {
    id: root

    property bool enabled: false
    property bool loaded: false
    // What was there before: { profile, dnd }.
    property var before: null
    // The power mode game mode chose, so ending it only undoes its own choice.
    property int ownProfile: -1

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
        Toasts.show(Tr.t("Game mode on"), Tr.t("No animations, full power, notifications wait"), "game");
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
            // A file left by a shell that died while on is cleared.
            Quickshell.execDetached([Ui.binDir + "falcon-game", "off"]);
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
