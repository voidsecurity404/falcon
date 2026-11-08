pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Names the song that is playing, through bin/falcon-songrec (songrec, Shazam). It listens
// for 10 seconds, and the answer comes as a toast that opens the song's page on a click.
Singleton {
    id: root

    readonly property bool running: proc.running
    // True from the moment the script really records until it answers.
    property bool listening: false
    property bool fromMic: false
    // The last song found: { title, artist, url, cover }.
    property var last: null

    function recognize(mic) {
        if (proc.running)
            return;
        fromMic = !!mic;
        answered = false;
        proc.command = [Ui.binDir + "falcon-songrec"].concat(mic ? ["--mic"] : []);
        proc.running = true;
    }

    property bool answered: false

    function line(text) {
        let answer = null;
        try {
            answer = JSON.parse(text);
        } catch (e) {
            return;
        }
        if (answer.state === "listening") {
            listening = true;
            Toasts.show(Tr.t("Listening…"), fromMic ? Tr.t("Naming the song from the microphone") : Tr.t("Naming the song that plays on the computer"), "music");
            return;
        }
        answered = true;
        listening = false;
        handle(answer);
    }

    function handle(answer) {
        if (answer.error === "missing") {
            Toasts.show(Tr.t("Song recognition needs songrec"), Tr.t("Click to install it"), "music", () => Quickshell.execDetached(["kitty", "--class", "falcon-install", "sh", "-c", "sudo pacman -S --needed songrec; echo; read -p '" + Tr.t("Press Enter to close") + "' x"]));
        } else if (answer.error === "silent") {
            Toasts.show(Tr.t("Nothing is playing"), Tr.t("Play the song and try again"), "music");
        } else if (answer.error === "unknown") {
            Toasts.show(Tr.t("Song not found"), Tr.t("Shazam does not know it, or it was too quiet"), "music");
        } else if (answer.error || !answer.title) {
            Toasts.show(Tr.t("Could not name the song"), Tr.t("Check the internet connection"), "music");
        } else {
            last = answer;
            Toasts.show(answer.title, answer.artist, "music", answer.url ? () => Qt.openUrlExternally(answer.url) : null);
        }
    }

    Process {
        id: proc

        stdout: SplitParser {
            onRead: data => root.line(data)
        }
        // The last line can arrive just after the exit, so the check waits a moment.
        onExited: lateCheck.restart()
    }
    Timer {
        id: lateCheck

        interval: 300
        onTriggered: {
            root.listening = false;
            if (!root.answered && !proc.running)
                root.handle({ error: "failed" });
        }
    }
}
