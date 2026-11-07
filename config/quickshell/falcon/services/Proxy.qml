pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The system proxy, run by bin/falcon-proxy as its own system service, so it does not end with the
// shell. The switch shows what the service really does. The saved wish brings it back after a reboot.
Singleton {
    id: root

    property bool ready: false
    property bool hasLink: false
    property bool active: false
    property bool wanted: false
    property bool restoreChecked: false
    readonly property bool busy: action.running

    function refresh() {
        status.running = true;
    }

    function run(verb) {
        action.verb = verb;
        action.command = [Ui.binDir + "falcon-proxy", verb];
        action.running = true;
    }

    function runSetup() {
        Quickshell.execDetached(["kitty", "--title", "falcon proxy setup", "env", "PATH=" + Ui.binDir + ":" + Quickshell.env("PATH"), "sh", "-c", 'falcon-proxy setup; printf "\\n%s " "$(falcon-tr "Press Enter to close.")"; read _']);
    }

    function toggle() {
        if (busy)
            return;
        if (!ready) {
            Ui.popup = "";
            runSetup();
            return;
        }
        run(active ? "off" : "on");
    }

    Component.onCompleted: {
        wanted = Saved.get("proxy", false);
        refresh();
    }

    Process {
        id: status

        command: [Ui.binDir + "falcon-proxy", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const s = JSON.parse(text);
                    root.ready = s.ready;
                    root.hasLink = s.link;
                    root.active = s.active;
                } catch (e) {
                    return;
                }
                // Only once, after a start. A network that is not up yet must not undo the wish.
                if (!root.restoreChecked) {
                    root.restoreChecked = true;
                    if (root.wanted && !root.active && root.ready && root.hasLink)
                        root.run("start");
                }
            }
        }
    }
    Process {
        id: action

        property string verb: ""

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "")
                    Toasts.show(Tr.t("Proxy"), text.trim().split("\n")[0], "shield");
            }
        }
        onExited: code => {
            if (verb !== "start" && (code === 0 || verb === "on")) {
                root.wanted = verb === "on" && code === 0;
                Saved.set("proxy", root.wanted);
            }
            if (code === 0 && verb === "on")
                Toasts.show(Tr.t("Proxy on"), Tr.t("All traffic goes through the proxy"), "shield");
            else if (code === 0 && verb === "off")
                Toasts.show(Tr.t("Proxy off"), Tr.t("The connection is direct"), "shield");
            root.refresh();
        }
    }
    // Notices a service that stopped by itself, and looks only while it should be running.
    Timer {
        interval: 10000
        repeat: true
        running: root.wanted || root.active
        onTriggered: root.refresh()
    }
}
