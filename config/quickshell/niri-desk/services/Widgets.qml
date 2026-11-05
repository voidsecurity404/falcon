pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Desktop widgets: which ones, where and how large. Stored in ~/.config/niri-desk/widgets.json.
// Places are fractions of the free screen area, so a layout survives another resolution.
Singleton {
    id: root

    readonly property var catalog: [
        {
            type: "clock",
            title: Tr.t("Clock"),
            icon: "clock",
            w: 560,
            h: 190,
            plate: false
        },
        {
            type: "analog",
            title: Tr.t("Analog clock"),
            icon: "clock",
            w: 190,
            h: 190,
            plate: true
        },
        {
            type: "calendar",
            title: Tr.t("Calendar"),
            icon: "calendar",
            w: 258,
            h: 268,
            plate: true
        },
        {
            type: "weather",
            title: Tr.t("Weather"),
            icon: "sun",
            w: 240,
            h: 130,
            plate: true
        },
        {
            type: "system",
            title: Tr.t("System"),
            icon: "system",
            w: 380,
            h: 250,
            plate: true
        },
        {
            type: "music",
            title: Tr.t("Music"),
            icon: "music",
            w: 400,
            h: 150,
            plate: true,
            interactive: true
        },
        {
            type: "claude",
            title: Tr.t("Claude limits"),
            icon: "sparkle",
            w: 290,
            h: 158,
            plate: true
        },
        {
            type: "notes",
            title: Tr.t("Notes"),
            icon: "note",
            w: 290,
            h: 230,
            plate: true,
            interactive: true
        }
    ]
    readonly property var sizes: ({
            s: 0.85,
            m: 1,
            l: 1.2
        })
    readonly property var defaults: [
        {
            id: "clock",
            type: "clock",
            fx: 0.02,
            fy: 0.97,
            size: "m"
        },
        {
            id: "calendar",
            type: "calendar",
            fx: 0.985,
            fy: 0.02,
            size: "m"
        },
        {
            id: "system",
            type: "system",
            fx: 0.985,
            fy: 0.5,
            size: "m"
        },
        {
            id: "music",
            type: "music",
            fx: 0.985,
            fy: 0.97,
            size: "m"
        },
        {
            id: "weather",
            type: "weather",
            fx: 0.02,
            fy: 0.02,
            size: "m"
        }
    ]

    property var items: []
    // Delegates follow this list, so moving a widget does not rebuild it.
    property var ids: []
    property bool loaded: false
    property bool restacking: false
    property bool editMode: false
    property bool noteHovered: false
    property bool noteFocused: false
    property var rects: ({})
    // The widget whose clickable copy is showing: its face hides, so nothing is drawn twice.
    property string hoverId: ""
    // Screens where widgets are being drawn right now.
    property var liveScreens: ({})
    readonly property bool shownNow: Object.keys(liveScreens).length > 0
    // True while niri slides workspaces: the clickable copies step aside, the faces stay put.
    property bool sliding: false

    readonly property bool enabled: Settings.get("widgets.enabled", true)
    readonly property bool firstOnly: Settings.get("widgets.firstOnly", false)
    readonly property real glass: Settings.get("widgets.opacity", 0.5)
    readonly property bool musicLive: (shownNow || editMode) && hasType("music")
    readonly property bool systemLive: (shownNow || editMode) && hasType("system")
    readonly property string notePath: Quickshell.env("HOME") + "/.config/niri-desk/note.txt"

    function setLive(screen, live) {
        const next = Object.assign({}, liveScreens);
        if (live)
            next[screen] = true;
        else
            delete next[screen];
        liveScreens = next;
    }

    function hasType(type) {
        return items.some(w => w.type === type);
    }

    function info(type) {
        return catalog.find(c => c.type === type) || null;
    }

    function get(id) {
        return items.find(w => w.id === id) || null;
    }

    function factor(size) {
        return sizes[size] || 1;
    }

    function validated(list) {
        if (!Array.isArray(list))
            return null;
        const seen = {};
        const out = [];
        for (const w of list) {
            if (!w || !info(w.type) || typeof w.id !== "string" || seen[w.id])
                continue;
            seen[w.id] = true;
            out.push({
                id: w.id,
                type: w.type,
                fx: Math.max(0, Math.min(1, Number(w.fx) || 0)),
                fy: Math.max(0, Math.min(1, Number(w.fy) || 0)),
                size: sizes[w.size] ? w.size : "m"
            });
        }
        return out;
    }

    function apply(list, save) {
        items = list;
        const next = list.map(w => w.id);
        if (JSON.stringify(next) !== JSON.stringify(ids))
            ids = next;
        if (save)
            file.setText(JSON.stringify(list, null, 1) + "\n");
    }

    function update(id, change) {
        apply(items.map(w => w.id === id ? Object.assign({}, w, change) : w), true);
    }

    function move(id, fx, fy) {
        update(id, {
            fx: Math.max(0, Math.min(1, fx)),
            fy: Math.max(0, Math.min(1, fy))
        });
    }

    function cycleSize(id) {
        const w = get(id);
        if (w)
            update(id, {
                size: w.size === "s" ? "m" : w.size === "m" ? "l" : "s"
            });
    }

    function add(type) {
        let n = 1;
        while (get(type + (n > 1 ? "-" + n : "")))
            n++;
        apply(items.concat([
            {
                id: type + (n > 1 ? "-" + n : ""),
                type: type,
                fx: 0.5,
                fy: 0.4,
                size: "m"
            }
        ]), true);
    }

    function remove(id) {
        apply(items.filter(w => w.id !== id), true);
    }

    function reset() {
        apply(defaults, true);
    }

    // Moves the widgets to the calm parts of a new wallpaper. The newest request wins.
    function arrange(image) {
        if (!enabled || !loaded || editMode || items.length === 0)
            return;
        if (placer.running) {
            pendingImage = image;
            return;
        }
        const screen = Quickshell.screens.find(s => s.name === Niri.focusedOutput) || Quickshell.screens[0];
        if (!screen)
            return;
        const top = Settings.bottom ? 16 : 56;
        const bottom = Settings.bottom ? 56 : 16;
        const spanX = screen.width - 32;
        const spanY = screen.height - bottom - top;
        const list = items.map(w => {
            const i = info(w.type);
            const width = i.w * factor(w.size);
            const height = i.h * factor(w.size);
            return {
                id: w.id,
                w: width,
                h: height,
                x: 16 + w.fx * Math.max(0, spanX - width),
                y: top + w.fy * Math.max(0, spanY - height),
                bare: !i.plate
            };
        });
        placer.sizes = list;
        placer.spanX = spanX;
        placer.spanY = spanY;
        placer.top = top;
        placer.command = [Ui.binDir + "niri-desk-widgets-place", image, String(screen.width), String(screen.height), String(top), String(bottom), JSON.stringify(list)];
        placer.running = true;
    }

    function takePlaces(text) {
        let places = null;
        try {
            places = JSON.parse(text);
        } catch (e) {
            return;
        }
        if (Object.keys(places).length === 0)
            return;
        apply(items.map(w => {
            const place = places[w.id];
            const size = placer.sizes.find(s => s.id === w.id);
            if (!place || !size)
                return w;
            return Object.assign({}, w, {
                fx: Math.max(0, Math.min(1, (place.x - 16) / Math.max(1, placer.spanX - size.w))),
                fy: Math.max(0, Math.min(1, (place.y - placer.top) / Math.max(1, placer.spanY - size.h)))
            });
        }), true);
    }

    function setRect(id, x, y, w, h) {
        const next = Object.assign({}, rects);
        next[id] = {
            x: Math.round(x),
            y: Math.round(y),
            w: Math.round(w),
            h: Math.round(h)
        };
        rects = next;
    }

    onEditModeChanged: {
        if (editMode)
            Ui.popup = "";
    }

    Timer {
        id: slideEnd

        interval: 520
        onTriggered: root.sliding = false
    }
    Connections {
        target: Niri
        function onWorkspacesChanged() {
            const active = Niri.workspaces.filter(w => w.is_active).map(w => w.id).join();
            if (active !== root.lastActive) {
                root.lastActive = active;
                root.sliding = true;
                slideEnd.restart();
            }
        }
    }
    // Keyin ochilgan jonli fon vidjetlarni yopib qo'yadi: ko'rinadigan qatlamni qayta ochib, ustiga chiqaramiz.
    function restack() {
        restacking = true;
        restackTimer.restart();
    }
    Timer {
        id: restackTimer

        interval: 120
        onTriggered: root.restacking = false
    }

    property string lastActive: ""
    property string pendingImage: ""

    Process {
        id: placer

        property var sizes: []
        property real spanX: 0
        property real spanY: 0
        property int top: 0

        stdout: StdioCollector {
            onStreamFinished: root.takePlaces(text)
        }
        onExited: {
            if (root.pendingImage === "")
                return;
            const image = root.pendingImage;
            root.pendingImage = "";
            root.arrange(image);
        }
    }

    FileView {
        id: file

        path: Quickshell.env("HOME") + "/.config/niri-desk/widgets.json"
        printErrors: false
        atomicWrites: true
        onLoaded: {
            let list = null;
            try {
                list = root.validated(JSON.parse(text()));
            } catch (e) {
                list = null;
            }
            root.apply(list === null ? root.defaults : list, false);
            root.loaded = true;
        }
        onLoadFailed: {
            root.apply(root.defaults, false);
            root.loaded = true;
        }
    }
}
