pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Sound levels for the music tab and the desktop waves. Listens only while one of them is on screen and something is playing.
Singleton {
    id: root

    readonly property int count: 36
    // Screens where the desktop waves can be seen right now.
    property var watching: ({})
    readonly property bool wanted: Object.keys(watching).length > 0 && !!Media.player && Media.player.isPlaying
    property var levels: []

    function setWatching(screen, on) {
        const next = Object.assign({}, watching);
        if (on)
            next[screen] = true;
        else
            delete next[screen];
        watching = next;
    }

    Process {
        running: root.wanted
        command: ["falcon-spectrum"]
        stdout: SplitParser {
            onRead: line => root.levels = line.split(" ").map(Number)
        }
        onRunningChanged: {
            if (!running)
                root.levels = [];
        }
    }
}
