pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Pictures pinned over the screen: the region selector's Pin action puts a cut of the screen here,
// and `modules/PinnedShots.qml` shows each as a card above the windows. Places are logical global
// coordinates. The files live in $XDG_RUNTIME_DIR/falcon-pins and go with their card, and the
// folder is emptied when the shell starts, since pins do not outlive the shell.
Singleton {
    id: root

    readonly property string dir: Quickshell.env("XDG_RUNTIME_DIR") + "/falcon-pins"
    readonly property int maxPins: 8
    // [{ id, path, x, y, w, h }]: w and h are the size the picture had on the screen.
    property var items: []
    property int nextId: 1

    function add(path, x, y, w, h) {
        if (w < 2 || h < 2)
            return;
        let list = items.slice();
        // The oldest pin gives way, so a forgotten pile cannot grow.
        while (list.length >= maxPins)
            Quickshell.execDetached(["rm", "-f", list.shift().path]);
        list.push({ id: nextId, path: path, x: x, y: y, w: w, h: h });
        nextId += 1;
        items = list;
    }

    function remove(id) {
        const pin = items.find(p => p.id === id);
        if (!pin)
            return;
        Quickshell.execDetached(["rm", "-f", pin.path]);
        items = items.filter(p => p.id !== id);
    }

    function clear() {
        for (const pin of items)
            Quickshell.execDetached(["rm", "-f", pin.path]);
        items = [];
    }

    function copy(id) {
        const pin = items.find(p => p.id === id);
        if (!pin)
            return;
        Quickshell.execDetached(["sh", "-c", 'wl-copy --type image/png < "$1"', "sh", pin.path]);
        Toasts.show(Tr.t("Copied"), Tr.t("The pinned picture is in the clipboard"), "copy");
    }

    function save(id) {
        const pin = items.find(p => p.id === id);
        if (pin)
            Ui.run("falcon-region", "save", pin.path);
    }

    Component.onCompleted: Quickshell.execDetached(["sh", "-c", 'rm -rf "$1"; mkdir -p "$1"', "sh", dir])
}
