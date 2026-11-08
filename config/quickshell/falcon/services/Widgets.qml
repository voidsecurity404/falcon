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
            type: "stack",
            title: Tr.t("Stacked clock"),
            blurb: Tr.t("Bold hours over thin minutes, right on the wallpaper"),
            icon: "clock",
            group: "time",
            forms: [{ name: "stacked", w: 270, h: 330 }, { name: "line", w: 470, h: 170 }, { name: "small", w: 250, h: 120 }],
            plate: false
        },
        {
            type: "flip",
            title: Tr.t("Flip clock"),
            blurb: Tr.t("Cards that turn over every minute"),
            icon: "clock",
            group: "time",
            forms: [{ name: "wide", w: 420, h: 170 }, { name: "small", w: 290, h: 120 }],
            solid: true,
            plate: false
        },
        {
            type: "orbit",
            title: Tr.t("Orbit clock"),
            blurb: Tr.t("Hours, minutes and seconds as three rings"),
            icon: "clock",
            group: "time",
            forms: [{ name: "round", w: 220, h: 220 }, { name: "wide", w: 360, h: 170 }],
            plate: true
        },
        {
            type: "dial",
            title: Tr.t("Dial"),
            blurb: Tr.t("Classic hands with a ticking second"),
            icon: "clock",
            group: "time",
            forms: [{ name: "round", w: 230, h: 230 }],
            plate: true
        },
        {
            type: "cookie",
            title: Tr.t("Cookie clock"),
            blurb: Tr.t("Hands on a wavy Material shape"),
            icon: "clock",
            group: "time",
            forms: [{ name: "cookie", w: 240, h: 240 }, { name: "flower", w: 240, h: 240 }],
            solid: true,
            plate: false
        },
        {
            type: "matrix",
            title: Tr.t("Dot matrix clock"),
            blurb: Tr.t("Glowing digits made of dots"),
            icon: "clock",
            group: "time",
            forms: [{ name: "wide", w: 420, h: 156 }],
            plate: true
        },
        {
            type: "world",
            title: Tr.t("World time"),
            blurb: Tr.t("Moscow, London, New York and Tokyo"),
            icon: "clock",
            group: "time",
            forms: [{ name: "wide", w: 340, h: 206 }, { name: "compact", w: 430, h: 96 }],
            plate: true
        },
        {
            type: "dayprogress",
            title: Tr.t("Time passing"),
            blurb: Tr.t("How much of the day, week, month and year is gone"),
            icon: "timer",
            group: "time",
            forms: [{ name: "wide", w: 320, h: 196 }, { name: "compact", w: 400, h: 104 }],
            plate: true
        },
        {
            type: "month",
            title: Tr.t("Month"),
            blurb: Tr.t("The whole month with today marked"),
            icon: "calendar",
            group: "date",
            forms: [{ name: "month", w: 300, h: 316 }],
            plate: true
        },
        {
            type: "datecard",
            title: Tr.t("Date card"),
            blurb: Tr.t("A calendar page in the wallpaper color"),
            icon: "calendar",
            group: "date",
            forms: [{ name: "square", w: 176, h: 176 }, { name: "wide", w: 310, h: 130 }],
            solid: true,
            plate: false
        },
        {
            type: "weekstrip",
            title: Tr.t("Week"),
            blurb: Tr.t("Seven days in a row"),
            icon: "calendar",
            group: "date",
            forms: [{ name: "wide", w: 430, h: 124 }],
            plate: true
        },
        {
            type: "yeardots",
            title: Tr.t("Year in dots"),
            blurb: Tr.t("A dot for each day of the year"),
            icon: "widgets",
            group: "date",
            forms: [{ name: "wide", w: 400, h: 196 }, { name: "tall", w: 216, h: 340 }],
            plate: true
        },
        {
            type: "sky",
            title: Tr.t("Sky"),
            blurb: Tr.t("The temperature on a sky of the current weather"),
            icon: "sun",
            group: "weather",
            forms: [{ name: "wide", w: 320, h: 160 }, { name: "tall", w: 190, h: 236 }, { name: "compact", w: 240, h: 96 }],
            solid: true,
            plate: false
        },
        {
            type: "forecast",
            title: Tr.t("Forecast"),
            blurb: Tr.t("The coming days with their temperature range"),
            icon: "cloud",
            group: "weather",
            forms: [{ name: "wide", w: 370, h: 236 }, { name: "across", w: 440, h: 156 }],
            plate: true
        },
        {
            type: "hourly",
            title: Tr.t("By the hour"),
            blurb: Tr.t("How the temperature changes in the next 24 hours"),
            icon: "cloudSun",
            group: "weather",
            forms: [{ name: "wide", w: 430, h: 186 }],
            plate: true
        },
        {
            type: "sunpath",
            title: Tr.t("Sun path"),
            blurb: Tr.t("Where the sun is between sunrise and sunset"),
            icon: "sun",
            group: "weather",
            forms: [{ name: "wide", w: 320, h: 186 }],
            plate: true
        },
        {
            type: "moon",
            title: Tr.t("Moon"),
            blurb: Tr.t("The moon as it looks tonight"),
            icon: "moon",
            group: "weather",
            forms: [{ name: "wide", w: 300, h: 150 }, { name: "tall", w: 190, h: 226 }],
            plate: true
        },
        {
            type: "rings",
            title: Tr.t("System rings"),
            blurb: Tr.t("Processor, memory and temperature"),
            icon: "chip",
            group: "system",
            forms: [{ name: "wide", w: 340, h: 180 }, { name: "round", w: 190, h: 190 }],
            uses: "system",
            plate: true
        },
        {
            type: "cpugraph",
            title: Tr.t("Processor graph"),
            blurb: Tr.t("Load of the last two minutes"),
            icon: "chip",
            group: "system",
            forms: [{ name: "wide", w: 360, h: 170 }, { name: "compact", w: 270, h: 96 }],
            uses: "system",
            plate: true
        },
        {
            type: "memgrid",
            title: Tr.t("Memory"),
            blurb: Tr.t("Used memory as a field of blocks"),
            icon: "chip",
            group: "system",
            forms: [{ name: "wide", w: 300, h: 176 }, { name: "compact", w: 370, h: 88 }],
            uses: "system",
            plate: true
        },
        {
            type: "storage",
            title: Tr.t("Disk"),
            blurb: Tr.t("How full the disk is and what is free"),
            icon: "system",
            group: "system",
            forms: [{ name: "round", w: 186, h: 196 }, { name: "wide", w: 310, h: 110 }],
            uses: "system",
            plate: true
        },
        {
            type: "liquidbattery",
            title: Tr.t("Battery"),
            blurb: Tr.t("A level of liquid that moves while charging"),
            icon: "battery",
            group: "system",
            forms: [{ name: "tall", w: 176, h: 246 }, { name: "wide", w: 310, h: 120 }],
            uses: "system",
            plate: true
        },
        {
            type: "netspeed",
            title: Tr.t("Network"),
            blurb: Tr.t("Download and upload speed"),
            icon: "wifi",
            group: "system",
            forms: [{ name: "wide", w: 350, h: 170 }, { name: "compact", w: 290, h: 88 }],
            plate: true
        },
        {
            type: "vinyl",
            title: Tr.t("Record player"),
            blurb: Tr.t("The cover on a record that spins with the music"),
            icon: "music",
            group: "music",
            forms: [{ name: "wide", w: 420, h: 176 }, { name: "tall", w: 236, h: 350 }],
            uses: "music",
            interactive: true,
            plate: true
        },
        {
            type: "cover",
            title: Tr.t("Album cover"),
            blurb: Tr.t("The whole widget is the cover of the track"),
            icon: "music",
            group: "music",
            forms: [{ name: "square", w: 260, h: 260 }, { name: "wide", w: 430, h: 140 }],
            solid: true,
            uses: "music",
            interactive: true,
            plate: false
        },
        {
            type: "equalizer",
            title: Tr.t("Equalizer"),
            blurb: Tr.t("Bars that move with the sound"),
            icon: "volume",
            group: "music",
            forms: [{ name: "wide", w: 370, h: 156 }, { name: "compact", w: 270, h: 88 }],
            uses: "music",
            plate: true
        },
        {
            type: "sticky",
            title: Tr.t("Sticky note"),
            blurb: Tr.t("A paper note you can write on"),
            icon: "note",
            group: "tools",
            forms: [{ name: "wide", w: 280, h: 250 }, { name: "tall", w: 230, h: 340 }, { name: "short", w: 420, h: 170 }],
            solid: true,
            interactive: true,
            typing: true,
            plate: false
        },
        {
            type: "checklist",
            title: Tr.t("Checklist"),
            blurb: Tr.t("Tasks you can add and tick off"),
            icon: "check",
            group: "tools",
            forms: [{ name: "wide", w: 300, h: 320 }, { name: "short", w: 430, h: 210 }],
            interactive: true,
            typing: true,
            plate: true
        },
        {
            type: "pomodoro",
            title: Tr.t("Pomodoro"),
            blurb: Tr.t("Work and break rounds with one press"),
            icon: "focus",
            group: "tools",
            forms: [{ name: "round", w: 216, h: 246 }, { name: "wide", w: 330, h: 116 }],
            interactive: true,
            plate: true
        },
        {
            type: "quote",
            title: Tr.t("Quote of the day"),
            blurb: Tr.t("A new thought every day"),
            icon: "sparkle",
            group: "tools",
            forms: [{ name: "wide", w: 430, h: 170 }, { name: "tall", w: 266, h: 290 }],
            plate: true
        },
        {
            type: "claudering",
            title: Tr.t("Claude limits"),
            blurb: Tr.t("The 5 hour and weekly limits as rings"),
            icon: "sparkle",
            group: "tools",
            forms: [{ name: "wide", w: 340, h: 170 }, { name: "compact", w: 300, h: 92 }],
            plate: true
        }
    ]
    readonly property var groups: [
        { id: "all", title: Tr.t("All") },
        { id: "time", title: Tr.t("Time") },
        { id: "date", title: Tr.t("Calendar") },
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
        {
            id: "stack",
            type: "stack",
            fx: 0.02,
            fy: 0.97,
            size: "m"
        },
        {
            id: "month",
            type: "month",
            fx: 0.985,
            fy: 0.02,
            size: "m"
        },
        {
            id: "rings",
            type: "rings",
            fx: 0.985,
            fy: 0.97,
            size: "m"
        },
        {
            id: "cover",
            type: "cover",
            fx: 0.985,
            fy: 0.5,
            size: "m"
        },
        {
            id: "sky",
            type: "sky",
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
    readonly property int topInset: Settings.bottom ? 16 : 56
    readonly property int bottomInset: (Settings.bottom ? 56 : 16) + (wavesEnabled ? wavesHeight : 0)
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
        apply(items.concat([
            {
                id: type + (n > 1 ? "-" + n : ""),
                type: type,
                fx: 0.5,
                fy: 0.4,
                size: "m"
            }
        ]), true);
        remember();
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
