pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Battery care. The charge limit lives in the firmware through bin/falcon-charge, and the power
// mode follows the charger, only when the charger really changes, so a mode chosen by hand stays.
Singleton {
    id: root

    property bool chargeSupported: false
    property bool chargeWritable: false
    property int chargeActual: 0
    // The firmware may keep another value than the one asked for. It is not asked again for that one.
    property int settledWanted: -1

    readonly property bool limitOn: Settings.get("power.chargeLimitOn", false)
    readonly property int limitValue: Math.max(50, Math.min(100, Number(Settings.get("power.chargeLimit", 80)) || 80))
    readonly property int wantedLimit: limitOn ? limitValue : 100
    readonly property bool needsSetup: chargeSupported && !chargeWritable
    readonly property bool aboveLimit: limitOn && chargeSupported && Sys.batteryPercent > limitValue

    readonly property bool autoOn: Settings.get("power.auto", true)
    readonly property bool onBattery: UPower.onBattery
    readonly property string sourceNow: onBattery ? "battery" : "charger"
    property bool started: false

    function refresh() {
        status.running = true;
    }

    function openSetup() {
        Ui.settingsPage = Ui.pagePower;
        Ui.settingsOpen = true;
    }

    function runSetup() {
        Quickshell.execDetached(["kitty", "--title", "falcon charge setup", "env", "PATH=" + Ui.binDir + ":" + Quickshell.env("PATH"), "sh", "-c", 'falcon-charge setup; qs -c falcon ipc call desk powerRefresh >/dev/null 2>&1; printf "\\n%s " "$(falcon-tr "Press Enter to close.")"; read _']);
    }

    function toggleLimit() {
        if (needsSetup) {
            openSetup();
            return;
        }
        Settings.set("power.chargeLimitOn", !limitOn);
    }

    function profileOf(name) {
        if (name === "power-saver")
            return PowerProfile.PowerSaver;
        if (name === "performance" && PowerProfiles.hasPerformanceProfile)
            return PowerProfile.Performance;
        return PowerProfile.Balanced;
    }

    function applyProfile(tell) {
        const wanted = profileOf(Settings.get(onBattery ? "power.onBattery" : "power.onCharger", "balanced"));
        if (PowerProfiles.profile !== wanted) {
            PowerProfiles.profile = wanted;
            if (tell)
                Toasts.show(onBattery ? Tr.t("On battery") : Tr.t("On the charger"), nameOf(wanted), "charging");
        }
    }

    function nameOf(profile) {
        return profile === PowerProfile.PowerSaver ? Tr.t("Saver") : profile === PowerProfile.Performance ? Tr.t("Performance") : Tr.t("Balanced");
    }

    // A change while the shell was not running, or across a reboot, counts. A restart with the same
    // source does not, so it never overrides a mode chosen by hand.
    function sourceSettled() {
        if (!Sys.hasBattery)
            return;
        const last = Saved.get("powerSource", "");
        Saved.set("powerSource", sourceNow);
        if (last !== "" && last !== sourceNow && autoOn)
            applyProfile(true);
    }

    onSourceNowChanged: {
        if (started)
            sourceDelay.restart();
    }
    onAutoOnChanged: {
        if (started && autoOn && Sys.hasBattery)
            applyProfile(true);
    }
    onWantedLimitChanged: limitDelay.restart()

    Timer {
        // Waits for the battery and the settings, which arrive after the first frame.
        interval: 2500
        running: Settings.loaded
        onTriggered: {
            root.started = true;
            root.sourceSettled();
            root.refresh();
        }
    }

    // A loose cable or a dock waking up must not switch back and forth.
    Timer {
        id: sourceDelay

        interval: 3000
        onTriggered: root.sourceSettled()
    }

    Timer {
        id: limitDelay

        interval: 500
        onTriggered: root.syncLimit()
    }

    // Firmware may forget the limit across sleep, and this also notices the setup being done.
    Timer {
        interval: 60000
        repeat: true
        running: root.started
        onTriggered: root.refresh()
    }

    function syncLimit() {
        if (!started || !chargeSupported || !chargeWritable || chargeActual === wantedLimit || settledWanted === wantedLimit)
            return;
        setter.command = [Ui.binDir + "falcon-charge", "set", String(wantedLimit)];
        setter.running = true;
    }

    Process {
        id: status

        command: [Ui.binDir + "falcon-charge", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const s = JSON.parse(text);
                    root.chargeSupported = s.supported;
                    root.chargeWritable = s.writable;
                    root.chargeActual = s.limit;
                    root.syncLimit();
                } catch (e) {
                    root.chargeSupported = false;
                }
            }
        }
    }

    Process {
        id: setter

        property int asked: 0

        onRunningChanged: {
            if (running)
                asked = root.wantedLimit;
        }
        stdout: StdioCollector {
            onStreamFinished: {
                let r = {};
                try {
                    r = JSON.parse(text);
                } catch (e) {}
                root.settledWanted = setter.asked;
                if (r.limit !== undefined)
                    root.chargeActual = r.limit;
                if (r.ok && r.limit !== r.wanted)
                    Toasts.show(Tr.t("Battery charge limit"), Tr.t("The firmware chose {n}%").replace("{n}", r.limit), "alert");
                else if (!r.ok && r.reason === "refused")
                    Toasts.show(Tr.t("Battery charge limit"), Tr.t("The firmware refused {n}%").replace("{n}", setter.asked), "alert");
                root.refresh();
            }
        }
    }
}
