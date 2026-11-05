pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Pinned clipboard rows, kept as copies of their own, so they outlive the history and "cliphist wipe".
Singleton {
    id: root

    readonly property int maxPins: 6
    readonly property string dir: Ui.home + "/.local/state/falcon/clip-pins"
    // [{file, text, image}]
    property var pins: []
    property var pending: null

    function isPinnedText(text) {
        return pins.some(p => p.text === text);
    }

    function pin(clip) {
        if (isPinnedText(clip.text) || pending)
            return;
        if (pins.length >= maxPins) {
            Toasts.show(Tr.t("Pinned list is full"), Tr.t("Unpin something first"), "alert");
            return;
        }
        pending = {
            file: String(Date.now()),
            text: clip.text,
            image: clip.image
        };
        keep.command = ["sh", "-c", 'umask 077; mkdir -p "$1" && cliphist decode "$2" > "$1/$3" && [ -s "$1/$3" ] || { rm -f "$1/$3"; exit 1; }', "sh", dir, clip.id, pending.file];
        keep.running = true;
    }

    function unpin(file) {
        pins = pins.filter(p => p.file !== file);
        Saved.set("clipPins", pins);
        // Only a name this service made: digits, so it can never leave the folder.
        if (/^\d+$/.test(file))
            Quickshell.execDetached(["rm", "-f", dir + "/" + file]);
    }

    function copy(pinItem) {
        Quickshell.execDetached(["sh", "-c", 'wl-copy < "$1"', "sh", dir + "/" + pinItem.file]);
    }

    Component.onCompleted: pins = Saved.get("clipPins", [])

    Process {
        id: keep

        onExited: code => {
            const item = root.pending;
            root.pending = null;
            if (code === 0 && item) {
                root.pins = root.pins.concat([item]);
                Saved.set("clipPins", root.pins);
            } else {
                Toasts.show(Tr.t("Could not pin"), Tr.t("This row is no longer in the history"), "alert");
            }
        }
    }
}
