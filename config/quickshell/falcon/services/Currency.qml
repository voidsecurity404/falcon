pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Exchange rates against the sum from the Central Bank of Uzbekistan, through bin/falcon-currency.
// Crypto (BTC, ETH…) the bank does not list comes in dollars, with "unit": "USD". UZS is the base.
// Asked only while a currency widget is on the desktop, every three hours and again a few seconds
// after the list of currencies changes. The last answer stays through failed requests.
Singleton {
    id: root

    readonly property var codes: String(Settings.get("widgets.currency.codes", "USD,RUB,EUR") || "").toUpperCase().split(/[\s,;]+/).filter(c => /^[A-Z]{3,5}$/.test(c) && c !== "UZS").slice(0, 6)
    readonly property bool wanted: Widgets.loaded && Widgets.hasType("currency")
    property var rates: ({})
    property var history: ({})
    property string date: ""
    property bool offline: false
    property real fetchedAt: 0

    function refresh() {
        if (!proc.running && codes.length > 0) {
            proc.command = [Ui.binDir + "falcon-currency"].concat(codes);
            proc.running = true;
        }
    }

    // 12014.37 -> "12 014", 146.19 -> "146.19".
    // "$64 654" for a coin priced in dollars, the plain number for one in sum.
    function price(code, v) {
        const r = rates[code];
        return (r && r.unit === "USD" ? "$" : "") + format(v);
    }
    function format(v) {
        if (v >= 1000)
            return Math.round(v).toLocaleString(Qt.locale(), "f", 0);
        return Number(v).toLocaleString(Qt.locale(), "f", 2);
    }

    onWantedChanged: if (wanted) refresh()
    onCodesChanged: if (wanted) again.restart()

    Timer {
        id: again

        interval: 2000
        onTriggered: root.refresh()
    }
    Timer {
        interval: 3 * 3600000
        running: root.wanted && !GameMode.quiet
        repeat: true
        onTriggered: root.refresh()
    }
    // A failed first try (no network yet at login) is tried again soon.
    Timer {
        interval: 120000
        running: root.wanted && root.offline && !GameMode.quiet
        repeat: true
        onTriggered: root.refresh()
    }
    Process {
        id: proc

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    if (d.error) {
                        root.offline = true;
                        return;
                    }
                    root.rates = d.rates || {};
                    root.history = d.history || {};
                    root.date = d.date || "";
                    root.offline = false;
                    root.fetchedAt = Date.now();
                } catch (e) {
                    root.offline = true;
                }
            }
        }
    }
}
