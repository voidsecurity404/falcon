pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit

// The session's polkit agent: asks for the password when an app needs root rights.
// Only one agent can serve a session, so hyprpolkitagent is stopped before ours registers,
// and started again if ours could not register, so a password prompt always exists.
Singleton {
    id: root

    property bool starting: true
    readonly property var agent: loader.item
    readonly property var flow: agent ? agent.flow : null
    readonly property bool active: !!agent && agent.isActive
    readonly property bool registered: !!agent && agent.isRegistered

    // The dialog is up from the request until its closing animation ends.
    property bool alive: false

    function submit(text) {
        if (flow)
            flow.submit(text);
    }

    function cancel() {
        if (flow)
            flow.cancelAuthenticationRequest();
    }

    onActiveChanged: {
        if (active)
            alive = true;
    }

    Process {
        running: true
        command: ["systemctl", "--user", "stop", "hyprpolkitagent.service"]
        onExited: root.starting = false
    }

    LazyLoader {
        id: loader

        active: !root.starting

        PolkitAgent {}
    }

    Timer {
        running: !root.starting
        interval: 4000
        onTriggered: {
            if (root.registered)
                return;
            console.warn("polkit: the shell's agent did not register, starting hyprpolkitagent");
            Quickshell.execDetached(["systemctl", "--user", "start", "hyprpolkitagent.service"]);
        }
    }
}
