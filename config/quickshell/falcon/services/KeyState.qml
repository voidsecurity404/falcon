pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Caps Lock and the keyboard layout, shown in the level pill under the bar when they change
// (`keyboard.osd`). Wayland gives no Caps Lock state to clients, so the keyboards' capslock LEDs
// in sysfs are read (four times a second, one small file each; sysfs files cannot be watched).
// With `compose:caps` among the keyboard options the key is Compose and the LED never lights.
// A layout switched by niri's per-window layouts right after a focus change is not shown.
Singleton {
    id: root

    readonly property bool enabled: Settings.get("keyboard.osd", true) === true
    property var leds: []
    property bool caps: false
    property bool capsKnown: false
    property double focusMoved: 0
    property string lastLayout: ""

    function layoutName(name) {
        const n = (name || "").toLowerCase();
        if (n.startsWith("english"))
            return "English";
        if (n.startsWith("russian"))
            return "Русский";
        if (n.startsWith("uzbek"))
            return "O'zbekcha";
        return name || "";
    }

    onCapsChanged: {
        if (capsKnown && enabled)
            Toasts.badge("caps", caps ? Tr.t("Caps Lock on") : Tr.t("Caps Lock off"), "caps", caps);
    }

    Connections {
        target: Niri

        function onFocusedWindowIdChanged() {
            root.focusMoved = Date.now();
        }
        function onLayoutLabelChanged() {
            const label = Niri.layoutLabel;
            const before = root.lastLayout;
            root.lastLayout = label;
            if (before === "" || label === "" || !root.enabled)
                return;
            if (Settings.get("keyboard.perWindow", true) && Date.now() - root.focusMoved < 400)
                return;
            Toasts.badge("layout", root.layoutName(Niri.layoutNames[Niri.layoutIndex]), "keyboard", true, label);
        }
    }

    Component.onCompleted: lastLayout = Niri.layoutLabel

    // The keyboards' LEDs, listed again now and then for keyboards plugged in later.
    Process {
        id: lister

        running: root.enabled
        command: ["sh", "-c", "ls -d /sys/class/leds/*::capslock 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root.leds = text.split("\n").filter(l => l !== "").map(l => l + "/brightness")
        }
    }
    Timer {
        interval: 30000
        running: root.enabled
        repeat: true
        onTriggered: lister.running = true
    }

    Instantiator {
        model: root.enabled ? root.leds : []

        delegate: FileView {
            required property string modelData

            path: modelData
            blockLoading: true
        }
        onObjectAdded: (index, object) => root.views = root.views.concat([object])
        onObjectRemoved: (index, object) => root.views = root.views.filter(v => v !== object)
    }
    property var views: []

    Timer {
        interval: 250
        running: root.enabled && root.views.length > 0
        repeat: true
        onTriggered: {
            let on = false;
            for (const v of root.views) {
                v.reload();
                if (parseInt(v.text()) > 0)
                    on = true;
            }
            // The first reading only learns the state, so a shell start shows nothing.
            root.caps = on;
            root.capsKnown = true;
        }
    }
}
