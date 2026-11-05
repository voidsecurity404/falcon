pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Sound levels for the music tab. Listens only while that tab is open and something is playing.
Singleton {
    id: root

    readonly property int count: 36
    readonly property bool wanted: Ui.popup === "dashboard" && Ui.dashTab === 1 && !!Media.player && Media.player.isPlaying
    property var levels: []

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
