pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Desktop widgets: which ones, where and how large. Stored in ~/.config/falcon/widgets.json.
// Places are fractions of the free screen area, so a layout survives another resolution.
// Each widget type has one or more forms: its content arranged for another shape. The first is the usual one.
Singleton {
    id: root

    readonly property var catalog: [
        {
            type: "clock",
            title: Tr.t("Clock"),
            blurb: Tr.t("Large time with the date, weather and a running minute"),
            icon: "clock",
            group: "time",
            forms: [{ name: "wide", w: 480, h: 250 }, { name: "stacked", w: 300, h: 380 }, { name: "compact", w: 340, h: 150 }],
            plate: false
        },
        {
            type: "calendar",
            title: Tr.t("Calendar"),
            blurb: Tr.t("Month you can leaf through, with today and the week number"),
            icon: "calendar",
            group: "time",
            forms: [{ name: "month", w: 330, h: 340 }, { name: "wide", w: 540, h: 300 }],
            interactive: true,
            plate: true
        },
        {
            type: "focus",
            title: Tr.t("Focus timer"),
            blurb: Tr.t("Pomodoro rounds and quick timers with a live ring"),
            icon: "focus",
            group: "time",
            forms: [{ name: "round", w: 270, h: 320 }, { name: "wide", w: 490, h: 190 }],
            interactive: true,
            plate: true
        },
        {
            type: "weather",
            title: Tr.t("Weather"),
            blurb: Tr.t("Now, the next hours with rain chance and the coming days"),
            icon: "cloudSun",
            group: "weather",
            forms: [{ name: "large", w: 440, h: 440 }, { name: "wide", w: 460, h: 210 }, { name: "compact", w: 280, h: 140 }],
            plate: true
        },
        {
            type: "player",
            title: Tr.t("Player"),
            blurb: Tr.t("Cover, seek bar and controls of what is playing"),
            icon: "music",
            group: "music",
            forms: [{ name: "wide", w: 470, h: 200 }, { name: "square", w: 310, h: 360 }],
            uses: "music",
            interactive: true,
            plate: true
        },
        {
            type: "system",
            title: Tr.t("System monitor"),
            blurb: Tr.t("Processor graph, memory, temperature, disk and network"),
            icon: "chip",
            group: "system",
            forms: [{ name: "wide", w: 460, h: 230 }, { name: "tall", w: 260, h: 350 }, { name: "compact", w: 330, h: 140 }],
            uses: "system",
            plate: true
        },
        {
            type: "power",
            title: Tr.t("Battery and power"),
            blurb: Tr.t("Charge, time left and the power mode in one press"),
            icon: "battery",
            group: "system",
            forms: [{ name: "wide", w: 440, h: 200 }, { name: "square", w: 260, h: 280 }],
            uses: "system",
            interactive: true,
            plate: true
        },
        {
            type: "controls",
            title: Tr.t("Quick controls"),
            blurb: Tr.t("Volume, brightness and the main switches"),
            icon: "settings",
            group: "system",
            forms: [{ name: "wide", w: 520, h: 230 }, { name: "tall", w: 270, h: 410 }],
            interactive: true,
            plate: true
        },
        {
            type: "notes",
            title: Tr.t("Notes"),
            blurb: Tr.t("A note you write right on the desktop, saved as you type"),
            icon: "note",
            group: "tools",
            forms: [{ name: "wide", w: 360, h: 270 }, { name: "tall", w: 270, h: 380 }],
            interactive: true,
            typing: true,
            plate: true
        },
        {
            type: "tasks",
            title: Tr.t("Tasks"),
            blurb: Tr.t("A list to add to and tick off, with progress"),
            icon: "check",
            group: "tools",
            forms: [{ name: "tall", w: 330, h: 360 }, { name: "wide", w: 460, h: 250 }],
            interactive: true,
            typing: true,
            plate: true
        },
        {
            type: "apps",
            title: Tr.t("Apps"),
            blurb: Tr.t("Your pinned apps, started with one press"),
            icon: "widgets",
            group: "tools",
            forms: [{ name: "grid", w: 320, h: 220 }, { name: "row", w: 460, h: 104 }],
            interactive: true,
            plate: true
        },
        {
            type: "phone",
            title: Tr.t("Phone"),
            blurb: Tr.t("Battery, notifications and actions of your phone"),
            icon: "phone",
            group: "tools",
            forms: [{ name: "wide", w: 440, h: 210 }, { name: "square", w: 270, h: 300 }],
            interactive: true,
            plate: true
        }
    ]
    readonly property var groups: [
        { id: "all", title: Tr.t("All") },
        { id: "time", title: Tr.t("Time") },
        { id: "weather", title: Tr.t("Weather") },
        { id: "system", title: Tr.t("System") },
        { id: "music", title: Tr.t("Music") },
        { id: "tools", title: Tr.t("Tools") }
    ]
    readonly property var sizes: ({
            s: 0.85,
            m: 1,
            l: 1.2
        })
    readonly property var defaults: [
        { id: "clock", type: "clock", fx: 0.02, fy: 0.97, size: "m" },
        { id: "calendar", type: "calendar", fx: 0.985, fy: 0.02, size: "m" },
        { id: "system", type: "system", fx: 0.985, fy: 0.97, size: "m" },
        { id: "player", type: "player", fx: 0.985, fy: 0.55, size: "m" },
        { id: "weather", type: "weather", fx: 0.02, fy: 0.02, size: "m", form: "wide" }
    ]

    // Where the pointer is over a widget's clickable copy, in the widget's own pixels. The face draws
    // the widget, so it reads this to show hover and press, which the see-through copy cannot.
    property var pointer: ({ id: "", x: -1, y: -1, down: false })
    // Small state both copies of a widget share, such as the month a calendar shows. Not saved.
    property var shared: ({})

    property var items: []
    // Delegates follow this list, so moving a widget does not rebuild it.
    property var ids: []
    property bool loaded: false
    property bool restacking: false
    // The shell's wallpaper copy is opened again first, then the widgets above it.
    property bool restackingBack: false
    property bool editMode: false
    // The gallery that adds widgets, opened from edit mode. Its previews are live.
    property bool galleryOpen: false
    property string galleryGroup: "all"
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
    // The music waves own the bottom of the desktop, so widgets stay above them.
    readonly property bool wavesEnabled: Settings.get("waves.enabled", true)
    readonly property int wavesHeight: Math.max(60, Math.min(320, Number(Settings.get("waves.height", 140)) || 140))
    readonly property int topInset: 56
    // Looks drawn along the bottom; aura, ring and orb take no strip of their own.
    readonly property string wavesStyle: Settings.get("waves.style", "bars")
    readonly property bool wavesStrip: wavesEnabled && ["aura", "ring", "orb"].indexOf(wavesStyle) < 0
    readonly property int bottomInset: 16 + (wavesStrip ? wavesHeight : 0)
    readonly property real glass: Settings.get("widgets.opacity", 0.5)
    // What a new wallpaper changes: "full" place and form, "place" only the place, "off" nothing.
    readonly property string follow: Settings.get("widgets.followWallpaper", "full")
    // The picture on screen now, the key for layouts the user arranged by hand.
    property string currentImage: ""
    readonly property bool musicLive: galleryOpen || ((shownNow || editMode) && usesData("music"))
    readonly property bool systemLive: galleryOpen || ((shownNow || editMode) && usesData("system"))
    readonly property string notePath: Quickshell.env("HOME") + "/.config/falcon/note.txt"

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

    function usesData(kind) {
        return items.some(w => {
            const i = info(w.type);
            return !!i && i.uses === kind;
        });
    }

    function info(type) {
        return catalog.find(c => c.type === type) || null;
    }

    function get(id) {
        return items.find(w => w.id === id) || null;
    }

    // The form a widget has now, with its size before scaling.
    function formOf(w) {
        const i = w ? info(w.type) : null;
        if (!i)
            return null;
        return i.forms.find(f => f.name === w.form) || i.forms[0];
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
                size: sizes[w.size] ? w.size : "m",
                form: typeof w.form === "string" ? w.form : ""
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
        remember();
    }

    // A layout changed by hand comes back whenever this wallpaper does.
    function remember() {
        if (currentImage === "" || follow === "off")
            return;
        const next = Object.assign({}, handLayouts());
        next[currentImage] = items;
        hand.setText(JSON.stringify(next, null, 1) + "\n");
        handCache = next;
    }

    function forget() {
        const next = Object.assign({}, handLayouts());
        delete next[currentImage];
        hand.setText(JSON.stringify(next, null, 1) + "\n");
        handCache = next;
    }

    function handLayouts() {
        if (handCache === null) {
            try {
                handCache = JSON.parse(hand.text() || "{}");
            } catch (e) {
                handCache = {};
            }
        }
        return handCache;
    }

    // Widgets added since keep their place, and widgets removed since stay removed.
    function restoreHand(saved) {
        const list = validated(saved) || [];
        apply(items.map(w => {
            const old = list.find(s => s.id === w.id);
            return old || w;
        }), true);
    }

    function cycleSize(id) {
        const w = get(id);
        if (!w)
            return;
        update(id, {
            size: w.size === "s" ? "m" : w.size === "m" ? "l" : "s"
        });
        remember();
    }

    function add(type) {
        let n = 1;
        while (get(type + (n > 1 ? "-" + n : "")))
            n++;
        const id = type + (n > 1 ? "-" + n : "");
        const spot = freeSpot(type);
        apply(items.concat([
            {
                id: id,
                type: type,
                fx: spot.fx,
                fy: spot.fy,
                size: "m",
                form: ""
            }
        ]), true);
        remember();
        return id;
    }

    // The place where a new widget covers the least of the others, nearest to the middle.
    function freeSpot(type) {
        const screen = Quickshell.screens.find(s => s.name === Niri.focusedOutput) || Quickshell.screens[0];
        const form = info(type).forms[0];
        if (!screen)
            return { fx: 0.5, fy: 0.4 };
        const spanX = Math.max(1, screen.width - 32 - form.w);
        const spanY = Math.max(1, screen.height - bottomInset - topInset - form.h);
        const taken = Object.keys(rects).filter(id => !!get(id)).map(id => rects[id]);
        let best = null;
        for (let i = 0; i <= 20; i++) {
            for (let j = 0; j <= 20; j++) {
                const fx = i / 20, fy = j / 20;
                const x = 16 + fx * spanX, y = topInset + fy * spanY;
                let cover = 0;
                for (const r of taken) {
                    const w = Math.min(x + form.w + 16, r.x + r.w) - Math.max(x - 16, r.x);
                    const h = Math.min(y + form.h + 16, r.y + r.h) - Math.max(y - 16, r.y);
                    if (w > 0 && h > 0)
                        cover += w * h;
                }
                const far = Math.hypot(fx - 0.5, fy - 0.45);
                const score = cover * 10 + far;
                if (!best || score < best.score)
                    best = { fx: fx, fy: fy, score: score };
            }
        }
        return best;
    }

    // Edit mode's shape button: the next form of this widget.
    function cycleForm(id) {
        const w = get(id);
        const i = w ? info(w.type) : null;
        if (!i || i.forms.length < 2)
            return;
        const at = i.forms.indexOf(formOf(w));
        update(id, { form: i.forms[(at + 1) % i.forms.length].name });
        remember();
    }

    function setPointer(id, x, y) {
        if (pointer.id === id && pointer.x === x && pointer.y === y)
            return;
        pointer = { id: id, x: x, y: y, down: id !== "" && pointer.down };
    }

    function setPointerDown(down) {
        if (pointer.down !== down)
            pointer = { id: pointer.id, x: pointer.x, y: pointer.y, down: down };
    }

    function share(id, key, value) {
        const next = Object.assign({}, shared);
        next[id + "/" + key] = value;
        shared = next;
    }

    function sharedValue(id, key, fallback) {
        const v = shared[id + "/" + key];
        return v === undefined ? fallback : v;
    }

    function remove(id) {
        apply(items.filter(w => w.id !== id), true);
        remember();
    }

    function reset() {
        apply(defaults, true);
        forget();
    }

    // Moves the widgets to the calm parts of a new wallpaper. The newest request wins.
    function arrange(image) {
        currentImage = image;
        if (follow === "off" || !enabled || !loaded || editMode || items.length === 0)
            return;
        const saved = handLayouts()[image];
        if (saved) {
            restoreHand(saved);
            return;
        }
        if (placer.running) {
            pendingImage = image;
            return;
        }
        const screen = Quickshell.screens.find(s => s.name === Niri.focusedOutput) || Quickshell.screens[0];
        if (!screen)
            return;
        const top = topInset;
        const bottom = bottomInset;
        const spanX = screen.width - 32;
        const spanY = screen.height - bottom - top;
        const list = items.map(w => {
            const i = info(w.type);
            const scale = factor(w.size);
            const form = formOf(w);
            return {
                id: w.id,
                form: form.name,
                forms: (follow === "place" ? [form] : i.forms).map(f => ({
                    name: f.name,
                    w: f.w * scale,
                    h: f.h * scale
                })),
                x: 16 + w.fx * Math.max(0, spanX - form.w * scale),
                y: top + w.fy * Math.max(0, spanY - form.h * scale),
                bare: !i.plate && !i.solid
            };
        });
        placer.sizes = list;
        placer.spanX = spanX;
        placer.spanY = spanY;
        placer.top = top;
        placer.command = [Ui.binDir + "falcon-widgets-place", image, String(screen.width), String(screen.height), String(top), String(bottom), JSON.stringify(list)];
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
            const sent = placer.sizes.find(s => s.id === w.id);
            const size = sent ? sent.forms.find(f => f.name === place?.form) : null;
            if (!size)
                return w;
            return Object.assign({}, w, {
                form: size.name,
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
        else
            galleryOpen = false;
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
    // A layer opened later covers the earlier ones in niri's backdrop: a live wallpaper's player, or
    // awww started again. The shell's wallpaper copy and the widgets are opened again above it, in
    // that order, so the copy never lies over the widgets.
    function restack() {
        restacking = true;
        restackingBack = true;
        restackTimer.restart();
    }
    Timer {
        id: restackTimer

        interval: 120
        onTriggered: {
            if (root.restackingBack) {
                root.restackingBack = false;
                restart();
            } else {
                root.restacking = false;
            }
        }
    }

    property string lastActive: ""
    property string pendingImage: ""
    property var handCache: null

    FileView {
        id: hand

        path: Quickshell.env("HOME") + "/.config/falcon/widget-layouts.json"
        blockLoading: true
        printErrors: false
        atomicWrites: true
    }
    Process {
        running: true
        command: ["readlink", "-f", Quickshell.env("HOME") + "/.local/state/falcon/wallpaper"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.currentImage === "")
                    root.currentImage = text.trim();
            }
        }
    }

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

        path: Quickshell.env("HOME") + "/.config/falcon/widgets.json"
        printErrors: false
        atomicWrites: true
        onLoaded: {
            let list = null;
            let raw = null;
            try {
                raw = JSON.parse(text());
                list = root.validated(raw);
            } catch (e) {
                list = null;
            }
            // A layout made only of widget types that no longer exist starts again from the defaults.
            const gone = list !== null && list.length === 0 && Array.isArray(raw) && raw.length > 0;
            root.apply(list === null || gone ? root.defaults : list, gone);
            root.loaded = true;
        }
        onLoadFailed: {
            root.apply(root.defaults, false);
            root.loaded = true;
        }
    }
}
