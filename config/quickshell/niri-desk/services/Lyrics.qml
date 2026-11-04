pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Live subtitles. Recognition runs only while the music tab is open and something is playing.
Singleton {
    id: root

    property string status: "idle"
    property string partial: ""
    property string language: ""
    property string message: ""

    signal lineAdded(string text)
    signal cleared

    readonly property var player: Media.player
    readonly property string track: player ? player.trackTitle + "|" + player.trackArtist : ""
    readonly property bool wanted: Ui.popup === "dashboard" && Ui.dashTab === 1 && !!player && player.isPlaying

    onTrackChanged: clear()

    function clear() {
        partial = "";
        language = "";
        cleared();
    }

    Process {
        running: root.wanted
        command: ["sh", "-c", 'exec "$HOME/.local/share/niri-desk/lyrics-venv/bin/python" -I "$HOME/.local/bin/niri-desk-lyrics" "$1"', "sh", root.player ? root.player.trackTitle + " " + root.player.trackArtist : ""]
        stdout: SplitParser {
            onRead: line => {
                let data;
                try {
                    data = JSON.parse(line);
                } catch (e) {
                    return;
                }
                if (data.status) {
                    root.status = data.status;
                    root.message = data.message || "";
                }
                if (data.language)
                    root.language = data.language;
                if (data.partial !== undefined)
                    root.partial = data.partial;
                if (data.line) {
                    root.partial = "";
                    root.lineAdded(data.line);
                }
            }
        }
        onRunningChanged: {
            if (running)
                root.status = "loading";
            else if (root.status === "listening" || root.status === "loading")
                root.status = "idle";
        }
        onExited: code => {
            // 127: the recognition environment is not installed.
            if (code === 127)
                root.status = "missing";
        }
    }
}
