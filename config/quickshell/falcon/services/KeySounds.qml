pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Key press sounds through bin/falcon-keysounds. The player runs while `keysounds.enabled` is on,
// the root helper is set up (`ready`, its socket exists) and the profile has been cut. Turning it
// on downloads the recordings first when they are missing, and points to the one-time setup.
Singleton {
    id: root

    readonly property bool enabled: Settings.get("keysounds.enabled", false)
    readonly property string profile: Settings.get("keysounds.profile", "cherrymx-blue-pbt")
    readonly property real volume: Math.max(0.05, Math.min(1, Number(Settings.get("keysounds.volume", 0.6)) || 0.6))
    property bool setupDone: false
    property bool ready: false
    property var profiles: []
    readonly property bool preparing: prepareProc.running
    readonly property bool hasProfile: profiles.indexOf(profile) >= 0
    readonly property bool playing: player.running
    property bool told: false

    readonly property var names: ({
            "cherrymx-blue-pbt": "Cherry MX Blue",
            "cherrymx-brown-pbt": "Cherry MX Brown",
            "cherrymx-black-pbt": "Cherry MX Black",
            "cherrymx-red-abs": "Cherry MX Red",
            "topre-purple-hybrid-pbt": "Topre",
            "eg-crystal-purple": "Crystal Purple",
            "eg-oreo": "Oreo"
        })
    readonly property var ids: Object.keys(names)

    function refresh() {
        statusProc.running = true;
    }

    function openSetup() {
        Ui.settingsOpen = false;
        Quickshell.execDetached(["kitty", "--class", "falcon-install", "sh", "-c", '"$1" setup; echo; read -p "$2" x', "sh", Ui.binDir + "falcon-keysounds", Tr.t("Press Enter to close")]);
        recheck.restart();
    }

    function prepare() {
        if (!prepareProc.running)
            prepareProc.running = true;
    }

    // Plays a few presses of the profile, even before the setup.
    function preview(name) {
        if (profiles.indexOf(name || profile) < 0) {
            prepare();
            return;
        }
        Quickshell.execDetached([Ui.binDir + "falcon-keysounds", "test", name || profile, String(volume)]);
    }

    function check() {
        if (!enabled)
            return;
        if (profiles.length === 0) {
            prepare();
        } else if (!ready && !told) {
            told = true;
            Toasts.show(Tr.t("Key sounds need a one-time setup"), Tr.t("Click to set it up, it asks for your password"), "keyboard", () => root.openSetup());
        }
    }

    onEnabledChanged: {
        told = false;
        refresh();
    }
    onProfileChanged: {
        if (enabled && hasProfile)
            preview(profile);
    }
    Component.onCompleted: refresh()

    Process {
        id: statusProc

        command: [Ui.binDir + "falcon-keysounds", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const s = JSON.parse(text);
                    root.setupDone = !!s.setup;
                    root.ready = !!s.ready;
                    root.profiles = s.profiles || [];
                } catch (e) {}
                root.check();
            }
        }
    }

    Process {
        id: prepareProc

        command: [Ui.binDir + "falcon-keysounds", "prepare"]
        onRunningChanged: {
            if (running)
                Toasts.show(Tr.t("Getting key sounds"), Tr.t("Recordings of real switches, about 15 MB"), "keyboard");
        }
        onExited: code => {
            if (code !== 0)
                Toasts.show(Tr.t("Key sounds could not be downloaded"), Tr.t("Check the internet connection"), "keyboard");
            root.refresh();
        }
    }

    // After the setup window opens, the helper's socket is looked for a while.
    Timer {
        id: recheck

        property int left: 0

        interval: 2000
        repeat: true
        onRunningChanged: {
            if (running)
                left = 60;
        }
        onTriggered: {
            root.refresh();
            left -= 1;
            if (root.ready || left <= 0)
                stop();
        }
    }

    // The player. A change of profile or volume starts it again with the new values.
    Process {
        id: player

        readonly property bool wanted: root.enabled && root.ready && root.hasProfile
        readonly property var args: ["setpriv", "--pdeathsig", "KILL", Ui.binDir + "falcon-keysounds", "run", root.profile, String(root.volume)]

        command: args
        // Set by hand, never bound: the restart below would break a binding.
        onWantedChanged: running = wanted
        Component.onCompleted: running = wanted
        onArgsChanged: {
            if (running) {
                running = false;
                restart.restart();
            }
        }
        onExited: {
            if (wanted)
                restart.restart();
        }
    }
    Timer {
        id: restart

        interval: 400
        onTriggered: player.running = player.wanted
    }
}
