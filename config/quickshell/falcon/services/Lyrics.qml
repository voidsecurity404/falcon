pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Lyrics of the song that plays, from LRCLIB through bin/falcon-lyrics. Asked only while the
// music tab shows them, once per song (the script keeps answers on disk). Timed lyrics follow
// the player's position, read every 150 ms while they are on screen.
Singleton {
    id: root

    // Saved choice of the music tab: lyrics in place of the big title.
    property bool shown: false
    readonly property bool wanted: shown && Spectrum.musicTab && !!Media.player
    // idle, loading, synced, plain, instrumental, none, offline
    property string status: "idle"
    // [[seconds, text], ...] for synced, [[-1, text], ...] for plain.
    property var lines: []
    property int current: -1
    readonly property string key: {
        const p = Media.player;
        return p ? (p.trackArtist + "\n" + Media.title + "\n" + Math.round(p.lengthSupported ? p.length : 0)) : "";
    }
    property string loadedKey: ""

    function setShown(value) {
        shown = value;
        Saved.set("lyrics", value);
    }

    function lineAt(seconds) {
        // Last line whose time has come; a little early, so a line lights as it is sung.
        const t = seconds + 0.25;
        let low = 0, high = lines.length - 1, found = -1;
        while (low <= high) {
            const mid = (low + high) >> 1;
            if (lines[mid][0] <= t) {
                found = mid;
                low = mid + 1;
            } else {
                high = mid - 1;
            }
        }
        return found;
    }

    function seekTo(index) {
        const p = Media.player;
        if (status !== "synced" || !p || !p.canSeek || index < 0 || index >= lines.length)
            return;
        p.position = lines[index][0];
        current = index;
    }

    function load() {
        if (!wanted || key === "" || key === loadedKey)
            return;
        loadedKey = key;
        lines = [];
        current = -1;
        const p = Media.player;
        if (!Media.title) {
            status = "none";
            return;
        }
        status = "loading";
        proc.running = false;
        proc.command = [Ui.binDir + "falcon-lyrics", p.trackArtist || "", Media.title, String(p.lengthSupported ? p.length : 0)];
        proc.forKey = key;
        proc.running = true;
    }

    function take(text, forKey) {
        if (forKey !== loadedKey)
            return;
        let answer = null;
        try {
            answer = JSON.parse(text);
        } catch (e) {
            status = "offline";
            return;
        }
        if (answer.synced) {
            lines = answer.synced;
            status = "synced";
            tick();
        } else if (answer.plain) {
            lines = answer.plain.map(t => [-1, t]);
            status = "plain";
        } else if (answer.instrumental) {
            status = "instrumental";
        } else {
            status = answer.error === "offline" ? "offline" : "none";
        }
    }

    function tick() {
        const p = Media.player;
        if (status !== "synced" || !p)
            return;
        p.positionChanged();
        current = lineAt(p.position);
    }

    Component.onCompleted: shown = Saved.get("lyrics", false)

    onWantedChanged: load()
    onKeyChanged: {
        // The old song's lines go at once, the new ones come after the pause.
        if (wanted && key !== loadedKey) {
            lines = [];
            current = -1;
            status = "loading";
        }
        debounce.restart();
    }

    Timer {
        id: debounce

        // A new song: the title and the artist arrive in separate signals.
        interval: 400
        onTriggered: root.load()
    }
    // An offline miss is asked again when the tab opens later.
    Connections {
        target: Spectrum
        function onMusicTabChanged() {
            if (Spectrum.musicTab && root.status === "offline")
                root.loadedKey = "";
            root.load();
        }
    }
    Timer {
        interval: 150
        repeat: true
        running: root.wanted && root.status === "synced"
        onTriggered: root.tick()
    }

    Process {
        id: proc

        property string forKey: ""

        stdout: StdioCollector {
            onStreamFinished: root.take(text.trim(), proc.forKey)
        }
        onExited: code => {
            if (code !== 0 && root.status === "loading" && proc.forKey === root.loadedKey)
                root.status = "offline";
        }
    }
}
