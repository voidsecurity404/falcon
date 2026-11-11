pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Which apps use the microphone and the camera, from bin/falcon-privacy.
Singleton {
    id: root

    readonly property bool enabled: BarLayout.has("privacy")
    property var mic: []
    property var camera: []

    function tell() {
        if (mic.length > 0)
            Toasts.show(Tr.t("Microphone in use"), mic.join(", "), Audio.micMuted ? "micOff" : "mic");
        if (camera.length > 0)
            Toasts.show(Tr.t("Camera in use"), camera.join(", ").replace(/^\?$/, Tr.t("Unknown app")), "camera");
    }

    onEnabledChanged: {
        if (!enabled) {
            mic = [];
            camera = [];
        }
    }

    Process {
        id: watcher

        command: [Ui.binDir + "falcon-privacy"]
        running: root.enabled && Settings.loaded
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => {
                try {
                    const s = JSON.parse(line);
                    root.mic = s.mic;
                    root.camera = s.camera;
                } catch (e) {}
            }
        }
        onExited: {
            // The icons must not stay lit, or stay dark, on a watcher that died.
            root.mic = [];
            root.camera = [];
            if (root.enabled)
                retry.restart();
        }
    }
    Timer {
        id: retry

        interval: 5000
        onTriggered: watcher.running = root.enabled
    }
}
