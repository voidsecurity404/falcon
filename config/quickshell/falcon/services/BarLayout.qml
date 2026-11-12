pragma Singleton

import QtQuick
import Quickshell

// What the top bar shows and where: the parts of each of the three islands in order, and the
// sizes of the islands. Settings → Panel edits it, the islands, Sys, Media and Privacy read it.
// A part in no island is hidden. Unknown names and repeats in the settings are dropped.
Singleton {
    id: root

    // Every part the bar can show. `home` is the island it goes back to when added again,
    // `sep` puts a thin line between it and its neighbours.
    readonly property var catalog: [
        {
            id: "menu",
            title: "App menu",
            icon: "sparkle",
            home: "left"
        },
        {
            id: "workspaces",
            title: "Workspaces",
            icon: "windows",
            home: "left",
            sep: true
        },
        {
            id: "window",
            title: "Focused window",
            icon: "panel",
            home: "left",
            sep: true
        },
        {
            id: "resources",
            title: "System load",
            icon: "chip",
            home: "center",
            sep: true
        },
        {
            id: "record",
            title: "Recording time",
            icon: "record",
            home: "center"
        },
        {
            id: "timer",
            title: "Timer",
            icon: "timer",
            home: "center"
        },
        {
            id: "clock",
            title: "Clock",
            icon: "clock",
            home: "center"
        },
        {
            id: "weather",
            title: "Weather",
            icon: "cloudSun",
            home: "center"
        },
        {
            id: "media",
            title: "Music",
            icon: "music",
            home: "center",
            sep: true
        },
        {
            id: "tools",
            title: "Tools",
            icon: "screenshot",
            home: "right",
            sep: true
        },
        {
            id: "tray",
            title: "Tray",
            icon: "widgets",
            home: "right",
            sep: true
        },
        {
            id: "claude",
            title: "Claude",
            icon: "claude",
            home: "right"
        },
        {
            id: "privacy",
            title: "Mic and camera",
            icon: "mic",
            home: "right"
        },
        {
            id: "updates",
            title: "Waiting updates",
            icon: "update",
            home: "right"
        },
        {
            id: "lang",
            title: "Keyboard layout",
            icon: "keyboard",
            home: "right"
        },
        {
            id: "phone",
            title: "Phone",
            icon: "phone",
            home: "right"
        },
        {
            id: "status",
            title: "Status",
            icon: "wifi",
            home: "right"
        },
        {
            id: "bell",
            title: "Notifications",
            icon: "bell",
            home: "right"
        },
        {
            id: "power",
            title: "Power menu",
            icon: "power",
            home: "right"
        }
    ]
    // The network and security parts, one per reading of NetTools. They start hidden.
    readonly property var netParts: NetTools.tools.map(t => ({
                id: t.id,
                title: t.title,
                icon: t.icon,
                home: "right",
                net: true
            }))
    readonly property var allParts: catalog.concat(netParts)
    readonly property var zones: ["left", "center", "right"]
    readonly property var byId: {
        const out = {};
        for (const part of allParts)
            out[part.id] = part;
        return out;
    }

    readonly property var left: clean("left")
    readonly property var center: clean("center")
    readonly property var right: clean("right")
    readonly property var hidden: allParts.map(p => p.id).filter(id => !left.includes(id) && !center.includes(id) && !right.includes(id))

    // Sizes, kept in a range the bar still works in.
    readonly property int height: clamp(Settings.get("panel.height", 42), 30, 60)
    readonly property int radius: Math.min(clamp(Settings.get("panel.radius", 15), 0, 30), Math.floor(height / 2))
    readonly property int edgeGap: clamp(Settings.get("panel.edgeGap", 8), 0, 30)
    readonly property int sideGap: clamp(Settings.get("panel.sideGap", 10), 0, 60)
    readonly property int spacing: clamp(Settings.get("panel.spacing", 8), 0, 24)
    readonly property bool border: Settings.get("panel.border", true)
    // One long glass bar holding all three islands, or three separate islands.
    readonly property bool joined: Settings.get("panel.joined", true) === true
    readonly property int buttonHeight: Math.max(22, Math.min(36, height - 12))
    readonly property string workspaceStyle: Settings.get("panel.workspaceStyle", "pills")
    readonly property int titleWidth: clamp(Settings.get("panel.titleWidth", 280), 60, 600)
    readonly property int mediaWidth: clamp(Settings.get("panel.mediaWidth", 140), 60, 400)
    // Where the menus under the bar start, and the strip kept free for windows.
    readonly property int popupTop: edgeGap + height + 8
    readonly property int reserved: Math.max(0, edgeGap + height - 4)

    function clamp(value, low, high) {
        const n = Number(value);
        return isNaN(n) ? low : Math.max(low, Math.min(high, Math.round(n)));
    }

    // Switches of the bar before parts could be moved. Until the user arranges the islands, a
    // part switched off there stays hidden.
    readonly property var legacy: ({
            workspaces: "ribbon",
            resources: "resources",
            media: "media",
            tools: "tools",
            tray: "tray",
            claude: "claude",
            updates: "updates",
            privacy: "privacy",
            lang: "lang"
        })

    // An island's parts from the settings: known names only, each once, earlier islands first.
    function clean(zone) {
        const seen = {};
        const own = Settings.user.panel || {};
        for (const z of zones) {
            const list = Settings.get("panel." + z, (Settings.defaults.panel || {})[z] || []);
            const arranged = Array.isArray(own[z]);
            const out = [];
            for (const id of Array.isArray(list) ? list : []) {
                if (typeof id !== "string" || !byId[id] || seen[id])
                    continue;
                if (!arranged && legacy[id] && own[legacy[id]] === false)
                    continue;
                seen[id] = true;
                out.push(id);
            }
            if (z === zone)
                return out;
        }
        return [];
    }

    function has(id) {
        return left.includes(id) || center.includes(id) || right.includes(id);
    }
    function zoneOf(id) {
        for (const z of zones)
            if (root[z].includes(id))
                return z;
        return "hidden";
    }

    // Puts a part into an island at an index, or hides it with the zone "hidden".
    function place(id, zone, index) {
        if (!byId[id])
            return;
        const lists = {
            left: left.slice(),
            center: center.slice(),
            right: right.slice()
        };
        let at = index;
        for (const z of zones) {
            const i = lists[z].indexOf(id);
            if (i < 0)
                continue;
            lists[z].splice(i, 1);
            if (z === zone && i < at)
                at -= 1;
        }
        if (lists[zone]) {
            at = Math.max(0, Math.min(lists[zone].length, at));
            lists[zone].splice(at, 0, id);
        }
        const panel = JSON.parse(JSON.stringify(Settings.user.panel || {}));
        for (const z of zones)
            panel[z] = lists[z];
        for (const key in legacy)
            delete panel[legacy[key]];
        Settings.set("panel", panel);
    }
    function hide(id) {
        place(id, "hidden", 0);
    }
    // Back to the island it belongs to, at its end.
    function restore(id) {
        const home = byId[id] ? byId[id].home : "right";
        place(id, home, root[home].length);
    }
    // The parts and their order as on a fresh install. The sizes stay.
    function resetLayout() {
        const panel = JSON.parse(JSON.stringify(Settings.user.panel || {}));
        for (const z of zones)
            delete panel[z];
        for (const key in legacy)
            delete panel[legacy[key]];
        Settings.set("panel", panel);
    }
    function resetLook() {
        const panel = JSON.parse(JSON.stringify(Settings.user.panel || {}));
        for (const key of ["joined", "height", "radius", "edgeGap", "sideGap", "spacing", "border", "workspaceStyle", "titleWidth", "mediaWidth"])
            delete panel[key];
        Settings.set("panel", panel);
    }
}
