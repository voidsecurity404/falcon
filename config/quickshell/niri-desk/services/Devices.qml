pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Other devices: KDE Connect, LocalSend, the phone camera, the tablet screen and mirroring.
// It looks only while its settings page is open, or once when something asks.
Singleton {
    id: root

    property bool watching: false
    property var extras: ({})
    property var phones: []
    property var camera: ({})
    property var sidecar: ({})
    property var mirror: ({})

    readonly property bool allInstalled: Object.keys(extras).length > 0 && extras.localsend && extras.kdeconnect && extras.scrcpy && extras.mirror && extras.restic && extras.wtype && extras.whisper && extras.wayvnc

    function refresh() {
        extrasRead.running = true;
        cameraRead.running = true;
        sidecarRead.running = true;
        mirrorRead.running = true;
        if (extras.kdeconnect)
            phonesRead.running = true;
    }

    function setup() {
        Quickshell.execDetached(["kitty", "--title", "niri-desk extras setup", "env", "PATH=" + Ui.binDir + ":" + Quickshell.env("PATH"), "sh", "-c", 'niri-desk-extras setup; printf "\\n%s " "$(niri-desk-tr "Press Enter to close.")"; read _']);
    }

    // Sends to a connected phone, otherwise opens LocalSend with the file.
    function share(path) {
        if (phones.length > 0) {
            Quickshell.execDetached(["kdeconnect-cli", "--device", phones[0].id, "--share", path]);
            Toasts.show(Tr.t("Sent to the phone"), phones[0].name, "phone");
        } else if (extras.localsend) {
            Quickshell.execDetached(["localsend_app", path]);
        } else {
            Toasts.show(Tr.t("Nothing to send with"), "niri-desk-extras setup", "alert");
        }
    }

    function openLocalSend() {
        if (extras.localsend)
            Quickshell.execDetached([Ui.binDir + "niri-desk-raise", "localsend", "localsend_app"]);
        else
            Toasts.show(Tr.t("LocalSend is not installed"), "niri-desk-extras setup", "alert");
    }

    function openPairing() {
        if (extras.kdeconnect)
            Quickshell.execDetached(["kdeconnect-app"]);
        else
            Toasts.show(Tr.t("KDE Connect is not installed"), "niri-desk-extras setup", "alert");
    }

    function ring(id) {
        Quickshell.execDetached(["kdeconnect-cli", "--device", id, "--ring"]);
    }

    function toggleTool(script) {
        Ui.run(script);
        again.restart();
    }

    function parseJson(text, fallback) {
        try {
            return JSON.parse(text);
        } catch (e) {
            return fallback;
        }
    }

    Component.onCompleted: extrasRead.running = true

    Timer {
        interval: 5000
        repeat: true
        triggeredOnStart: true
        running: root.watching
        onTriggered: root.refresh()
    }
    Timer {
        id: again

        interval: 2000
        onTriggered: root.refresh()
    }

    Process {
        id: extrasRead

        command: [Ui.binDir + "niri-desk-extras", "status"]
        stdout: StdioCollector {
            onStreamFinished: root.extras = root.parseJson(text, {})
        }
    }
    Process {
        id: cameraRead

        command: [Ui.binDir + "niri-desk-phonecam", "status"]
        stdout: StdioCollector {
            onStreamFinished: root.camera = root.parseJson(text, {})
        }
    }
    Process {
        id: sidecarRead

        command: [Ui.binDir + "niri-desk-sidecar", "status"]
        stdout: StdioCollector {
            onStreamFinished: root.sidecar = root.parseJson(text, {})
        }
    }
    Process {
        id: mirrorRead

        command: [Ui.binDir + "niri-desk-mirror", "status"]
        stdout: StdioCollector {
            onStreamFinished: root.mirror = root.parseJson(text, {})
        }
    }
    Process {
        id: phonesRead

        command: ["kdeconnect-cli", "--list-available", "--id-name-only"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.phones = text.split("\n").filter(l => l.trim() !== "").map(l => {
                    const gap = l.indexOf(" ");
                    return {
                        id: gap > 0 ? l.slice(0, gap) : l,
                        name: gap > 0 ? l.slice(gap + 1) : l
                    };
                });
            }
        }
    }
}
