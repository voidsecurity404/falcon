import QtQuick
import Quickshell
import qs.services

// The time made of living dots. Each dot has a position and a speed: it is pulled to its place in the digits,
// thrown away by the pointer and flies back on its own. Resting dots are skipped, so a calm clock costs little.
Item {
    id: root

    property real pointerX: -999
    property real pointerY: -999
    property real centerY: height / 2

    readonly property string wanted: Ui.pad(clock.hours) + ":" + Ui.pad(clock.minutes)
    readonly property int pool: 3400
    readonly property int grid: 5
    readonly property real reach: 8100
    property string shown: ""
    property int ready: 0
    property int frame: 0
    property var dots: []
    readonly property var x0: new Float32Array(pool)
    readonly property var y0: new Float32Array(pool)
    readonly property var vx: new Float32Array(pool)
    readonly property var vy: new Float32Array(pool)
    readonly property var hx: new Float32Array(pool)
    readonly property var hy: new Float32Array(pool)
    readonly property var phase: new Float32Array(pool)
    readonly property var awake: new Uint8Array(pool)
    readonly property var shades: {
        const list = [];
        const a = Theme.accent;
        const b = Qt.hsla((Math.max(0, a.hslHue) + 0.18) % 1, a.hslSaturation, a.hslLightness, 1);
        for (let i = 0; i <= 16; i++)
            list.push(Qt.rgba(a.r + (b.r - a.r) * i / 16, a.g + (b.g - a.g) * i / 16, a.b + (b.b - a.b) * i / 16, 1));
        return list;
    }

    function shadeAt(y) {
        const k = Math.max(0, Math.min(1, (y - centerY + 100) / 200));
        return shades[Math.round(k * 16)];
    }

    // Sends the dots to new places, in shuffled order so that they cross the whole time.
    function aim(points) {
        const count = points.length / 2;
        const order = new Int32Array(count);
        for (let i = 0; i < count; i++)
            order[i] = i;
        for (let i = count - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            const swap = order[i];
            order[i] = order[j];
            order[j] = swap;
        }
        for (let i = 0; i < pool; i++) {
            // With fewer places than dots, some dots share a place.
            const at = order[i % count];
            hx[i] = points[at * 2];
            hy[i] = points[at * 2 + 1];
            awake[i] = 1;
            if (i < dots.length && dots[i])
                dots[i].color = shadeAt(hy[i]);
        }
    }

    function step() {
        // Read once: looking up a QML property for each dot is what would make this slow.
        const list = dots;
        const n = ready;
        const px = pointerX;
        const py = pointerY;
        const far = reach;
        const xs = x0;
        const ys = y0;
        const us = vx;
        const ws = vy;
        const homeX = hx;
        const homeY = hy;
        const phases = phase;
        const live = awake;
        const tremble = (0.5 + Sys.cpu / 100 * 5) * 0.4;
        const a = Date.now() / 500;
        const b = Date.now() / 430;
        const slice = frame++ % 8;
        for (let i = 0; i < n; i++) {
            // Dots are not always created in order.
            const dot = list[i];
            if (!dot)
                continue;
            const dx = xs[i] - px;
            const dy = ys[i] - py;
            const near = dx * dx + dy * dy;
            if (near < far)
                live[i] = 1;
            if (live[i]) {
                let ax = (homeX[i] - xs[i]) * 0.03;
                let ay = (homeY[i] - ys[i]) * 0.03;
                if (near < far) {
                    const force = (far - near) / far * 2.2 / Math.sqrt(near + 1);
                    ax += dx * force;
                    ay += dy * force;
                }
                const u = (us[i] + ax) * 0.86;
                const w = (ws[i] + ay) * 0.86;
                us[i] = u;
                ws[i] = w;
                xs[i] += u;
                ys[i] += w;
                dot.x = xs[i] + Math.sin(a + phases[i]) * tremble;
                dot.y = ys[i] + Math.cos(b + phases[i] * 1.3) * tremble;
                if (Math.abs(u) + Math.abs(w) < 0.03 && Math.abs(homeX[i] - xs[i]) + Math.abs(homeY[i] - ys[i]) < 0.15)
                    live[i] = 0;
            } else if ((i & 7) === slice) {
                // Resting dots tremble in turns: eight groups, one per frame.
                dot.x = xs[i] + Math.sin(a + phases[i]) * tremble;
                dot.y = ys[i] + Math.cos(b + phases[i] * 1.3) * tremble;
            }
        }
    }

    Component.onCompleted: {
        for (let i = 0; i < pool; i++) {
            x0[i] = Math.random() * width;
            y0[i] = Math.random() * height;
            phase[i] = Math.random() * 6.283;
        }
    }

    onWantedChanged: reader.requestPaint()
    onShadesChanged: {
        for (let i = 0; i < dots.length; i++) {
            if (dots[i])
                dots[i].color = shadeAt(hy[i]);
        }
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    // Draws the digits once and reads which grid points they cover. It is empty the rest of the time.
    Canvas {
        id: reader

        anchors.fill: parent
        onAvailableChanged: requestPaint()
        onPaint: {
            if (!available || width <= 0 || root.shown === root.wanted)
                return;
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.fillStyle = "#ffffff";
            // The variable font has overlapping outlines: the other rule would cut holes in the digits.
            ctx.fillRule = Qt.WindingFill;
            ctx.font = "800 240px \"Unbounded\"";
            ctx.textAlign = "center";
            ctx.textBaseline = "middle";
            ctx.fillText(root.wanted, width / 2, root.centerY);
            const pixels = ctx.getImageData(0, 0, width, height).data;
            ctx.clearRect(0, 0, width, height);
            const w = Math.floor(width);
            const points = [];
            for (let y = 0; y < height; y += root.grid) {
                for (let x = 0; x < w; x += root.grid) {
                    if (pixels[(y * w + x) * 4 + 3] > 128)
                        points.push(x, y);
                }
            }
            if (points.length > 0) {
                root.shown = root.wanted;
                root.aim(points);
            }
        }
    }

    // Made a few at a time, so that the panel opens without a pause. Each dot starts flying as soon as it exists.
    Instantiator {
        model: root.pool
        asynchronous: true

        delegate: Rectangle {
            required property int index

            parent: root
            x: root.x0[index]
            y: root.y0[index]
            width: 3.4
            height: 3.4
            radius: 1.7
            antialiasing: true
            color: root.shadeAt(root.hy[index])
        }
        onObjectAdded: (index, object) => {
            root.dots[index] = object;
            root.ready = Math.max(root.ready, index + 1);
        }
    }

    FrameAnimation {
        running: root.visible && root.shown !== ""
        onTriggered: root.step()
    }
}
