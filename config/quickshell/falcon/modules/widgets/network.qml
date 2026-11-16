import QtQuick
import qs.components
import qs.services

// Devices on the local network from the bar's LAN reading (falcon-netscan lan): how many, and
// a list with names or makers. One not seen before is marked new for a day; the first scan only
// learns. A press opens the full table. Forms: wide, square.
Item {
    id: root

    readonly property bool widgetRoot: true
    property string widgetId: ""
    property string form: "wide"
    // Set by WidgetHost: only the face, which lives while it is seen, asks for fresh numbers.
    property string role: ""
    property bool watching: false
    onRoleChanged: {
        if (role === "face" && !watching) {
            watching = true;
            NetTools.watch("lan", 1);
        }
    }
    Component.onDestruction: if (watching) NetTools.watch("lan", -1)
    readonly property bool square: form === "square"
    readonly property var reading: NetTools.data["lan"] || null
    // This computer's own rows come last and are left out here.
    readonly property var rows: reading && reading.rows ? reading.rows.filter(r => r.length >= 4 && r[0] !== "" && !/^(this|этот)/i.test(String(r[3]))) : []
    // MAC -> when first seen (ms), kept in Saved "lanSeen" with "since" for the first scan.
    readonly property var seen: Saved.get("lanSeen", null)
    readonly property real dayMs: 86400000

    function isNew(mac) {
        const s = seen;
        return !!s && !!s.macs && !!s.macs[mac] && s.macs[mac] > s.since + 60000 && Date.now() - s.macs[mac] < dayMs;
    }
    function nameOf(r) {
        const n = String(r[3] || "");
        if (n !== "" && n !== "—")
            return n.replace(/\.local$/, "");
        const v = String(r[2] || "");
        return v !== "" && v !== "—" ? v.replace(/\s*(Co\.?,?\s*)?(Ltd\.?|Inc\.?|LLC|Corporation|Corp\.?|Technologies|Technology|Systems)\b.*$/i, "") : r[1];
    }
    readonly property var ordered: rows.slice().sort((a, b) => (isNew(b[1]) - isNew(a[1])))
    readonly property int newCount: rows.filter(r => isNew(r[1])).length

    onRowsChanged: {
        if (role !== "face" || rows.length === 0)
            return;
        const now = Date.now();
        const s = seen && seen.macs ? { since: seen.since, macs: Object.assign({}, seen.macs) } : { since: now, macs: {} };
        let changed = !seen;
        for (const r of rows) {
            if (!s.macs[r[1]]) {
                s.macs[r[1]] = now;
                changed = true;
            }
        }
        if (changed)
            Saved.set("lanSeen", s);
    }

    WidgetCaption {
        x: 20
        y: 16
        icon: "devices"
        text: Tr.t("On the network")
    }
    Row {
        x: 20
        y: 46
        spacing: 10

        Text {
            text: root.reading ? root.rows.length : "…"
            font.family: Theme.display
            font.pixelSize: 40
            font.weight: Font.DemiBold
            color: Theme.text
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter

            Label {
                text: Tr.t("devices")
                size: 13
                color: Theme.muted
            }
            Label {
                visible: root.newCount > 0
                text: Tr.t("{n} new").replace("{n}", root.newCount)
                size: 12
                font.weight: Font.DemiBold
                color: Theme.warn
            }
        }
    }
    Label {
        visible: NetTools.busy["lan"] === true
        anchors.right: parent.right
        anchors.rightMargin: 20
        y: 20
        text: Tr.t("Scanning…")
        size: 11
        color: Theme.muted
    }

    Column {
        x: root.square ? 16 : 190
        y: root.square ? 104 : 46
        width: root.width - x - 16
        spacing: 3

        Repeater {
            model: root.ordered.slice(0, root.square ? 6 : 5)

            Rectangle {
                id: row

                required property var modelData
                readonly property bool fresh: root.isNew(modelData[1])

                width: parent.width
                height: 28
                radius: 9
                color: fresh ? Qt.alpha(Theme.warn, 0.14) : Qt.alpha(Theme.text, 0.05)

                Rectangle {
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 6
                    height: 6
                    radius: 3
                    color: row.fresh ? Theme.warn : Theme.good
                }
                Label {
                    x: 20
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 20 - ipText.implicitWidth - 16
                    elide: Text.ElideRight
                    text: root.nameOf(row.modelData)
                    size: 12
                    font.weight: row.fresh ? Font.DemiBold : Font.Normal
                }
                Label {
                    id: ipText

                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData[0]
                    size: 11
                    font.family: Theme.mono
                    color: Theme.muted
                }
            }
        }
        Label {
            visible: root.rows.length > (root.square ? 6 : 5)
            text: Tr.t("And {n} more").replace("{n}", root.rows.length - (root.square ? 6 : 5))
            size: 11
            color: Theme.muted
        }
    }
    WidgetHot {
        anchors.fill: parent
        onClicked: NetTools.toggle("lan")
    }
}
