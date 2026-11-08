pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// My phone: the tunnel state written by moy-telefon-link.service and the phone window of falcon-phone.
Singleton {
    id: root

    property var link: ({})
    // The panel item shows only once the tunnel has written its state at least once.
    property bool installed: false

    // "direct", "relay" or "offline"
    readonly property string state: link.state || "offline"
    readonly property int rtt: link.rtt || 0
    readonly property bool reachable: state !== "offline"
    readonly property bool windowOpen: Object.values(Niri.windows).some(w => w.title === "Мой телефон")

    readonly property string stateText: {
        if (state === "direct")
            return Tr.t("Connected directly, {ms} ms").replace("{ms}", rtt);
        if (state === "relay")
            return Tr.t("Connected through a relay, {ms} ms").replace("{ms}", rtt);
        return Tr.t("Phone is offline");
    }

    function toggle() {
        Quickshell.execDetached(["falcon-phone", "toggle"]);
    }

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/moy-telefon/link.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.link = JSON.parse(text());
                root.installed = true;
            } catch (e) {
                root.link = {};
            }
        }
        onLoadFailed: root.installed = false
    }
}
