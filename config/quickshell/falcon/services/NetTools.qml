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
    // The tool whose menu is open, and a port check of one device from the devices menu.
    property string open: ""
    property string probeIp: ""
    property var probe: null
    property bool probing: false

    function has(id) {
        return !!byId[id];
    }
    function iconOf(id) {
        return byId[id] ? byId[id].icon : "panel";
    }
    // Text beside the icon on the bar.
    function badgeOf(id) {
        const d = data[id];
        return d && !(byId[id] || {}).quiet ? d.badge || "" : "";
    }
    function colorOf(id) {
        const d = data[id];
        const s = d ? d.state : "";
        return s === "good" ? Theme.good : s === "bad" ? Theme.error : s === "warn" ? Theme.warn : Theme.text;
    }

    function watch(id, step) {
        const w = Object.assign({}, watched);
        w[id] = Math.max(0, (w[id] || 0) + step);
        watched = w;
        if (step > 0 && !data[id])
            refresh(id);
    }

    function toggle(id) {
        if (Ui.popup === "net" && open === id) {
            Ui.popup = "";
            return;
        }
        if (open !== id) {
            probe = null;
            probeIp = "";
        }
        open = id;
        Ui.popup = "net";
        refresh(id);
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
                const wanted = (root.watched[t.id] || 0) > 0 || (t.id === "speed" && Ui.popup === "net" && root.open === "speed");
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
