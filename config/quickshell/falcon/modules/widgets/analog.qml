import QtQuick
import Quickshell
import qs.services

// Analog clock with a second hand.
Item {
    SystemClock {
        id: clock

        precision: SystemClock.Seconds
        onSecondsChanged: dial.requestPaint()
    }
    Connections {
        target: Theme
        function onAccentChanged() {
            dial.requestPaint();
        }
    }

    Canvas {
        id: dial

        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const c = width / 2;
            const r = c - 18;
            ctx.translate(c, c);
            ctx.lineCap = "round";
            for (let i = 0; i < 12; i++) {
                const a = i * Math.PI / 6;
                ctx.strokeStyle = Qt.alpha(Theme.text, i % 3 === 0 ? 0.7 : 0.25);
                ctx.lineWidth = i % 3 === 0 ? 2.5 : 1.5;
                ctx.beginPath();
                ctx.moveTo(Math.sin(a) * (r - 8), -Math.cos(a) * (r - 8));
                ctx.lineTo(Math.sin(a) * r, -Math.cos(a) * r);
                ctx.stroke();
            }
            const hand = (a, l, w, color) => {
                ctx.strokeStyle = color;
                ctx.lineWidth = w;
                ctx.beginPath();
                ctx.moveTo(0, 0);
                ctx.lineTo(Math.sin(a) * l, -Math.cos(a) * l);
                ctx.stroke();
            };
            const s = clock.seconds;
            const m = clock.minutes + s / 60;
            const h = clock.hours % 12 + m / 60;
            hand(h * Math.PI / 6, r * 0.5, 4, Theme.text);
            hand(m * Math.PI / 30, r * 0.76, 3, Theme.text);
            hand(s * Math.PI / 30, r * 0.84, 1.5, Theme.accent);
            ctx.fillStyle = Theme.accent;
            ctx.beginPath();
            ctx.arc(0, 0, 4, 0, 2 * Math.PI);
            ctx.fill();
        }
    }
}
