import QtQuick
import Quickshell
import qs.components
import qs.services

// The sun on its arc between sunrise and sunset.
Item {
    id: root

    readonly property real length: Weather.sunset - Weather.sunrise
    readonly property real now: clock.date.getTime()
    readonly property real share: length > 0 ? (now - Weather.sunrise) / length : 0
    readonly property bool up: share >= 0 && share <= 1
    readonly property real base: height - 54
    readonly property real side: 26
    readonly property real rise: height - 96

    function timeOf(ms) {
        const d = new Date(ms);
        return Ui.pad(d.getHours()) + ":" + Ui.pad(d.getMinutes());
    }
    function spanOf(ms) {
        const minutes = Math.max(0, Math.round(ms / 60000));
        return Tr.t("{h} h {m} min").replace("{h}", Math.floor(minutes / 60)).replace("{m}", minutes % 60);
    }
    function point(t) {
        return Qt.point(side + (width - side * 2) * t, base - Math.sin(t * Math.PI) * rise);
    }

    onShareChanged: arc.requestPaint()
    onRiseChanged: arc.requestPaint()

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    Label {
        x: 20
        y: 14
        text: !Weather.hasData ? Tr.t("No weather data") : root.up ? Tr.t("{t} of daylight left").replace("{t}", root.spanOf(Weather.sunset - root.now)) : root.share < 0 ? Tr.t("Sunrise in {t}").replace("{t}", root.spanOf(Weather.sunrise - root.now)) : Tr.t("The sun has set")
        color: Theme.muted
        size: 12
    }
    Canvas {
        id: arc

        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.lineCap = "round";
            ctx.strokeStyle = Qt.alpha(Theme.text, 0.14);
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.moveTo(10, root.base);
            ctx.lineTo(root.width - 10, root.base);
            ctx.stroke();
            const curve = (from, to) => {
                ctx.beginPath();
                for (let i = 0; i <= 60; i++) {
                    const p = root.point(from + (to - from) * i / 60);
                    if (i === 0)
                        ctx.moveTo(p.x, p.y);
                    else
                        ctx.lineTo(p.x, p.y);
                }
                ctx.stroke();
            };
            ctx.lineWidth = 3;
            ctx.strokeStyle = Qt.alpha(Theme.text, 0.14);
            curve(0, 1);
            if (Weather.hasData) {
                ctx.strokeStyle = Theme.accent;
                curve(0, Math.max(0, Math.min(1, root.share)));
            }
        }

        Connections {
            target: Theme
            function onAccentChanged() {
                arc.requestPaint();
            }
        }
    }
    Item {
        visible: Weather.hasData
        readonly property point at: root.point(Math.max(0, Math.min(1, root.share)))

        x: at.x
        y: at.y

        Rectangle {
            x: -18
            y: -18
            width: 36
            height: 36
            radius: 18
            visible: root.up
            color: Qt.alpha(Theme.accent, 0.22)
        }
        Rectangle {
            x: -9
            y: -9
            width: 18
            height: 18
            radius: 9
            color: root.up ? Theme.accent : Theme.muted
            border.width: 2
            border.color: Theme.pill
        }
    }
    Column {
        x: 20
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12

        Label {
            text: Weather.hasData ? root.timeOf(Weather.sunrise) : "—"
            size: 16
            font.weight: Font.DemiBold
        }
        Label {
            text: Tr.t("Sunrise")
            color: Theme.muted
            size: 11
        }
    }
    Column {
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12

        Label {
            anchors.right: parent.right
            text: Weather.hasData ? root.timeOf(Weather.sunset) : "—"
            size: 16
            font.weight: Font.DemiBold
        }
        Label {
            anchors.right: parent.right
            text: Tr.t("Sunset")
            color: Theme.muted
            size: 11
        }
    }
}
