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

    function setVolume(value) {
        if (available)
            sink.audio.volume = Math.max(0, Math.min(1, value));
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

    onVolumeChanged: announce()
    onMutedChanged: announce()
    onAvailableChanged: settle.restart()

    // Ishga tushishdagi birinchi qiymat xabar sifatida chiqmasin.
    Timer {
        id: settle

        interval: 800
        onTriggered: root.settled = root.available
    }

    PwObjectTracker {
        objects: [root.sink, root.source].filter(n => !!n)
    }
}
