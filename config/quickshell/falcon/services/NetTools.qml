pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Readings for the bar's network and security parts (Settings → Panel, the parts marked
// "Network"). Each reading comes from `falcon-netscan TOOL` as one JSON object; `speed` alone is
// counted here from /proc/net/dev. A reading runs only while its part is on the bar (every
// `every` seconds) or when its menu opens, never two of one kind at once.
Singleton {
    id: root

    readonly property var tools: [
        {
            id: "lan",
            title: "Devices on the network",
            icon: "devices",
            every: 120
        },
        {
            id: "wan",
            title: "Public address",
            icon: "globe",
            every: 600
        },
        {
            id: "iface",
            title: "Interfaces",
            icon: "ethernet",
            every: 30
        },
        {
            id: "wifi",
            title: "Wi-Fi",
            icon: "wifi",
            every: 20
        },
        {
            id: "aps",
            title: "Nearby Wi-Fi",
            icon: "radar",
            every: 180
        },
        {
            id: "ports",
            title: "Listening ports",
            icon: "plug",
            every: 30
        },
        {
            id: "conns",
            title: "Connections",
            icon: "link",
            every: 15
        },
        {
            id: "vpn",
            title: "VPN",
            icon: "shieldCheck",
            every: 10
        },
        {
            id: "dns",
            title: "DNS",
            icon: "server",
            every: 120,
            quiet: true
        },
        {
            id: "ping",
            title: "Latency",
            icon: "pulse",
            every: 30
        },
        {
            id: "speed",
            title: "Traffic",
            icon: "gauge",
            every: 2
        },
        {
            id: "firewall",
            title: "Firewall",
            icon: "flame",
            every: 60
        },
        {
            id: "arp",
            title: "ARP watch",
            icon: "eye",
            every: 30
        },
        {
            id: "tor",
            title: "Tor",
            icon: "onion",
            every: 60
        },
        {
            id: "bt",
            title: "Bluetooth nearby",
            icon: "bluetooth",
            every: 0
        },
        {
            id: "hash",
            title: "Encode and hash",
            icon: "hash",
            every: 0,
            quiet: true
        },
        {
            id: "logins",
            title: "Sessions and logins",
            icon: "user",
            every: 60
        }
    ]
    readonly property var byId: {
        const out = {};
        for (const t of tools)
            out[t.id] = t;
        return out;
    }

    // Tool id → its last reading, and the ones running now.
    property var data: ({})
    property var busy: ({})
    property var last: ({})
    // How many bar parts show each tool.
    property var watched: ({})
    // The menu: `origin` is the bar part it drops from ("network" for the hub, or a tool), `open`
    // the tool whose table it shows ("" is the hub's page of tiles). Only a click opens it; pointing
    // at a part shows just its name (`tip`, after a short pause).
    property string open: ""
    property string origin: ""
    property string pointed: ""
    property string tip: ""
    property string probeIp: ""
    property var probe: null
    property bool probing: false
    // Values beside the icons on the bar; off, the bar shows icons only and the menu has the values.
    readonly property bool showValues: Settings.get("panel.netValues", false) === true
    // Readings the hub watches for its warning dot: a red one when any of them is bad.
    readonly property var alertTools: ["arp", "firewall", "ping", "wifi", "logins"]
    readonly property string alert: {
        let worst = "";
        for (const id of alertTools) {
            const d = data[id];
            if (d && d.state === "bad")
                return "bad";
            if (d && d.state === "warn")
                worst = "warn";
        }
        return worst;
    }
    readonly property bool menuOpen: Ui.popup === "net"

    function has(id) {
        return !!byId[id];
    }
    function iconOf(id) {
        return byId[id] ? byId[id].icon : "panel";
    }
    // Text beside the icon on the bar.
    function badgeOf(id) {
        const d = data[id];
        return showValues && d && !(byId[id] || {}).quiet ? d.badge || "" : "";
    }
    function stateColor(state) {
        return state === "good" ? Theme.good : state === "bad" ? Theme.error : state === "warn" ? Theme.warn : Theme.text;
    }
    function colorOf(id) {
        const d = data[id];
        return stateColor(d ? d.state : "");
    }

    function watch(id, step) {
        const w = Object.assign({}, watched);
        w[id] = Math.max(0, (w[id] || 0) + step);
        watched = w;
        if (step > 0 && !data[id])
            refresh(id);
    }
    // The hub on the bar keeps the readings of its warning dot fresh.
    function watchHub(step) {
        for (const id of alertTools)
            watch(id, step);
    }

    // Shows a tool's table, or the hub's tiles with "".
    function show(id) {
        if (open !== id) {
            probe = null;
            probeIp = "";
        }
        open = id;
        if (id === "")
            refreshStale();
        else
            refresh(id);
    }
    // Opens the menu under a bar part: "network" for the hub, otherwise a tool.
    function openFrom(part) {
        origin = part;
        show(part === "network" ? "" : part);
        Ui.popup = "net";
    }
    // A click opens the part's menu, or closes it when it is already open from that part.
    function click(part) {
        tip = "";
        tipTimer.stop();
        if (menuOpen && origin === part) {
            Ui.popup = "";
            return;
        }
        openFrom(part);
    }
    // Kept for `desk netMenu`.
    function toggle(id) {
        click(id === "" ? "network" : id);
    }
    // The part's name under it, never while a menu is open.
    function titleOf(part) {
        return part === "network" ? "Network and security" : (byId[part] || {}).title || "";
    }
    function hoverEnter(part) {
        pointed = part;
        tip = "";
        tipTimer.restart();
    }
    function hoverExit(part) {
        if (pointed === part) {
            pointed = "";
            tip = "";
            tipTimer.stop();
        }
    }

    // Every reading that is older than its interval, for the hub's tiles.
    function refreshStale() {
        const now = Date.now();
        for (const t of tools)
            if (t.every > 0 && (!data[t.id] || now - (last[t.id] || 0) >= t.every * 1000))
                refresh(t.id);
    }

    Timer {
        id: tipTimer

        interval: 450
        onTriggered: {
            if (root.pointed !== "" && Ui.popup === "")
                root.tip = root.pointed;
        }
    }
    Connections {
        target: Ui

        function onPopupChanged() {
            if (Ui.popup !== "")
                root.tip = "";
        }
    }

    function setBusy(id, on) {
        const b = Object.assign({}, busy);
        b[id] = on;
        busy = b;
    }

    function refresh(id) {
        if (!byId[id] || busy[id])
            return;
        const l = Object.assign({}, last);
        l[id] = Date.now();
        last = l;
        if (id === "speed") {
            netdev.reload();
            return;
        }
        setBusy(id, true);
        runner.createObject(root, {
            tool: id,
            command: [Ui.binDir + "falcon-netscan", id]
        });
    }

    // Common ports of one device on the local network.
    function probeHost(ip) {
        if (probing)
            return;
        probeIp = ip;
        probe = null;
        probing = true;
        runner.createObject(root, {
            tool: "probe",
            command: [Ui.binDir + "falcon-netscan", "probe", ip]
        });
    }

    function copy(text) {
        Quickshell.execDetached(["wl-copy", "--", String(text)]);
    }

    function took(tool, text) {
        let r = null;
        try {
            r = JSON.parse(text);
        } catch (e) {
            r = {
                title: "",
                error: "No answer",
                rows: [],
                columns: [],
                badge: "",
                state: ""
            };
        }
        if (tool === "probe") {
            probe = r;
            probing = false;
            return;
        }
        const d = Object.assign({}, data);
        d[tool] = r;
        data = d;
        setBusy(tool, false);
    }

    Component {
        id: runner

        Process {
            id: proc

            property string tool: ""

            running: true
            stdout: StdioCollector {
                onStreamFinished: {
                    root.took(proc.tool, text);
                    proc.destroy();
                }
            }
        }
    }

    // Every second: readings whose part is on the bar and whose time has come, and the open menu's
    // traffic, which changes all the time.
    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            const now = Date.now();
            for (const t of root.tools) {
                const wanted = (root.watched[t.id] || 0) > 0 || (t.id === "speed" && root.menuOpen);
                if (wanted && t.every > 0 && now - (root.last[t.id] || 0) >= t.every * 1000)
                    root.refresh(t.id);
            }
        }
    }

    // Traffic: bytes per second of each interface, from two readings of /proc/net/dev.
    property var counters: ({})
    property real countedAt: 0

    function human(bytes) {
        const units = ["B", "K", "M", "G"];
        let v = bytes;
        let i = 0;
        while (v >= 1000 && i < units.length - 1) {
            v /= 1024;
            i++;
        }
        return (v >= 10 || i === 0 ? Math.round(v) : v.toFixed(1)) + units[i];
    }

    FileView {
        id: netdev

        path: "/proc/net/dev"
        blockLoading: true
        onLoaded: {
            const now = Date.now();
            const seconds = root.countedAt > 0 ? (now - root.countedAt) / 1000 : 0;
            const fresh = {};
            const rows = [];
            let down = 0;
            let up = 0;
            let received = 0;
            let sent = 0;
            for (const line of text().split("\n").slice(2)) {
                const m = line.match(/^\s*([^:]+):\s*(.*)$/);
                if (!m || m[1] === "lo")
                    continue;
                const f = m[2].trim().split(/\s+/).map(Number);
                const name = m[1];
                fresh[name] = [f[0], f[8]];
                const old = root.counters[name];
                const rx = old && seconds > 0 ? Math.max(0, (f[0] - old[0]) / seconds) : 0;
                const tx = old && seconds > 0 ? Math.max(0, (f[8] - old[1]) / seconds) : 0;
                down += rx;
                up += tx;
                received += f[0];
                sent += f[8];
                if (f[0] + f[8] > 0)
                    rows.push([name, "↓ " + root.human(rx) + "/s", "↑ " + root.human(tx) + "/s", root.human(f[0]), root.human(f[8])]);
            }
            root.counters = fresh;
            root.countedAt = now;
            const d = Object.assign({}, root.data);
            d.speed = {
                title: Tr.t("Traffic"),
                summary: Tr.t("Since boot: received {rx}, sent {tx}").replace("{rx}", root.human(received)).replace("{tx}", root.human(sent)),
                columns: [Tr.t("Interface"), Tr.t("Download"), Tr.t("Upload"), Tr.t("Received"), Tr.t("Sent")],
                rows: rows,
                badge: "↓" + root.human(down) + " ↑" + root.human(up),
                state: "",
                error: ""
            };
            root.data = d;
        }
    }
}
