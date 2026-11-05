import QtQuick
import Quickshell
import qs.components
import qs.services

// The moon as it looks tonight, worked out from the date. Forms: wide, tall.
Item {
    id: root

    property string form: "wide"
    readonly property bool tall: form === "tall"
    readonly property real cycle: 29.530588853
    // A known new moon: 6 January 2000, 18:14 UTC.
    readonly property real phase: {
        const days = (clock.date.getTime() - Date.UTC(2000, 0, 6, 18, 14)) / 86400000;
        return ((days % cycle) + cycle) % cycle / cycle;
    }
    readonly property int lit: Math.round((1 - Math.cos(phase * 2 * Math.PI)) / 2 * 100)
    readonly property string phaseName: {
        const p = phase;
        if (p < 0.02 || p >= 0.98)
            return Tr.t("New moon");
        if (p < 0.23)
            return Tr.t("Waxing crescent");
        if (p < 0.27)
            return Tr.t("First quarter");
        if (p < 0.48)
            return Tr.t("Waxing gibbous");
        if (p < 0.52)
            return Tr.t("Full moon");
        if (p < 0.73)
            return Tr.t("Waning gibbous");
        if (p < 0.77)
            return Tr.t("Last quarter");
        return Tr.t("Waning crescent");
    }
    readonly property int toFull: Math.round(((0.5 - phase + 1) % 1) * cycle)

    onPhaseChanged: disc.requestPaint()

    SystemClock {
        id: clock

        precision: SystemClock.Hours
    }

    Canvas {
        id: disc

        x: root.tall ? (parent.width - width) / 2 : 18
        y: root.tall ? 16 : (parent.height - height) / 2
        width: 104
        height: 104
        renderStrategy: Canvas.Cooperative
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const c = width / 2;
            const r = c - 8;
            ctx.beginPath();
            ctx.arc(c, c, r, 0, Math.PI * 2);
            ctx.fillStyle = "#1d2029";
            ctx.fill();

            const k = Math.cos(root.phase * 2 * Math.PI);
            const waxing = root.phase < 0.5;
            ctx.save();
            ctx.beginPath();
            const steps = 48;
            for (let i = 0; i <= steps; i++) {
                const a = -Math.PI / 2 + Math.PI * i / steps;
                const x = c + (waxing ? 1 : -1) * r * Math.cos(a);
                const y = c + r * Math.sin(a);
                if (i === 0)
                    ctx.moveTo(x, y);
                else
                    ctx.lineTo(x, y);
            }
            for (let i = 0; i <= steps; i++) {
                const a = Math.PI / 2 - Math.PI * i / steps;
                ctx.lineTo(c + (waxing ? 1 : -1) * k * r * Math.cos(a), c + r * Math.sin(a));
            }
            ctx.closePath();
            ctx.clip();
            const light = ctx.createRadialGradient(c - r * 0.2, c - r * 0.3, r * 0.1, c, c, r * 1.1);
            light.addColorStop(0, "#fbf6e6");
            light.addColorStop(1, "#c9c0a6");
            ctx.fillStyle = light;
            ctx.fillRect(0, 0, width, height);
            // Maria, the darker plains.
            ctx.fillStyle = "rgba(112, 106, 92, 0.3)";
            for (const m of [[-0.3, -0.35, 0.3], [0.2, -0.3, 0.22], [-0.45, 0.15, 0.24], [0.1, 0.1, 0.17], [0.35, 0.3, 0.14], [-0.1, 0.5, 0.12]]) {
                ctx.beginPath();
                ctx.arc(c + m[0] * r, c + m[1] * r, m[2] * r, 0, Math.PI * 2);
                ctx.fill();
            }
            ctx.restore();
        }
    }
    Column {
        x: root.tall ? 14 : disc.x + disc.width + 12
        y: root.tall ? disc.y + disc.height + 8 : (parent.height - height) / 2
        width: parent.width - x - 14
        spacing: 3

        Label {
            width: parent.width
            horizontalAlignment: root.tall ? Text.AlignHCenter : Text.AlignLeft
            text: root.phaseName
            size: 15
            font.weight: Font.DemiBold
            wrapMode: Text.WordWrap
            maximumLineCount: 2
        }
        Label {
            width: parent.width
            horizontalAlignment: root.tall ? Text.AlignHCenter : Text.AlignLeft
            text: Tr.t("{n}% lit").replace("{n}", root.lit)
            color: Theme.muted
            size: 12
        }
        Label {
            width: parent.width
            horizontalAlignment: root.tall ? Text.AlignHCenter : Text.AlignLeft
            visible: root.toFull > 0
            text: Tr.t("Full in {n} d").replace("{n}", root.toFull)
            color: Theme.muted
            size: 12
        }
    }
}
