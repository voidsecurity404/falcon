pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool available: !!sink && !!sink.audio
    readonly property real volume: available ? sink.audio.volume : 0
    readonly property bool muted: available ? sink.audio.muted : false
    readonly property int percent: Math.round(volume * 100)

    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool micAvailable: !!source && !!source.audio
    readonly property real micVolume: micAvailable ? source.audio.volume : 0
    readonly property bool micMuted: micAvailable ? source.audio.muted : false
    readonly property int micPercent: Math.round(micVolume * 100)

    property bool settled: false

    // Hearing protection: a sudden jump of the output volume, by an app or a newly chosen
    // device, is undone, and nothing goes above the set maximum. Changes made in the shell
    // itself (the slider) are allowed for a moment, since they are on purpose.
    readonly property bool protect: Settings.get("audio.protection", true)
    readonly property real maxStep: Math.max(0.05, Math.min(1, Settings.get("audio.maxStep", 0.15)))
    readonly property real maxVolume: Math.max(0.3, Math.min(1, Settings.get("audio.maxVolume", 1)))
    property real lastVolume: -1
    property real allowedVolume: -1
    property real allowedUntil: 0

    function setVolume(value) {
        if (!available)
            return;
        const v = Math.max(0, Math.min(protect ? maxVolume : 1, value));
        allowedVolume = v;
        allowedUntil = Date.now() + 1500;
        sink.audio.volume = v;
    }

    // True when it undid the change.
    function guard() {
        if (!available)
            return false;
        const v = sink.audio.volume;
        if (isNaN(v)) {
            lastVolume = -1;
            return false;
        }
        if (!protect || !settled || lastVolume < 0 || (Date.now() < allowedUntil && Math.abs(v - allowedVolume) < 0.011)) {
            lastVolume = protect ? Math.min(v, maxVolume) : v;
            if (protect && v > maxVolume + 0.005)
                sink.audio.volume = maxVolume;
            return false;
        }
        const back = Math.min(lastVolume, maxVolume);
        if (v > maxVolume + 0.005) {
            sink.audio.volume = back;
            Toasts.show(Tr.t("Volume kept down"), Tr.t("The maximum is {n}%").replace("{n}", Math.round(maxVolume * 100)), "volume");
            return true;
        } else if (v - lastVolume > maxStep + 0.005) {
            sink.audio.volume = back;
            Toasts.show(Tr.t("Sudden volume jump stopped"), Tr.t("Stayed at {n}%").replace("{n}", Math.round(back * 100)), "volume");
            return true;
        }
        lastVolume = v;
        return false;
    }

    function toggleMute() {
        if (available)
            sink.audio.muted = !sink.audio.muted;
    }

    function setMicVolume(value) {
        if (micAvailable)
            source.audio.volume = Math.max(0, Math.min(1, value));
    }

    function toggleMicMute() {
        if (micAvailable)
            source.audio.muted = !source.audio.muted;
    }

    function announce() {
        if (settled)
            Toasts.level("volume", muted ? Tr.t("Muted") : Tr.t("Volume") + " " + Math.round(volume * 100) + "%", muted ? 0 : volume, "volume");
    }

    onVolumeChanged: {
        if (!guard())
            announce();
    }
    onProtectChanged: lastVolume = available ? volume : -1
    onMutedChanged: announce()
    onAvailableChanged: {
        // A device that comes back (after sleep, for example) reports its volume again.
        settled = false;
        settle.restart();
    }

    // Ishga tushishdagi birinchi qiymat xabar sifatida chiqmasin.
    Timer {
        id: settle

        interval: 800
        onTriggered: {
            root.settled = root.available;
            root.lastVolume = root.available ? root.volume : -1;
        }
    }

    PwObjectTracker {
        objects: [root.sink, root.source].filter(n => !!n)
    }
}
