import QtQuick
import QtQuick.Effects
import Quickshell
import qs.services

// The time made of living dots. Each dot has a position and a speed: it is pulled to its place in the digits,
// thrown away by the pointer and flies back on its own. When every dot has settled, nothing runs at all.
Item {
    id: root

    property real pointerX: -999
    property real pointerY: -999
    property real centerY: height / 2
    property int fontSize: 240

    readonly property string wanted: Ui.pad(clock.hours) + ":" + Ui.pad(clock.minutes)
    readonly property int pool: 3400
    readonly property int grid: 5
    // Each of the five characters owns its dots, so a new minute moves only the digit that changed.
    // The widest digit, 8, needs 739 places at the size used on the Today tab, and the colon 152.
    readonly property int digitDots: 800
    readonly property int colonDots: pool - digitDots * 4
    readonly property real reach: 8100
    // The dots tremble only under a real load, so an idle computer stays idle.
    readonly property bool trembling: Sys.cpu >= 25
    property string shown: ""
    property int ready: 0
    property int frame: 0
    property bool settled: false
    property real lastX: -999
    property real lastY: -999
    property var dots: []
    readonly property var xs: new Float32Array(pool)
    readonly property var ys: new Float32Array(pool)
    readonly property var us: new Float32Array(pool)
    readonly property var ws: new Float32Array(pool)
    readonly property var homeX: new Float32Array(pool)
    readonly property var homeY: new Float32Array(pool)
    readonly property var phase: new Float32Array(pool)
    readonly property var awake: new Uint8Array(pool)

    // Sends one character's dots to new places, in shuffled order so that they cross the whole character.
    function aim(slot, points) {
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
        const hx = homeX;
        const hy = homeY;
        const live = awake;
        const first = slotStart(slot);
        const size = slotDots(slot);
        for (let n = 0; n < size; n++) {
            // With fewer places than dots, some dots share a place.
            const at = order[n % count];
            const i = first + n;
            hx[i] = points[at * 2];
            hy[i] = points[at * 2 + 1];
            live[i] = 1;
        }
        settled = false;
    }

    // Each opening of the panel starts with the dots spread over it.
    function scatter() {
        const x = xs;
        const y = ys;
        const live = awake;
        const w = width;
        const h = height;
        for (let i = 0; i < pool; i++) {
            x[i] = Math.random() * w;
            y[i] = Math.random() * h;
            live[i] = 1;
        }
        settled = false;
    }

    function slotDots(slot) {
        return slot === 2 ? colonDots : digitDots;
    }

    function slotStart(slot) {
        return slot <= 2 ? slot * digitDots : colonDots + (slot - 1) * digitDots;
    }

    function step() {
        // Read once: looking up a QML property for each dot is what would make this slow.
        const list = dots;
        const n = ready;
        const px = pointerX;
        const py = pointerY;
        const moved = px !== lastX || py !== lastY;
        lastX = px;
        lastY = py;
        const far = reach;
        const x = xs;
        const y = ys;
        const u = us;
        const w = ws;
        const hx = homeX;
        const hy = homeY;
        const phases = phase;
        const live = awake;
        const shake = trembling ? (0.5 + Sys.cpu / 100 * 5) * 0.4 : 0;
        const a = Date.now() / 500;
        const b = Date.now() / 430;
        const slice = frame++ & 7;
        let busy = 0;
        for (let i = 0; i < n; i++) {
            // Dots are not always created in order.
            const dot = list[i];
            if (!dot)
                continue;
            const dx = x[i] - px;
            const dy = y[i] - py;
            const near = dx * dx + dy * dy;
            if (moved && (near < far || x[i] !== hx[i] || y[i] !== hy[i]))
                live[i] = 1;
            if (live[i]) {
                let ax = (hx[i] - x[i]) * 0.03;
                let ay = (hy[i] - y[i]) * 0.03;
                if (near < far) {
                    const force = (far - near) / far * 2.2 / Math.sqrt(near + 1);
                    ax += dx * force;
                    ay += dy * force;
                }
                const nu = (u[i] + ax) * 0.86;
                const nw = (w[i] + ay) * 0.86;
                u[i] = nu;
                w[i] = nw;
                x[i] += nu;
                y[i] += nw;
                // A dot almost home lands there, which ends the long invisible tail of the spring.
                const slow = Math.abs(nu) + Math.abs(nw) + Math.abs(ax) + Math.abs(ay) < 0.12;
                if (slow && near >= far) {
                    x[i] = hx[i];
                    y[i] = hy[i];
                }
                if (slow)
                    live[i] = 0;
                else
                    busy++;
                // Moves too small to see are not worth a redraw.
                if (!slow && Math.abs(nu) + Math.abs(nw) < 0.04 && !shake)
                    continue;
                dot.x = x[i] + (shake ? Math.sin(a + phases[i]) * shake : 0);
                dot.y = y[i] + (shake ? Math.cos(b + phases[i] * 1.3) * shake : 0);
            } else if (shake && (i & 7) === slice) {
                // Resting dots tremble in turns: eight groups, one per frame.
                dot.x = x[i] + Math.sin(a + phases[i]) * shake;
                dot.y = y[i] + Math.cos(b + phases[i] * 1.3) * shake;
            }
        }
        settled = busy === 0 && !shake && n === pool;
    }

    Component.onCompleted: {
        for (let i = 0; i < pool; i++)
            phase[i] = Math.random() * 6.283;
        scatter();
    }

    onWantedChanged: reader.requestPaint()
    onPointerXChanged: settled = false
    onPointerYChanged: settled = false
    onTremblingChanged: settled = false

    Connections {
        target: Ui
        function onPopupChanged() {
            if (Ui.popup === "dashboard")
                root.scatter();
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
        onHeightChanged: requestPaint()
        onVisibleChanged: requestPaint()
        onPaint: {
            if (!available || width <= 0 || height <= 0 || root.shown === root.wanted)
                return;
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.fillStyle = "#ffffff";
            ctx.font = "800 " + root.fontSize + "px \"Unbounded\"";
            // The variable font has overlapping outlines. fillText would cut holes where they cross.
            ctx.fillRule = Qt.WindingFill;
            // Digits differ in width. Fixed cells keep the other digits in place when one changes.
            let cell = 0;
            for (let digit = 0; digit <= 9; digit++)
                cell = Math.max(cell, ctx.measureText(String(digit)).width);
            const colon = ctx.measureText(":").width;
            let left = Math.round((width - cell * 4 - colon) / 2);
            const w = Math.floor(width);
            const changes = [];
            for (let slot = 0; slot < root.wanted.length; slot++) {
                const glyph = root.wanted[slot];
                const size = slot === 2 ? colon : cell;
                if (glyph !== root.shown[slot]) {
                    ctx.clearRect(0, 0, width, height);
                    ctx.beginPath();
                    // text() ignores the alignment settings. The digits are 0.75 of the font size tall.
                    ctx.text(glyph, Math.round(left + (size - ctx.measureText(glyph).width) / 2), root.centerY + root.fontSize * 0.375);
                    ctx.fill();
                    const pixels = ctx.getImageData(0, 0, width, height).data;
                    const points = [];
                    for (let y = 0; y < height; y += root.grid) {
                        for (let x = 0; x < w; x += root.grid) {
                            if (pixels[(y * w + x) * 4 + 3] > 128)
                                points.push(x, y);
                        }
                    }
                    changes.push({ slot: slot, points: points });
                }
                left += size;
            }
            ctx.clearRect(0, 0, width, height);
            // A font that is not ready yet gives no places: try again at the next paint.
            if (changes.every(change => change.points.length > 0)) {
                root.shown = root.wanted;
                for (const change of changes)
                    root.aim(change.slot, change.points);
            }
        }
    }

    // White dots only say where the color shows. Four corners per dot keep the scene light,
    // and the color gradient is one shared picture instead of a color per dot.
    Item {
        id: field

        anchors.fill: parent
        visible: false
        layer.enabled: true
    }
    Rectangle {
        id: paint

        anchors.fill: parent
        visible: false
        gradient: Gradient {
            GradientStop {
                position: Math.max(0, (root.centerY - 90) / Math.max(1, root.height))
                color: Theme.accent
            }
            GradientStop {
                position: Math.min(1, (root.centerY + root.fontSize * 0.375) / Math.max(1, root.height))
                color: Qt.hsla((Math.max(0, Theme.accent.hslHue) + 0.18) % 1, Theme.accent.hslSaturation, Theme.accent.hslLightness, 1)
            }
        }
    }
    MultiEffect {
        anchors.fill: parent
        source: paint
        maskEnabled: true
        maskSource: field
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }

    // Made a few at a time when the shell starts, and kept: opening the panel creates nothing.
    Instantiator {
        model: root.pool
        asynchronous: true

        delegate: Image {
            parent: field
            width: 3.6
            height: 3.6
            source: "dot.png"
            smooth: true
        }
        onObjectAdded: (index, object) => {
            object.x = root.xs[index];
            object.y = root.ys[index];
            root.dots[index] = object;
            root.ready = Math.max(root.ready, index + 1);
        }
    }

    FrameAnimation {
        running: root.visible && root.shown !== "" && !root.settled
        onTriggered: root.step()
    }
}
