import QtQuick
import qs.components
import qs.services

// Exchange rates of the sum from the Central Bank: each currency's rate, the day's change and
// two weeks as a line. Forms: wide (columns), tall (rows with lines), compact (rows).
Item {
    id: root

    readonly property bool widgetRoot: true
    property string widgetId: ""
    property string form: "wide"
    readonly property bool wide: form === "wide"
    readonly property bool compact: form === "compact"
    readonly property var list: Currency.codes.filter(c => !!Currency.rates[c])
    readonly property color up: Theme.good
    readonly property color down: Theme.error

    function diffText(c) {
        const r = Currency.rates[c];
        if (!r || r.diff === 0)
            return "0";
        return (r.diff > 0 ? "+" : "−") + Currency.price(c, Math.abs(r.diff));
    }
    function tint(c) {
        const r = Currency.rates[c];
        return !r || r.diff === 0 ? Theme.muted : r.diff > 0 ? up : down;
    }
    function sign(c) {
        return ({ USD: "$", EUR: "€", RUB: "₽", GBP: "£", CNY: "¥", JPY: "¥", KZT: "₸", TRY: "₺", KRW: "₩", AED: "د.إ", BTC: "₿", ETH: "Ξ", USDT: "₮" })[c] || c.charAt(0);
    }

    WidgetCaption {
        x: 20
        y: 16
        icon: "coin"
        text: Tr.t("Exchange rates")
    }
    Label {
        anchors.right: parent.right
        anchors.rightMargin: 20
        y: 20
        text: Currency.offline && Currency.fetchedAt === 0 ? Tr.t("Offline") : Currency.date !== "" ? Tr.t("CBU") + " · " + Currency.date : ""
        size: 11
        color: Currency.offline ? Theme.error : Theme.muted
    }
    Label {
        anchors.centerIn: parent
        visible: root.list.length === 0
        text: Currency.offline ? Tr.t("No connection to the bank") : Tr.t("Loading rates…")
        size: 13
        color: Theme.muted
    }

    // ---------------------------------------------------------------- wide: a column each
    Row {
        visible: root.wide && root.list.length > 0
        x: 16
        y: 50
        spacing: 10

        Repeater {
            model: root.wide ? root.list : []

            Rectangle {
                id: col

                required property string modelData

                width: (root.width - 32 - 10 * (root.list.length - 1)) / root.list.length
                height: root.height - 66
                radius: 16
                color: Qt.alpha(Theme.text, 0.06)

                Row {
                    x: 12
                    y: 10
                    spacing: 6

                    Rectangle {
                        width: 22
                        height: 22
                        radius: 11
                        color: Qt.alpha(Theme.accent, 0.2)

                        Label {
                            anchors.centerIn: parent
                            text: root.sign(col.modelData)
                            size: 12
                            font.weight: Font.Bold
                            color: Theme.accent
                        }
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: col.modelData
                        size: 13
                        font.weight: Font.DemiBold
                    }
                }
                Text {
                    x: 12
                    y: 38
                    width: parent.width - 24
                    text: Currency.price(col.modelData, Currency.rates[col.modelData].rate)
                    font.family: Theme.display
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                    fontSizeMode: Text.HorizontalFit
                    minimumPixelSize: 14
                    color: Theme.text
                }
                Label {
                    x: 12
                    y: 70
                    text: root.diffText(col.modelData)
                    size: 11
                    font.weight: Font.DemiBold
                    color: root.tint(col.modelData)
                }
                WidgetSpark {
                    x: 8
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    width: parent.width - 16
                    height: parent.height - 96
                    readonly property var h: Currency.history[col.modelData] || []
                    values: h.length > 1 ? h : [0, 0]
                    min: h.length ? Math.min(...h) * 0.998 : 0
                    max: h.length ? Math.max(...h) * 1.002 : 1
                    color: root.tint(col.modelData)
                    lineWidth: 1.8
                    fillAlpha: 0.18
                    dot: false
                }
            }
        }
    }

    // ---------------------------------------------------------------- tall and compact: rows
    Column {
        visible: !root.wide && root.list.length > 0
        x: 16
        y: 48
        width: root.width - 32
        spacing: root.compact ? 2 : 8

        Repeater {
            // Compact holds four rows: with a fourth code they close up from 26 to 21 px.
            model: root.wide ? [] : root.list.slice(0, root.compact ? 4 : 6)

            Item {
                id: row

                required property string modelData

                width: parent.width
                height: root.compact ? (root.list.length > 3 ? 21 : 26) : 44

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData
                    size: 13
                    font.weight: Font.DemiBold
                }
                WidgetSpark {
                    visible: !root.compact
                    x: 46
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 46 - 120
                    height: 30
                    readonly property var h: Currency.history[row.modelData] || []
                    values: h.length > 1 ? h : [0, 0]
                    min: h.length ? Math.min(...h) * 0.998 : 0
                    max: h.length ? Math.max(...h) * 1.002 : 1
                    color: root.tint(row.modelData)
                    lineWidth: 1.6
                    fillAlpha: 0.15
                    dot: false
                }
                Column {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter

                    Label {
                        anchors.right: parent.right
                        text: Currency.price(row.modelData, Currency.rates[row.modelData].rate)
                        size: root.compact ? 13 : 16
                        font.weight: Font.DemiBold
                    }
                    Label {
                        visible: !root.compact
                        anchors.right: parent.right
                        text: root.diffText(row.modelData)
                        size: 11
                        color: root.tint(row.modelData)
                    }
                }
                Label {
                    visible: root.compact
                    anchors.right: parent.right
                    anchors.rightMargin: 90
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.diffText(row.modelData)
                    size: 11
                    color: root.tint(row.modelData)
                }
            }
        }
    }
}
